pub const std = @import("std");

pub fn addSystemPathsToModule(
    b: *std.Build,
    target: *const std.Build.ResolvedTarget,
    lib: *std.Build.Module,
) void {
    // For TranslateC to work, we need the system library headers
    switch (target.result.os.tag) {
        .macos => {
            const sdk = std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result) orelse
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
            const sdk = std.zig.system.darwin.getSdk(b.allocator, b.graph.io, &target.result) orelse
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
                if (FindNDK.find(b.graph.io, b.graph.environ_map)) |android_ndk| {
                    if (android_ndk) |ndk| {
                        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{
                            ndk,
                            "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include/",
                        }) });
                        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{
                            ndk,
                            "toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include/aarch64-linux-android/",
                        }) });
                    } else {
                        std.log.err("Can't find android ndk. Set ANDROID_NDK_HOME.", .{});
                        @panic("android/linux build requires ndk. Set ANDROID_NDK_HOME");
                    }
                } else |err| {
                    std.log.err("Error searching for android ndk. Set ANDROID_NDK_HOME. {any}", .{err});
                    @panic("Error searching for android ndk. Set ANDROID_NDK_HOME");
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

const FindNDK = @import("FindNDK.zig").FindNDK;
