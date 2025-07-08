//! This file describes which tests we want to always run.
//! For now it is everything that hangs off the engine.

const std = @import("std");
const main = @import("main.zig");

pub const std_options = struct {
    pub const log_level: std.log.Level = .debug;
};

test {
    const app = @import("app_context.zig");
    std.testing.refAllDecls(app);

    // Uncomment to force test everything
    // std.testing.refAllDecls(@This());
}
