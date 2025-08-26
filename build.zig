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
        const libc_file = b.path("android_libc.txt");
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

/// Attempt to find the location of the NDK by searching ANDROID_NDK_HOME,
/// ANDROID_SDK_ROOT, and fallback to searching known locations inside the
/// user home folder.
const FindNDK = struct {
    const ndk_versions = [_][]const u8{
        "29.0.13846066", // Pre-release
        "28.2.13676358", // Stable
        "27.3.13750724", // LTS
        "27.0.12077973",
        "25.1.8937393",
        "23.2.8568313",
        "23.1.7779620",
        "21.0.6113669",
        "20.1.5948944",
    };

    pub fn find(gpa: std.mem.Allocator) ?std.fs.Dir {
        const android_ndk_home = find_android_ndk_home(gpa) catch |e| {
            std.log.err("error while searching for ndk: {any}", .{e});
            return null;
        };
        if (android_ndk_home != null) return android_ndk_home.?;

        const android_sdk_root = find_android_sdk_root(gpa) catch |e| {
            std.log.err("error while searching for sdk: {any}", .{e});
            return null;
        };
        if (android_sdk_root != null) {
            if (android_sdk_root.?.openDir("ndk", .{})) |dir| {
                std.log.debug("searching inside ANDROID_SDK_ROOT/ndk", .{});
                const found = search_ndk_folder(gpa, dir);
                if (found != null) return found.?;
            } else |_| {
                std.log.debug("no ndk in ANDROID_SDK_ROOT", .{});
            }
        }

        const home = find_user_home(gpa) catch |e| {
            std.log.err("error while searching for ndk: {any}", .{e});
            return null;
        };
        if (home == null) {
            std.log.err("ndk not found. No HOME or USERPROFILE set.", .{});
            return null;
        }
        const ndk_base = home.?.openDir("Library/Android/sdk/ndk/", .{}) catch |e| {
            std.log.err("ndk not found. Error {any} reading HOME/Library/Android/sdk/ndk/", .{e});
            return null;
        };
        return search_ndk_folder(gpa, ndk_base);
    }

    pub fn search_ndk_folder(_: std.mem.Allocator, ndk_base: std.fs.Dir) ?std.fs.Dir {
        for (ndk_versions) |version| {
            const folder = ndk_base.openDir(version, .{}) catch {
                std.log.debug("ndk version {s} not found", .{version});
                continue;
            };
            std.log.debug("ndk version found: {any}", .{folder});
            return folder;
        }
        return null;
    }

    /// If ANDROID_NDK_HOME is set, just use that
    pub fn find_android_ndk_home(gpa: std.mem.Allocator) !?std.fs.Dir {
        var env_map = try std.process.getEnvMap(gpa);
        defer env_map.deinit();
        var iter = env_map.iterator();
        var home: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (std.ascii.eqlIgnoreCase("ANDROID_NDK_HOME", entry.key_ptr.*)) {
                home = entry.value_ptr.*;
                break;
            }
        }
        if (home == null) {
            std.log.info("ANDROID_NDK_HOME not set.", .{});
            return null;
        }
        const d = std.fs.openDirAbsolute(home.?, .{}) catch {
            std.log.warn("Failed to read ANDROID_NDK_HOME directory {any}", .{home.?});
            return null;
        };
        return d;
    }

    /// If ANDROID_SDK_ROOT is set, just use that
    pub fn find_android_sdk_root(gpa: std.mem.Allocator) !?std.fs.Dir {
        var env_map = try std.process.getEnvMap(gpa);
        defer env_map.deinit();
        var iter = env_map.iterator();
        var home: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (std.ascii.eqlIgnoreCase("ANDROID_SDK_ROOT", entry.key_ptr.*)) {
                home = entry.value_ptr.*;
                break;
            }
        }
        if (home == null) {
            std.log.info("ANDROID_SDK_ROOT not set.", .{});
            return null;
        }
        const d = std.fs.openDirAbsolute(home.?, .{}) catch {
            std.log.warn("Failed to read ANDROID_SDK_ROOT directory {any}", .{home.?});
            return null;
        };
        return d;
    }

    /// Sometimes, the NDK is in the users home folder
    pub fn find_user_home(gpa: std.mem.Allocator) !?std.fs.Dir {
        var env_map = try std.process.getEnvMap(gpa);
        defer env_map.deinit();
        var iter = env_map.iterator();
        var home: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (std.ascii.eqlIgnoreCase("HOME", entry.key_ptr.*)) {
                home = entry.value_ptr.*;
            }
            if (std.ascii.eqlIgnoreCase("UserProfile", entry.key_ptr.*)) {
                home = entry.value_ptr.*;
            }
        }
        if (home != null) {
            const d = std.fs.openDirAbsolute(home.?, .{}) catch {
                std.log.warn("Failed to read directory {any}", .{home.?});
                return null;
            };
            return d;
        }
        return null;
    }
};

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

pub fn add_imports(
    b: *std.Build,
    target: *const std.Build.ResolvedTarget,
    lib: *std.Build.Module,
) void {
    // For TranslateC to work, we need the system library headers
    switch (target.result.os.tag) {
        .macos => {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target.result) orelse
                @panic("macOS SDK is missing");
            lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{
                sdk,
                "/usr/include",
            }) });
            lib.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{
                sdk,
                "/System/Library/Frameworks",
            }) });
        },
        .ios => {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target.result) orelse
                @panic("macOS SDK is missing");
            lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{
                sdk,
                "/usr/include",
            }) });
            lib.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{
                sdk,
                "/System/Library/Frameworks",
            }) });
        },
        .linux => {
            // When building for android, we need to use the android linux headers
            if (FindNDK.find(b.allocator)) |android_ndk| {
                const ndk_location = android_ndk.realpathAlloc(b.allocator, ".") catch {
                    @panic("printing ndk path failed");
                };
                defer b.allocator.free(ndk_location);
                lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{
                    ndk_location,
                    "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include/",
                }) });
                lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{
                    ndk_location,
                    "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include/aarch64-linux-android/",
                }) });
            } else {
                @panic("android/linux build requires ndk. Set ANDROID_NDK_HOME");
            }
        },
        else => {
            std.log.debug(
                "add_imports not supported on {s}",
                .{@tagName(target.result.os.tag)},
            );
            @panic("add_imports only supports macos, ios, and linux. Please add windows support");
        },
    }
}

const std = @import("std");
const update_xcode_variables = @import("src/xcode_version_update.zig").update_xcode_variables;
const update_android_metadata = @import("src/android_version_update.zig").update_android_metadata;
//const generate_dictionary = @import("src/build/generate_dictionary.zig").generate_dictionary;
