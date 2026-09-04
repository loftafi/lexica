pub fn build(b: *std.Build) !void {
    comptime {
        const minimum_zig_version = @import("build.zig.zon").minimum_zig_version;
        @import("build/zig_version.zig").requireVersion(minimum_zig_version);
    }

    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};

    const app_name = b.option([]const u8, "app_name", "override the app name") orelse "Lexica";
    const app_version = @import("build.zig.zon").version;
    const org = b.option([]const u8, "org", "override the org") orelse "lexica";
    const app_owner = b.option([]const u8, "app_owner", "person or company in terms and conditions") orelse "the author";
    const app_bundle = b.option([]const u8, "app_bundle", "override the app bundle filename") orelse "app_bundle.bd";
    const app_resources = b.option([]const u8, "app_resources", "override the app resource folder") orelse "resources";
    const bundle_cache = b.option([]const u8, "bundle_cache", "override the bundle cache") orelse "/tmp/";
    const dev_mode = b.option(bool, "dev_mode", "include developer mode functions") orelse true;

    const app_id = b.option([]const u8, "app_id", "override the app id") orelse
        "org.example.lexica";
    const splash_screen = b.option(std.Build.LazyPath, "splash_screen", "Path to splash screen jpg") orelse
        b.path("assets/generated/splash-screen.jpg");
    const ios_icon = b.option(std.Build.LazyPath, "ios_icon", "Path to ios icon png") orelse
        b.path("assets/generated/app-icon-1024x1024.png");

    const app_info = b.addOptions();
    app_info.addOption([]const u8, "app_full_name", app_name);
    app_info.addOption([]const u8, "app_version", app_version);
    app_info.addOption([]const u8, "app_id", app_id);
    app_info.addOption([]const u8, "org", org);
    app_info.addOption([]const u8, "app_resources", app_resources);
    app_info.addOption([]const u8, "app_owner", app_owner);
    app_info.addOption([]const u8, "app_bundle", app_bundle);
    app_info.addOption([]const u8, "bundle_cache", bundle_cache);
    app_info.addOption(bool, "dev_mode", dev_mode);
    const app_info_module = app_info.createModule();

    // Normal build/test/run uses current default target for this system.
    var target = b.standardTargetOptions(.{});
    const imports = buildImports(b, &target, optimize, app_info_module) catch unreachable;
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &imports,
    });

    const exe = b.addExecutable(.{
        .name = "lexica",
        .root_module = mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &imports,
    });
    const real_tests = b.addTest(.{
        .root_module = test_mod,
        .filters = test_filters,
    });
    const run_real_tests = b.addRunArtifact(real_tests);

    const exe_unit_tests = b.addTest(.{ .root_module = mod });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_real_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    const pre_app_resource_package = b.step("pre-package", "Create the app bundle file");
    pre_app_resource_package.dependOn(test_step);
    pre_app_resource_package.dependOn(b.getInstallStep());

    const app_resource_package = b.step("package", "Create the app bundle file");
    app_resource_package.dependOn(pre_app_resource_package);
    var make_bundle = b.addRunArtifact(exe);
    make_bundle.has_side_effects = true;
    make_bundle.addArg("make_bundle");
    make_bundle.addDirectoryArg(b.path(app_resources));
    app_resource_package.dependOn(&make_bundle.step);

    {
        const simulator_step = b.step("simulator", "Build library for simulator");
        //simulator_step.dependOn(&xcode_config.step);
        const simulator_target = b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .aarch64, .abi = .simulator });
        const simulator_imports = try buildImports(b, &simulator_target, optimize, app_info_module);

        const simulator_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = simulator_target,
            .optimize = optimize,
            .imports = &simulator_imports,
        });

        simulator_mod.linkSystemLibrary("objc", .{});
        simulator_mod.linkFramework("Foundation", .{});
        simulator_mod.linkFramework("CoreFoundation", .{}); // needed?
        simulator_mod.linkFramework("UserNotifications", .{});
        //try addAppleSDK(b, simulator_mod, &simulator_target);

        const simulator_lib = b.addLibrary(.{
            .name = "lexica-ios-simulator",
            .root_module = simulator_mod,
            .linkage = .static,
        });
        simulator_lib.bundle_compiler_rt = true;
        if (optimize != .ReleaseFast and optimize != .ReleaseSafe) {
            simulator_lib.bundle_ubsan_rt = true;
        }

        var simulator_lib_install = b.addInstallLibFile(simulator_lib.getEmittedBin(), "../xcode/Dialectos/libdialectos-ios-simulator.so");
        simulator_step.dependOn(&simulator_lib_install.step);
    }

    {
        //
        // iOS
        //
        const mode: std.builtin.OptimizeMode = .ReleaseFast;
        const ios_target = b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .aarch64 });
        const ios_imports = try buildImports(b, &ios_target, mode, app_info_module);

        // Copy the xcode template
        var copy_xcode_template = b.step("xcode_template_copy", "Copy ios template");
        const template_path = b.dependency("engine", .{}).path("templates/xcode/");
        const do_copy = b.addInstallDirectory(.{
            .source_dir = template_path,
            .install_dir = .{ .custom = "xcode/" },
            .install_subdir = "",
        });
        copy_xcode_template.dependOn(&do_copy.step);

        // Ammend the xcode template with project information
        var patch_xcode_template = b.step("patch_xcode_template", "Update the xcode template");
        patch_xcode_template.dependOn(copy_xcode_template);
        patch_xcode_template.dependOn(app_resource_package);
        const xcode_template_update = b.addExecutable(.{
            .name = "xcode_template_update",
            .root_module = b.createModule(.{
                .root_source_file = b.path("build/xcode_template_update.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        var run_xcode_update = b.addRunArtifact(xcode_template_update);
        run_xcode_update.addFileArg(b.path("."));
        run_xcode_update.addFileArg(b.path("zig-out/xcode/Dialectos.xcodeproj/project.pbxproj"));
        run_xcode_update.addArg(app_name);
        run_xcode_update.addArg(app_version);
        run_xcode_update.addArg(app_id);
        run_xcode_update.has_side_effects = true;
        run_xcode_update.step.dependOn(copy_xcode_template);
        patch_xcode_template.dependOn(&run_xcode_update.step);

        // ios step depends on `patch_xcode_template` depends on `copy_xcode_template`
        const ios_step = b.step("ios", "Build library for ios");
        copyStep(b, ios_step, patch_xcode_template, app_bundle, "xcode/Dialectos/app_bundle.bd");
        copyStepP(b, ios_step, patch_xcode_template, splash_screen, "xcode/startup-screen.jpg");
        copyStepP(b, ios_step, patch_xcode_template, ios_icon, "xcode/Dialectos/Assets.xcassets/AppIcon.appiconset/app-icon-3-full.png");
        copyStepP(b, ios_step, patch_xcode_template, ios_icon, "xcode/Dialectos/Assets.xcassets/AppIcon.appiconset/app-icon-3-full 1.png");
        copyStepP(b, ios_step, patch_xcode_template, ios_icon, "xcode/Dialectos/Assets.xcassets/AppIcon.appiconset/app-icon-3-full 2.png");

        //var r = b.run("xcodebuild -project MyApp.xcodeproj -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 14' build");
        //var r2 = b.rum("xcodebuild archive -workspace App.xcworkspace -scheme YourScheme -archivePath App.xcarchive");

        if (std.mem.eql(u8, app_id, "org.example.lexica"))
            std.log.warn("Building ios lib with default app_id=org.example.lexica", .{});

        const ios_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = ios_target,
            .optimize = mode,
            .imports = &ios_imports,
        });

        ios_mod.linkSystemLibrary("objc", .{});
        ios_mod.linkFramework("Foundation", .{});
        ios_mod.linkFramework("CoreFoundation", .{}); // needed?
        ios_mod.linkFramework("UserNotifications", .{});

        const ios_lib = b.addLibrary(.{
            .name = "lexica-ios",
            .root_module = ios_mod,
            .linkage = .static,
        });
        ios_lib.bundle_compiler_rt = true;

        if (mode != .ReleaseFast and mode != .ReleaseSafe) {
            ios_lib.bundle_ubsan_rt = true;
        }

        ios_step.dependOn(&b.addInstallFile(ios_lib.getEmittedBin(), "xcode/Dialectos/libdialectos-ios.a").step);
    }

    const clean_step = b.step("clean", "Clean temporary files");
    const rm_clean = b.addSystemCommand(&.{
        "rm",
        "-rf",
        "zig-out",
        "zig-pkg",
        ".zig-cache",
        ".DS_Store",
    });
    clean_step.dependOn(&rm_clean.step);

    {
        //
        // Android
        //
        const mode: std.builtin.OptimizeMode = .ReleaseFast;
        const android_target = b.resolveTargetQuery(.{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .android });
        const android_imports = try buildImports(b, &android_target, mode, app_info_module);

        // Copy the android template
        var copy_android_template = b.step("android_template_copy", "Copy android template");
        const template_path = b.dependency("engine", .{}).path("templates/android/");
        const do_copy = b.addInstallDirectory(.{
            .source_dir = template_path,
            .install_dir = .{ .custom = "android/" },
            .install_subdir = "",
        });
        copy_android_template.dependOn(&do_copy.step);

        // Ammend the android template with project information
        var patch_android_template = b.step("patch_android_template", "Update the android template");
        patch_android_template.dependOn(copy_android_template);
        patch_android_template.dependOn(app_resource_package);
        const android_update_exe = b.addExecutable(.{
            .name = "android_template_update",
            .root_module = b.createModule(.{
                .root_source_file = b.path("build/android_template_update.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        var run_android_update = b.addRunArtifact(android_update_exe);
        run_android_update.addFileArg(b.path("."));
        run_android_update.addFileArg(b.path("zig-out/android/libc.txt"));
        run_android_update.addArg(app_name);
        run_android_update.addArg(app_version);
        run_android_update.has_side_effects = true;
        run_android_update.step.dependOn(copy_android_template);
        patch_android_template.dependOn(&run_android_update.step);

        const android_step = b.step("android", "Build library for android");
        android_step.dependOn(app_resource_package);
        android_step.dependOn(&run_android_update.step);
        android_step.dependOn(&b.addInstallFile(b.path("app_bundle.bd"), "android/Dialectos/app_bundle.bd").step);

        const copy = .{
            .{ "assets/generated/app-icon-1024x1024.png", "android/app/src/main/ic_launcher-playstore.png" },
            .{ "assets/generated/app-icon-rounded-192x192.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.webp" },
            .{ "assets/generated/app-icon-round-192x192.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.webp" },
            .{ "assets/generated/app-icon-foreground-432x432.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.webp" },
            .{ "assets/generated/app-icon-background-432x432.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-1024x1024.png", "android/app/src/main/ic_launcher-playstore.png" },
            .{ "assets/generated/app-icon-rounded-192x192.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.webp" },
            .{ "assets/generated/app-icon-round-192x192.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.webp" },
            .{ "assets/generated/app-icon-background-432x432.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.webp" },
            .{ "assets/generated/app-icon-foreground-432x432.webp", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-background-432x432.webp", "android/app/src/main/res/mipmap/ic_launcher_background.webp" },
            .{ "assets/generated/app-icon-foreground-432x432.webp", "android/app/src/main/res/mipmap/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-foreground-432x432.webp", "android/app/src/main/res/mipmap/icon_foreground.webp" },
            .{ "assets/generated/app-icon-background-432x432.webp", "android/app/src/main/res/mipmap/icon_background.webp" },
            .{ "assets/generated/app-icon-rounded-144x144.webp", "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.webp" },
            .{ "assets/generated/app-icon-round-144x144.webp", "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.webp" },
            .{ "assets/generated/app-icon-foreground-324x324.webp", "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-background-324x324.webp", "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_background.webp" },
            .{ "assets/generated/app-icon-rounded-96x96.webp", "android/app/src/main/res/mipmap-xhdpi/ic_launcher.webp" },
            .{ "assets/generated/app-icon-round-96x96.webp", "android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.webp" },
            .{ "assets/generated/app-icon-foreground-216x216.webp", "android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-background-216x216.webp", "android/app/src/main/res/mipmap-xhdpi/ic_launcher_background.webp" },
            .{ "assets/generated/app-icon-rounded-72x72.webp", "android/app/src/main/res/mipmap-hdpi/ic_launcher.webp" },
            .{ "assets/generated/app-icon-round-72x72.webp", "android/app/src/main/res/mipmap-hdpi/ic_launcher_round.webp" },
            .{ "assets/generated/app-icon-foreground-162x162.webp", "android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-background-162x162.webp", "android/app/src/main/res/mipmap-hdpi/ic_launcher_background.webp" },
            .{ "assets/generated/app-icon-rounded-48x48.webp", "android/app/src/main/res/mipmap-mdpi/ic_launcher.webp" },
            .{ "assets/generated/app-icon-round-48x48.webp", "android/app/src/main/res/mipmap-mdpi/ic_launcher_round.webp" },
            .{ "assets/generated/app-icon-foreground-108x108.webp", "android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.webp" },
            .{ "assets/generated/app-icon-background-108x108.webp", "android/app/src/main/res/mipmap-mdpi/ic_launcher_background.webp" },
        };

        inline for (copy) |cp| {
            copyStep(b, android_step, patch_android_template, cp[0], cp[1]);
        }

        if (std.mem.eql(u8, app_id, "org.example.lexica"))
            std.log.warn("Building android lib with default app_id=org.example.lexica", .{});

        const android_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = android_target,
            .optimize = mode,
            .imports = &android_imports,
        });

        const android_lib = b.addLibrary(.{
            .name = "lexica-android",
            .root_module = android_module,
            .linkage = .dynamic,
        });
        android_lib.setLibCFile(b.path("android_libc.txt"));
        //android_lib.setLibCFile(b.path("zig-out/android/libc.txt"));
        android_lib.bundle_compiler_rt = true;
        if (mode != .ReleaseFast and mode != .ReleaseSafe) {
            android_lib.bundle_ubsan_rt = true;
        }

        // https://developer.android.com/guide/practices/page-sizes
        android_lib.link_z_common_page_size = 16 * 1024;

        const android_lib_install = b.addInstallLibFile(android_lib.getEmittedBin(), "../../android/app/jni/jniLibs/arm64-v8a/libdialectos-android.so");
        android_step.dependOn(&android_lib_install.step);
    }
}

fn copyStep(b: *std.Build, before: *std.Build.Step, after: *std.Build.Step, src: []const u8, dst: []const u8) void {
    var cp = b.addInstallFile(b.path(src), dst);
    cp.step.dependOn(after);
    before.dependOn(&cp.step);
}

fn copyStepP(b: *std.Build, before: *std.Build.Step, after: *std.Build.Step, src: std.Build.LazyPath, dst: []const u8) void {
    var cp = b.addInstallFile(src, dst);
    cp.step.dependOn(after);
    before.dependOn(&cp.step);
}

fn buildImports(
    b: *std.Build,
    target: *const std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    app_info: *std.Build.Module,
) ![7]std.Build.Module.Import {
    const engine = b.dependency("engine", .{ .target = target.*, .optimize = optimize });
    const engine_module = engine.module("engine");
    const resources = engine.builder.dependency("resources", .{ .target = target.*, .optimize = optimize });
    const resources_module = resources.module("resources");
    const praxis = resources.builder.dependency("praxis", .{ .target = target.*, .optimize = optimize });
    const praxis_module = praxis.module("praxis");
    const translator = engine.builder.dependency("translator", .{ .target = target.*, .optimize = optimize });
    const translator_module = translator.module("translator");
    const zeit = b.dependency("zeit", .{ .target = target.*, .optimize = optimize });
    const zeit_module = zeit.module("zeit");

    if (target.*.result.os.tag == .ios or target.*.result.os.tag == .macos) {
        const objc = b.dependency("zig_objc", .{ .target = target.*, .optimize = optimize });
        const objc_module = objc.module("objc");
        //addSystemPathsToModule(b, target, objc_module);
        return .{
            .{ .name = "app_info", .module = app_info },
            .{ .name = "praxis", .module = praxis_module },
            .{ .name = "resources", .module = resources_module },
            .{ .name = "zeit", .module = zeit_module },
            .{ .name = "engine", .module = engine_module },
            .{ .name = "objc", .module = objc_module },
            .{ .name = "translator", .module = translator_module },
        };
    } else {
        return .{
            .{ .name = "app_info", .module = app_info },
            .{ .name = "praxis", .module = praxis_module },
            .{ .name = "resources", .module = resources_module },
            .{ .name = "zeit", .module = zeit_module },
            .{ .name = "engine", .module = engine_module },
            .{ .name = "engine", .module = engine_module },
            .{ .name = "translator", .module = translator_module },
        };
    }
}

/// If running on mac, and if xcode is installed, add the apple SDK using xcrun.
pub fn addAppleSDK(
    b: *std.Build,
    m: *std.Build.Module,
    target: *const std.Build.ResolvedTarget,
) !void {
    const Result = struct {
        const Value = struct {
            arch: std.Target.Cpu.Arch,
            os: std.Target.Os.Tag,
            abi: std.Target.Abi,
        };
        var map: std.AutoHashMapUnmanaged(Value, ?[]const u8) = .{};
    };

    const found = try Result.map.getOrPut(b.allocator, .{
        .os = target.result.os.tag,
        .abi = target.result.abi,
        .arch = target.result.cpu.arch,
    });

    if (!found.found_existing) {
        found.value_ptr.* = std.zig.system.darwin.getSdk(
            b.allocator,
            b.graph.io,
            &m.resolved_target.?.result,
        );
    }

    const path = found.value_ptr.* orelse return switch (target.result.os.tag) {
        .macos => error.XcodeMacOSSDKNotFound,
        .ios => error.XcodeiOSSDKNotFound,
        .tvos => error.XcodeTVOSSDKNotFound,
        .watchos => error.XcodeWatchOSSDKNotFound,
        else => error.XcodeAppleSDKNotFound,
    };
    m.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ path, "/usr/lib" }) });
    m.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ path, "/usr/include" }) });
    m.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ path, "/System/Library/Frameworks" }) });
}

const std = @import("std");
const addSystemPathsToModule = @import("build/addSystemPathsToModule.zig").addSystemPathsToModule;
const androidTriple = @import("build/android_template_update.zig").androidTriple;
