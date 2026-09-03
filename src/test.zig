/// Tests that must always be run. Triggered using `zig build test`
const std = @import("std");
const main = @import("main.zig");

pub const std_options = struct {
    pub const log_level: std.log.Level = .debug;
};

test {
    const app = @import("App.zig");
    std.testing.refAllDecls(app);

    // Uncomment to force test everything
    // std.testing.refAllDecls(@This());
}
