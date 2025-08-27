pub const std = @import("std");

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
            if (target.result.abi == .android) {
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
            } else {
                @panic("add_imports currently supports macos, ios, and android.");
            }
        },
        else => {
            std.log.debug(
                "add_imports not supported on {s}",
                .{@tagName(target.result.os.tag)},
            );
            @panic("add_imports only supports macos, ios, and android.");
        },
    }
}

/// Attempt to find the location of the NDK by searching ANDROID_NDK_HOME,
/// ANDROID_SDK_ROOT, and fallback to searching known locations inside the
/// user home folder.
pub const FindNDK = struct {
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

pub fn generate_libc_txt(
    gpa: std.mem.Allocator,
    b: *const std.Build,
    ndk: *const std.fs.Dir,
) !void {
    var libc_txt = std.ArrayList(u8).init(gpa);
    errdefer libc_txt.deinit();
    var out = libc_txt.writer();

    // i.e. include_dir=/Users/username/Library/Android/sdk/ndk27.3.13750724/27.0.12077973/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include
    const include_dir = try ndk.realpathAlloc(gpa, "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include");
    defer gpa.free(include_dir);
    try out.print("include_dir={s}\n", .{include_dir});

    // The system-specific include directory. May be the same as `include_dir`.
    // On Windows it's the directory that includes `vcruntime.h`.
    // On POSIX it's the directory that includes `sys/errno.h`.
    //
    // i.e. sys_include_dir=/Users/username/Library/Android/sdk/ndk27.3.13750724/27.0.12077973/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include
    const sys_include_dir = try ndk.realpathAlloc(gpa, "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include");
    defer gpa.free(sys_include_dir);
    try out.print("sys_include_dir={s}\n", .{sys_include_dir});

    // The directory that contains `crt1.o` or `crt2.o`.
    // On POSIX, can be found with `cc -print-file-name=crt1.o`.
    // Not needed when targeting MacOS.
    //
    // i.e. crt_dir=/Users/username/Library/Android/sdk/ndk/27.3.13750724/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/21
    const crt_dir = try ndk.realpathAlloc(gpa, "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/21");
    defer gpa.free(crt_dir);
    try out.print("crt_dir={s}\n", .{crt_dir});

    // These do not need to be set
    try out.writeAll("msvc_lib_dir=\n");
    try out.writeAll("kernel32_lib_dir=\n");
    try out.writeAll("gcc_dir=\n");

    var loc = try std.fs.cwd().openDir(b.build_root.path.?, .{});
    var file = try loc.createFile("android_libc.txt", .{ .truncate = true });
    defer file.close();
    try file.writeAll(libc_txt.items);
}
