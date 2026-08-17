var allocator: Allocator = undefined;
var io: std.Io = undefined;

/// Main app function for desktop versions of the app.
pub fn main(init: std.process.Init) !void {
    engine.start(&init, &startup, &shutdown);
}

var app: ?*App = null;

pub fn startup(init: *const std.process.Init) error{ OutOfMemory, AppInitFailed }!*engine.Display {
    allocator = init.gpa;
    io = init.io;

    // iPhone 16 - 393x852 (1179x2556) also minus 59 top safe area

    var config: engine.Config = .{
        .app_name = app_info.app_full_name,
        .app_version = app_info.app_version,
        .app_id = app_info.app_id,
        .app_build = app_info.app_build,
        .app_org = app_info.org,
        .app_bundle_output = app_info.app_bundle,
        .full_screen = true,
        .bundles = &.{
            //.{ .folder = app_info.app_resources },
            .{ .filename = app_info.app_bundle },
        },
        .width = 393,
        .height = 852 - 59,
        .min_width = 393,
        .min_height = 700,
        .command = .default,
        .translation_filename = "lexica translation",
        .desktop_icon = if (builtin.os.tag == .macos) "desktop icon" else null,
    };

    if (builtin.os.tag == .macos) {
        config.full_screen = false;
    }

    // If command line arguments exist, use them for the bundle_info.
    var bundle_info: std.ArrayListUnmanaged(engine.BundleInfo) = .empty;
    defer bundle_info.deinit(init.arena.allocator());

    var ai = init.minimal.args.iterate();
    if (ai.skip()) {
        while (ai.next()) |value| {
            if (std.ascii.eqlIgnoreCase(value, "make_bundle")) {
                config.command = .make_bundle;
                continue;
            }
            if (std.ascii.endsWithIgnoreCase(value, ".bd")) {
                try bundle_info.append(init.arena.allocator(), .{
                    .filename = try init.arena.allocator().dupe(u8, value),
                });
                continue;
            }
            if (value.len > 0) {
                try bundle_info.append(init.arena.allocator(), .{
                    .folder = try init.arena.allocator().dupe(u8, value),
                });
            }
        }
    }
    if (bundle_info.items.len > 0)
        config.bundles = bundle_info.items;

    app = App.create(allocator, io, &config) catch |f| {
        err("App.create() failed: {t}", .{f});
        return error.AppInitFailed;
    };
    errdefer app.?.destroy();

    // Do initial draw and initialise startup screens
    //app.?.startup() catch |e| {
    //    err("startup failed. Error: {t}", .{e});
    //    return error.AppInitFailed;
    //};

    return app.?.display;
}

pub fn shutdown(_: *const std.process.Init) void {
    if (app) |a| {
        a.destroy();
    }
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = engine.log.log_capture,
    //.allow_stack_tracing = if (engine.platform == .ios) false else true,
};

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const err = engine.log.err;
const info = engine.log.info;
const debug = engine.log.debug;

const App = @import("App.zig").AppContext;

const dialogos = @import("dialogos");
const app_info = @import("app_info");
