/// Main app function for desktop versions of the app.
pub fn main() !void {
    if (builtin.mode == .Debug) {
        var dba = std.heap.DebugAllocator(.{}){};
        defer _ = dba.deinit();
        var dev_resource_repo: []const u8 = "";

        // argsWithAllocator apparently needed for windows support.
        var args = try std.process.argsWithAllocator(dba.allocator());
        defer args.deinit();
        if (args.skip()) {
            if (args.next()) |arg| {
                if (arg.len > 0) {
                    dev_resource_repo = arg;
                }
            }
        }

        startup(dev_resource_repo, dba.allocator(), 0) catch |e| {
            debug("app.startup failed: {any}", .{e});
        };

        _ = dba.detectLeaks();
    } else {
        startup("", std.heap.smp_allocator, 0) catch |e| {
            debug("app.startup failed: {any}", .{e});
        };
    }
}

pub fn startup(dev_resource_repo: []const u8, allocator: Allocator, gui_flags: usize) !void {
    app.app_context = try app.AppContext.create(allocator, dev_resource_repo, gui_flags);
    defer app.app_context.?.destroy();
    try app.app_context.?.display.initial_draw();
    try app.app_context.?.setup_screens();
    try app.app_context.?.display.main();
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = engine.log_output_handler,
};

const builtin = @import("builtin");
const engine = @import("engine");
const debug = engine.debug;
const app = @import("app_context.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
