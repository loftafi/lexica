pub fn build(b: *std.Build) !void {
    comptime {
        const minimum_zig_version = @import("build.zig.zon").minimum_zig_version;
        @import("build/zig_version.zig").requireVersion(minimum_zig_version);
    }

    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};

    const app_name = b.option([]const u8, "app_name", "App name string.");
    const app_version = b.option([]const u8, "app_version", "App version string.");
    const app_id = b.option([]const u8, "app_id", "override the app id") orelse "org.example.app";
    const app_owner = b.option([]const u8, "app_owner", "App person or company string");
    const org = b.option([]const u8, "org", "App org name string.");
    const app_bundle = b.option([]const u8, "app_bundle", "Default app bundle name.");
    const app_resources = b.option([]const u8, "app_resources", "Default app resources folder.");
    const bundle_cache = b.option([]const u8, "bundle_cache", "Default app resource bundle cache.");
    const dev_mode = b.option(bool, "dev_mode", "Include debug symbols and trace log messages.");

    const app_info = b.addOptions();
    app_info.addOption([]const u8, "app_full_name", app_name orelse "Lexica");
    app_info.addOption([]const u8, "app_version", app_version orelse @import("build.zig.zon").version);
    app_info.addOption([]const u8, "app_owner", (app_owner orelse "the author"));
    app_info.addOption([]const u8, "org", (org orelse "lexica"));
    app_info.addOption([]const u8, "app_resources", app_resources orelse "resources");
    app_info.addOption([]const u8, "app_bundle", app_bundle orelse "app_bundle.bd");
    app_info.addOption([]const u8, "bundle_cache", bundle_cache orelse "/tmp/");
    app_info.addOption(bool, "dev_mode", dev_mode orelse true);
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
    if (app_bundle) |app_bundle_name| {
        if (app_resources) |folder| {
            var make_bundle = b.addRunArtifact(exe);
            make_bundle.has_side_effects = true;
            make_bundle.addArg("make_bundle");
            make_bundle.addDirectoryArg(b.graph.path(.install_prefix, app_bundle_name));
            make_bundle.addDirectoryArg(b.path(folder));
            app_resource_package.dependOn(&make_bundle.step);
        } else {
            app_resource_package.dependOn(&b.addFail("Specify -Dapp_resources to build a pacakge.").step);
        }
    } else {
        app_resource_package.dependOn(&b.addFail("Specify -Dapp_bundle to build a package").step);
    }

    {
        //
        // iOS
        //
        const ios_optimize_mode: std.builtin.OptimizeMode = .ReleaseFast;
        const ios_target = b.resolveTargetQuery(.{ .os_tag = .ios, .cpu_arch = .aarch64 });
        const ios_imports = try buildImports(b, &ios_target, ios_optimize_mode, app_info_module);
        const ios_app_name = b.option([]const u8, "ios_app_name", "iOS app name.");
        const ios_app_version = b.option([]const u8, "ios_app_version", "iOS app version.");
        const ios_app_bundle = b.option([]const u8, "ios_app_bundle", "Default app resource bundle filename.");
        const ios_app_id = b.option([]const u8, "ios_app_id", "iOS the app id.");
        const ios_splash_screen = b.option(std.Build.LazyPath, "ios_splash_screen", "iOS app startup splash screen jpg.");
        const ios_icon = b.option(std.Build.LazyPath, "ios_icon", "The iOS icon png.");
        const ios_icon_light = b.option(std.Build.LazyPath, "ios_icon_light", "The light iOS icon png.");
        const ios_icon_dark = b.option(std.Build.LazyPath, "ios_icon_dark", "The dark iOS icon png.");

        const ios_step = b.step("ios", "Build package for iOS");
        ios_step.dependOn(app_resource_package);

        const ios_export_step = b.dependency("engine", .{
            .ios_app_name = ios_app_name orelse app_name orelse "Lexica",
            .ios_app_id = ios_app_id orelse app_id,
            .ios_app_version = ios_app_version orelse app_version orelse @import("build.zig.zon").version,
            .ios_splash_screen = ios_splash_screen,
            .ios_app_bundle = ios_app_bundle,
            .ios_icon = ios_icon,
            .ios_icon_light = ios_icon_light,
            .ios_icon_dark = ios_icon_dark,
        }).builder.top_level_steps.get("export_xcode_template") orelse @panic("export step missing").step;
        ios_step.dependOn(&ios_export_step.step);

        //var r = b.run("xcodebuild -project MyApp.xcodeproj -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 14' build");
        //var r2 = b.rum("xcodebuild archive -workspace App.xcworkspace -scheme YourScheme -archivePath App.xcarchive");

        const ios_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = ios_target,
            .optimize = ios_optimize_mode,
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

        if (ios_optimize_mode == .Debug) {
            ios_lib.bundle_ubsan_rt = true;
        }

        //var install_ios_lib = b.addInstallFile(ios_lib.getEmittedBin(), "xcode/Dialectos/libdialectos-ios.a");
        const install_ios_lib = b.addInstallLibFile(ios_lib.getEmittedBin(), "../xcode/Dialectos/libdialectos-ios.a");
        install_ios_lib.step.dependOn(&ios_export_step.step);
        install_ios_lib.step.dependOn(&ios_lib.step);
        ios_step.dependOn(&install_ios_lib.step);
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
        const android_optimize_mode: std.builtin.OptimizeMode = .ReleaseFast;
        const android_target = b.resolveTargetQuery(.{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .android });
        const android_imports = try buildImports(b, &android_target, android_optimize_mode, app_info_module);
        const android_app_name = b.option([]const u8, "android_app_name", "Android app name.");
        const android_app_id = b.option([]const u8, "android_app_id", "Android app id.");
        const android_app_version = b.option([]const u8, "android_app_version", "Android app version.");
        const android_icon = b.option(std.Build.LazyPath, "android_icon", "The android icon png.");
        const android_app_bundle = b.option([]const u8, "android_app_bundle", "Default app resource bundle filename.");

        const android_icon_circle_192 = b.option(std.Build.LazyPath, "android_icon_circle_192", "Circle 192px android icon png.");
        const android_icon_circle_144 = b.option(std.Build.LazyPath, "android_icon_circle_144", "Circle 144px android icon png.");
        const android_icon_circle_96 = b.option(std.Build.LazyPath, "android_icon_circle_96", "Circle 96px android icon png.");
        const android_icon_circle_72 = b.option(std.Build.LazyPath, "android_icon_circle_72", "Circle 72px android icon png.");
        const android_icon_circle_48 = b.option(std.Build.LazyPath, "android_icon_circle_48", "Circle 48px android icon png.");
        const android_icon_rounded_192 = b.option(std.Build.LazyPath, "android_icon_rounded_192", "Rounded 192px android icon png.");
        const android_icon_rounded_144 = b.option(std.Build.LazyPath, "android_icon_rounded_144", "Rounded 144px android icon png.");
        const android_icon_rounded_96 = b.option(std.Build.LazyPath, "android_icon_rounded_96", "Rounded 96px android icon png.");
        const android_icon_rounded_72 = b.option(std.Build.LazyPath, "android_icon_rounded_72", "Rounded 72px android icon png.");
        const android_icon_rounded_48 = b.option(std.Build.LazyPath, "android_icon_rounded_48", "Rounded 48px android icon png.");
        const android_icon_foreground_432 = b.option(std.Build.LazyPath, "android_icon_foreground_192", "Foreground 192px android icon png.");
        const android_icon_foreground_324 = b.option(std.Build.LazyPath, "android_icon_foreground_48", "Foreground 48px android icon png.");
        const android_icon_foreground_216 = b.option(std.Build.LazyPath, "android_icon_foreground_144", "Foreground 144px android icon png.");
        const android_icon_foreground_162 = b.option(std.Build.LazyPath, "android_icon_foreground_96", "Foreground 96px android icon png.");
        const android_icon_foreground_108 = b.option(std.Build.LazyPath, "android_icon_foreground_72", "Foreground 72px android icon png.");
        const android_icon_background_432 = b.option(std.Build.LazyPath, "android_icon_background_432", "Foreground 192px android icon png.");
        const android_icon_background_324 = b.option(std.Build.LazyPath, "android_icon_background_324", "Foreground 144px android icon png.");
        const android_icon_background_216 = b.option(std.Build.LazyPath, "android_icon_background_216", "Foreground 96px android icon png.");
        const android_icon_background_162 = b.option(std.Build.LazyPath, "android_icon_background_162", "Foreground 72px android icon png.");
        const android_icon_background_108 = b.option(std.Build.LazyPath, "android_icon_background_108", "Foreground 48px android icon png.");

        const android_step = b.step("android", "Build package for android");
        android_step.dependOn(app_resource_package);

        const android_export_step = b.dependency("engine", .{
            .android_app_name = android_app_name orelse app_name orelse "Lexica",
            .android_app_id = android_app_id orelse app_id,
            .android_app_version = android_app_version orelse app_version orelse @import("build.zig.zon").version,
            //.android_splash_screen = android_splash_screen,
            .android_app_bundle = android_app_bundle,
            .android_icon = android_icon,
            .android_icon_circle_192 = android_icon_circle_192,
            .android_icon_circle_144 = android_icon_circle_144,
            .android_icon_circle_96 = android_icon_circle_96,
            .android_icon_circle_72 = android_icon_circle_72,
            .android_icon_circle_48 = android_icon_circle_48,
            .android_icon_rounded_192 = android_icon_rounded_192,
            .android_icon_rounded_144 = android_icon_rounded_144,
            .android_icon_rounded_96 = android_icon_rounded_96,
            .android_icon_rounded_72 = android_icon_rounded_72,
            .android_icon_rounded_48 = android_icon_rounded_48,
            .android_icon_foreground_432 = android_icon_foreground_432,
            .android_icon_foreground_324 = android_icon_foreground_324,
            .android_icon_foreground_216 = android_icon_foreground_216,
            .android_icon_foreground_162 = android_icon_foreground_162,
            .android_icon_foreground_108 = android_icon_foreground_108,
            .android_icon_background_432 = android_icon_background_432,
            .android_icon_background_324 = android_icon_background_324,
            .android_icon_background_216 = android_icon_background_216,
            .android_icon_background_162 = android_icon_background_162,
            .android_icon_background_108 = android_icon_background_108,
        }).builder.top_level_steps.get("export_android_template") orelse @panic("export android step missing").step;
        android_step.dependOn(&android_export_step.step);
        android_export_step.step.dependOn(app_resource_package);

        if (!b.graph.environ_map.contains("ANDROID_NDK_HOME") and !b.graph.environ_map.contains("ANDROID_SDK_ROOT")) {
            app_resource_package.dependOn(&b.addFail("The `android` build step requires ANDROID_NDK_HOME or ANDROID_SDK_ROOT to be set.").step);
        }

        const android_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = android_target,
            .optimize = android_optimize_mode,
            .imports = &android_imports,
        });

        const android_lib = b.addLibrary(.{
            .name = "lexica-android",
            .root_module = android_module,
            .linkage = .dynamic,
        });
        android_lib.step.dependOn(&android_export_step.step);
        android_lib.setLibCFile(b.graph.path(.install_prefix, "android/libc.txt"));
        android_lib.bundle_compiler_rt = true;
        //if (android_optimize_mode == .Debug)
        //    android_lib.bundle_ubsan_rt = true;
        //android_lib.bundle_ubsan_rt = true;

        // https://developer.android.com/guide/practices/page-sizes
        android_lib.link_z_common_page_size = 16 * 1024;

        const android_lib_install = b.addInstallLibFile(android_lib.getEmittedBin(), "../android/app/jni/jniLibs/arm64-v8a/liblexica-android.so");
        android_lib_install.step.dependOn(&android_lib.step);
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
const androidTriple = @import("build/android_template_update.zig").androidTriple;
