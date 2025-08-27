pub export fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};
    const platform = b.option([]const u8, "platform", "build for ios or android") orelse "";

    const app_name = b.option([]const u8, "app_name", "override the app name") orelse "Lexica";
    const app_version = b.option([]const u8, "app_version", "override the app version") orelse "1.0";
    const app_id = b.option([]const u8, "app_id", "override the app id") orelse "org.example.lexica";
    const org = b.option([]const u8, "org", "override the org") orelse "lexica";
    const assets = b.option([]const u8, "assets", "override the asset folder") orelse "assets";

    var build_number_step = b.allocator.create(IncrementBuildNumberStep) catch @panic("OOM");
    build_number_step.* = IncrementBuildNumberStep.init(b, app_name, app_version, app_id, org);
    b.getInstallStep().dependOn(&build_number_step.step);

    const app_info = b.addOptions();
    app_info.addOption([]const u8, "app_full_name", app_name);
    app_info.addOption([]const u8, "app_version", app_version);
    app_info.addOption([]const u8, "app_id", app_id);
    app_info.addOption([]const u8, "org", org);
    app_info.addOption([]const u8, "app_build", build_number_step.app_build);
    const app_info_module = app_info.createModule();

    if (platform.len == 0) {
        // Build a binary to run on macOS
        const target = b.standardTargetOptions(.{});

        const engine = b.dependency("engine", .{ .target = target, .optimize = optimize });
        const engine_module = engine.module("engine");
        const dep_sdl_module = engine.module("sdl");

        const zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
        const zigimg_module = zigimg.module("zigimg");
        const resources = engine.builder.dependency("resources", .{ .target = target, .optimize = optimize });
        const resources_module = resources.module("resources");
        const praxis = resources.builder.dependency("praxis", .{ .target = target, .optimize = optimize });
        const praxis_module = praxis.module("praxis");

        const mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        mod.addImport("app_info", app_info_module);
        mod.addImport("praxis", praxis_module);
        mod.addImport("resources", resources_module);
        mod.addImport("zigimg", zigimg_module);
        mod.addImport("engine", engine_module);
        mod.addImport("dep_sdl_module", dep_sdl_module);

        add_imports(b, &target, dep_sdl_module);

        const exe = b.addExecutable(.{
            .name = "lexica",
            .root_module = mod,
        });
        b.installArtifact(exe);
        build_number_step.step.dependOn(&exe.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        const real_tests = b.addTest(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
            .filters = test_filters,
        });
        real_tests.root_module.addImport("zigimg", zigimg_module);
        real_tests.root_module.addImport("app_info", app_info_module);
        //real_tests.root_module.addImport("praxis", praxis_module);
        real_tests.root_module.addImport("resources", resources_module);
        real_tests.root_module.addImport("engine", engine_module);
        real_tests.root_module.addImport("dep_sdl_module", dep_sdl_module);
        real_tests.linkLibrary(b.dependency("sdl", .{ .target = target, .optimize = optimize }).artifact("SDL3"));
        real_tests.linkLibrary(b.dependency("sdl_ttf", .{ .target = target, .optimize = optimize }).artifact("SDL_ttf"));
        const run_real_tests = b.addRunArtifact(real_tests);

        const exe_unit_tests = b.addTest(.{
            .root_module = mod,
        });
        exe_unit_tests.root_module.addImport("praxis", praxis_module);
        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_real_tests.step);
        test_step.dependOn(&run_exe_unit_tests.step);
    }

    if (std.ascii.eqlIgnoreCase("simulator", platform)) {
        // Build an iOS-simulator library
        const target = b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .aarch64, .abi = .simulator });

        const engine = b.dependency("engine", .{ .target = target, .optimize = optimize });
        const engine_module = engine.module("engine");
        const zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
        const zigimg_module = zigimg.module("zigimg");
        const resources = engine.builder.dependency("resources", .{ .target = target, .optimize = optimize });
        const resources_module = resources.module("resources");
        const praxis = resources.builder.dependency("praxis", .{ .target = target, .optimize = optimize });
        const praxis_module = praxis.module("praxis");
        //const dep_sdl_module = engine.module("sdl");

        const mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        mod.addImport("praxis", praxis_module);
        mod.addImport("resources", resources_module);
        mod.addImport("zigimg", zigimg_module);
        mod.addImport("engine", engine_module);

        const lib = b.addLibrary(.{
            .name = "lexica-ios-simulator",
            .root_module = mod,
            .linkage = .dynamic,
        });
        b.installArtifact(lib);

        // Copy library into the xcode template project
        const lib_install = b.addInstallLibFile(lib.getEmittedBin(), "../../ios/Lexica/liblexica-ios-simulator.so");
        b.getInstallStep().dependOn(&lib_install.step);
    }

    if (std.ascii.eqlIgnoreCase("ios", platform)) {
        // Build an iOS native library
        const target = b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .aarch64 });

        const engine = b.dependency("engine", .{ .target = target, .optimize = optimize });
        const engine_module = engine.module("engine");
        const dep_sdl_module = engine.module("sdl");
        const zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
        const zigimg_module = zigimg.module("zigimg");
        const resources = engine.builder.dependency("resources", .{ .target = target, .optimize = optimize });
        const resources_module = resources.module("resources");
        const praxis = resources.builder.dependency("praxis", .{ .target = target, .optimize = optimize });
        const praxis_module = praxis.module("praxis");

        if (optimize != .ReleaseFast and optimize != .ReleaseSafe) {
            std.log.warn("Building ios lib without -Doptimize=ReleaseFast or -Doptomize=ReleaseSafe", .{});
        }

        if (std.mem.eql(u8, app_id, "org.example.lexica")) {
            std.log.warn("Building ios lib with default app_id=org.example.lexica", .{});
        }

        add_imports(b, &target, dep_sdl_module);

        const mod = b.createModule(.{
            .root_source_file = b.path("src/ios_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        mod.addImport("app_info", app_info_module);
        mod.addImport("praxis", praxis_module);
        mod.addImport("resources", resources_module);
        mod.addImport("zigimg", zigimg_module);
        mod.addImport("engine", engine_module);
        mod.addImport("dep_sdl_module", dep_sdl_module);

        const lib = b.addLibrary(.{
            .name = "lexica-ios",
            .root_module = mod,
            .linkage = .static,
        });
        if (optimize != .ReleaseFast and optimize != .ReleaseSafe) {
            lib.bundle_ubsan_rt = true;
            lib.bundle_compiler_rt = true;
        }

        b.installArtifact(lib);
        build_number_step.step.dependOn(&lib.step);

        // Copy library into the xcode template project
        const lib_install = b.addInstallLibFile(lib.getEmittedBin(), "../../ios/Lexica/liblexica-ios.a");

        const allocator = std.heap.smp_allocator;
        const ap = b.path(assets);
        const icon1024 = ap.join(allocator, "generated/app-icon-1024x1024.png") catch @panic("OOM");
        const splash = ap.join(allocator, "generated/splash-screen.jpg") catch @panic("OOM");

        b.getInstallStep().dependOn(&b.addInstallFile(splash, "../ios/Lexica/assets/splash-screen.jpg").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon1024, "../ios/Lexica/assets/app-icon-3-full.png").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon1024, "../ios/Lexica/Assets.xcassets/AppIcon.appiconset/app-icon-3-full.png").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon1024, "../ios/Lexica/Assets.xcassets/AppIcon.appiconset/app-icon-3-full 1.png").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon1024, "../ios/Lexica/Assets.xcassets/AppIcon.appiconset/app-icon-3-full 2.png").step);

        b.getInstallStep().dependOn(&lib_install.step);
    }

    if (std.ascii.eqlIgnoreCase("android", platform)) {
        // Build an android shared library
        const target = b.resolveTargetQuery(.{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .android });

        const engine = b.dependency("engine", .{ .target = target, .optimize = optimize });
        const engine_module = engine.module("engine");
        const dep_sdl_module = engine.module("sdl");
        const zigimg = b.dependency("zigimg", .{ .target = target, .optimize = optimize });
        const zigimg_module = zigimg.module("zigimg");
        const resources = engine.builder.dependency("resources", .{ .target = target, .optimize = optimize });
        const resources_module = resources.module("resources");
        const praxis = resources.builder.dependency("praxis", .{ .target = target, .optimize = optimize });
        const praxis_module = praxis.module("praxis");

        const ndk_path = FindNDK.find(b.allocator);
        if (ndk_path == null) {
            std.log.err("lexica android requires the android ndk not found. Specify ANDROID_NDK_HOME", .{});
        } else {
            const loc = ndk_path.?.realpathAlloc(b.allocator, ".") catch |e| {
                std.log.info("error reading ndk path folder. {any}", .{e});
                return;
            };
            defer b.allocator.free(loc);
            std.log.info("lexica for android building with android ndk in {s}", .{loc});
        }

        if (optimize != .ReleaseFast and optimize != .ReleaseSafe) {
            std.log.warn("Building android lib without -Doptimize=ReleaseFast or -Doptomize=ReleaseSafe", .{});
        }

        if (std.mem.eql(u8, app_id, "org.example.lexica")) {
            std.log.warn("Building android lib with default app_id=org.example.lexica", .{});
        }

        const libc_file = b.path("android_libc.txt");
        generate_libc_txt(b.allocator, b, &ndk_path.?) catch @panic("failed to generate libc.txt");

        add_imports(b, &target, engine_module);
        add_imports(b, &target, resources_module);
        add_imports(b, &target, dep_sdl_module);

        const mod = b.createModule(.{
            .root_source_file = b.path("src/android_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        mod.addImport("praxis", praxis_module);
        mod.addImport("resources", resources_module);
        mod.addImport("zigimg", zigimg_module);
        mod.addImport("engine", engine_module);
        mod.addImport("dep_sdl_module", dep_sdl_module);
        mod.addImport("app_info", app_info_module);

        const lib = b.addLibrary(.{
            .name = "lexica-android",
            .root_module = mod,
            .linkage = .dynamic,
        });
        lib.setLibCFile(libc_file);
        if (optimize != .ReleaseFast and optimize != .ReleaseSafe) {
            lib.bundle_ubsan_rt = true;
            lib.bundle_compiler_rt = true;
        }

        b.installArtifact(lib);
        build_number_step.step.dependOn(&lib.step);

        const allocator = std.heap.smp_allocator;
        const ap = b.path(assets);

        //const dictionary = ap.join(allocator, "dictionary.txt") catch @panic("OOM");
        //b.addImport("praxis", praxis_module);
        //try generate_dictionary("assets/dictionary.txt", "resources/448a5B.bin", allocator);

        const icon_512 = ap.join(allocator, "generated/app-icon-1024x1024.png") catch @panic("OOM");
        b.getInstallStep().dependOn(&b.addInstallFile(icon_512, "android/app/src/main/ic_launcher-playstore.png").step);

        const icon_rounded_192 = ap.join(allocator, "generated/app-icon-rounded-192x192.webp") catch @panic("OOM");
        const icon_round_192 = ap.join(allocator, "generated/app-icon-round-192x192.webp") catch @panic("OOM");
        const icon_foreground_432 = ap.join(allocator, "generated/app-icon-foreground-432x432.webp") catch @panic("OOM");
        const icon_background_432 = ap.join(allocator, "generated/app-icon-background-432x432.webp") catch @panic("OOM");
        b.getInstallStep().dependOn(&b.addInstallFile(icon_rounded_192, "../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_round_192, "../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_432, "../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_432, "../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.webp").step);

        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_432, "../android/app/src/main/res/mipmap/ic_launcher_background.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_432, "../android/app/src/main/res/mipmap/ic_launcher_foreground.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_432, "../android/app/src/main/res/mipmap/icon_foreground.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_432, "../android/app/src/main/res/mipmap/icon_background.webp").step);

        const icon_rounded_144 = ap.join(allocator, "generated/app-icon-rounded-144x144.webp") catch @panic("OOM");
        const icon_round_144 = ap.join(allocator, "generated/app-icon-round-144x144.webp") catch @panic("OOM");
        const icon_foreground_324 = ap.join(allocator, "generated/app-icon-foreground-324x324.webp") catch @panic("OOM");
        const icon_background_324 = ap.join(allocator, "generated/app-icon-background-324x324.webp") catch @panic("OOM");
        b.getInstallStep().dependOn(&b.addInstallFile(icon_rounded_144, "../android/app/src/main/res/mipmap-xxhdpi/ic_launcher.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_round_144, "../android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_324, "../android/app/src/main/res/mipmap-xxhdpi/ic_launcher_background.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_324, "../android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.webp").step);

        const icon_rounded_96 = ap.join(allocator, "generated/app-icon-rounded-96x96.webp") catch @panic("OOM");
        const icon_round_96 = ap.join(allocator, "generated/app-icon-round-96x96.webp") catch @panic("OOM");
        const icon_foreground_216 = ap.join(allocator, "generated/app-icon-foreground-216x216.webp") catch @panic("OOM");
        const icon_background_216 = ap.join(allocator, "generated/app-icon-background-216x216.webp") catch @panic("OOM");
        b.getInstallStep().dependOn(&b.addInstallFile(icon_rounded_96, "../android/app/src/main/res/mipmap-xhdpi/ic_launcher.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_round_96, "../android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_216, "../android/app/src/main/res/mipmap-xhdpi/ic_launcher_background.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_216, "../android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.webp").step);

        const icon_rounded_72 = ap.join(allocator, "generated/app-icon-rounded-72x72.webp") catch @panic("OOM");
        const icon_round_72 = ap.join(allocator, "generated/app-icon-round-72x72.webp") catch @panic("OOM");
        const icon_foreground_162 = ap.join(allocator, "generated/app-icon-foreground-162x162.webp") catch @panic("OOM");
        const icon_background_162 = ap.join(allocator, "generated/app-icon-background-162x162.webp") catch @panic("OOM");
        b.getInstallStep().dependOn(&b.addInstallFile(icon_rounded_72, "../android/app/src/main/res/mipmap-hdpi/ic_launcher.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_round_72, "../android/app/src/main/res/mipmap-hdpi/ic_launcher_round.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_162, "../android/app/src/main/res/mipmap-hdpi/ic_launcher_background.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_162, "../android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.webp").step);

        const icon_rounded_48 = ap.join(allocator, "generated/app-icon-rounded-48x48.webp") catch @panic("OOM");
        const icon_round_48 = ap.join(allocator, "generated/app-icon-round-48x48.webp") catch @panic("OOM");
        const icon_foreground_108 = ap.join(allocator, "generated/app-icon-foreground-108x108.webp") catch @panic("OOM");
        const icon_background_108 = ap.join(allocator, "generated/app-icon-background-108x108.webp") catch @panic("OOM");
        b.getInstallStep().dependOn(&b.addInstallFile(icon_rounded_48, "../android/app/src/main/res/mipmap-mdpi/ic_launcher.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_round_48, "../android/app/src/main/res/mipmap-mdpi/ic_launcher_round.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_background_108, "../android/app/src/main/res/mipmap-mdpi/ic_launcher_background.webp").step);
        b.getInstallStep().dependOn(&b.addInstallFile(icon_foreground_108, "../android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.webp").step);

        // Copy library into the android template project
        const lib_install = b.addInstallLibFile(lib.getEmittedBin(), "../../android/app/jni/jniLibs/arm64-v8a/liblexica-android.so");
        b.getInstallStep().dependOn(&lib_install.step);
    }
}

pub fn git_commit_number(b: *std.Build) !usize {
    var code: u8 = 0;
    const out: []const u8 = b.runAllowFail(
        &[_][]const u8{ "git", "-C", b.build_root.path orelse ".", "rev-list", "--count", "HEAD" },
        &code,
        .Ignore,
    ) catch |err| switch (err) {
        error.FileNotFound => return error.GitNotFound,
        error.ExitCodeFailure => return error.GitNotRepository,
        else => return err,
    };
    const trimmed = std.mem.trim(u8, out, " \t\n\r");
    const build_number = try std.fmt.parseUnsigned(u32, trimmed, 10);
    return build_number;
}

const IncrementBuildNumberStep = struct {
    b: *std.Build,
    step: std.Build.Step,
    app_name: []const u8,
    app_version: []const u8,
    app_id: []const u8,
    app_build: []const u8,
    org: []const u8,
    build_number_buffer: [100]u8 = undefined,

    pub fn init(b: *std.Build, app_name: []const u8, app_version: []const u8, app_id: []const u8, org: []const u8) IncrementBuildNumberStep {
        return IncrementBuildNumberStep{
            .b = b,
            .step = std.Build.Step.init(.{ .id = .custom, .name = "increment_build_number", .owner = b, .makeFn = make }),
            .app_name = app_name,
            .app_version = app_version,
            .app_id = app_id,
            .org = org,
            .app_build = "",
        };
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const self: *IncrementBuildNumberStep = @fieldParentPtr("step", step);
        var build_number: usize = 0;

        if (false) {
            // If using text file for build number
            if (std.fs.cwd().readFile(self.path, &self.build_number_buffer)) |build_number_string| {
                self.app_build = std.mem.trim(u8, build_number_string, " \t\n\r");
                build_number = try std.fmt.parseUnsigned(u32, self.app_build, 10);
                build_number += 1;
            } else |e| {
                std.log.warn("Error reading build.txt. {any}", .{e});
                if (e != error.FileNotFound) {
                    return e;
                }
            }
            const file = try std.fs.cwd().createFile(self.path, .{});
            defer file.close();
            _ = try file.writer().print("{d}", .{build_number});
        } else {
            // If using git commit count for build number
            build_number = git_commit_number(self.b) catch |e| {
                std.log.err("Failed to read build number from git history. {any}", .{e});
                @panic("Failed to read build number from git history.");
            };
        }
        build_number += 2000;
        self.app_build = try std.fmt.bufPrint(&self.build_number_buffer, "{d}", .{build_number});
        std.log.info("Build number {d}", .{build_number});
        try update_xcode_variables(
            "ios/Lexica.xcodeproj/project.pbxproj",
            self.app_name,
            self.app_version,
            self.app_id,
            self.app_build,
            std.heap.smp_allocator,
        );
        try update_android_metadata(
            "android/app/src/main/AndroidManifest.xml",
            "android/app/build.gradle",
            "android/app/src/main/res/values/strings.xml",
            self.app_name,
            self.app_version,
            self.app_build,
            std.heap.smp_allocator,
        );
    }
};

const std = @import("std");
const update_xcode_variables = @import("src/xcode_version_update.zig").update_xcode_variables;
const update_android_metadata = @import("src/android_version_update.zig").update_android_metadata;

const add_imports = @import("build/add_imports.zig").add_imports;
const generate_libc_txt = @import("build/add_imports.zig").generate_libc_txt;
const FindNDK = @import("build/add_imports.zig").FindNDK;
//const generate_dictionary = @import("src/build/generate_dictionary.zig").generate_dictionary;
