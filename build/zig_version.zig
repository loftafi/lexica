/// Display clean message if building with old zig version.
pub fn requireVersion(comptime version: []const u8) void {
    const required = SemanticVersion.parse(version) catch unreachable;
    const current = builtin.zig_version;

    if (current.major != required.major or
        current.minor != required.minor or
        current.patch < required.patch)
    {
        @compileError(std.fmt.comptimePrint(
            "Zig version {f} is required. Current version is {f}",
            .{ current, required },
        ));
    }
}

const std = @import("std");
const SemanticVersion = std.SemanticVersion;
const builtin = @import("builtin");
