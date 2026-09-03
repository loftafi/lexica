/// On startup, register the startp and shutdown handler functions.
pub fn main(init: std.process.Init) !void {
    engine.start(&init, &startup, &shutdown);
}

var app: ?*App = null;

/// Creates an engine `Display` object, and loads it with all required
/// resources and screen layouts.
pub fn startup(init: *const std.process.Init) error{ OutOfMemory, AppInitFailed }!*engine.Display {

    // Display configuration defaults to iPhone 16 dimensions for testing.
    // iPhone 16 uses 393x852 logical pixels (1179x2556 physical pixels)
    // minus 59 logical pixels for the top safe area.

    // Read app configuration from `app_info` options provided by the
    // `build.zig` file.
    var config: engine.Config = .{
        .app_name = app_info.app_full_name,
        .app_version = app_info.app_version,
        .app_id = app_info.app_id,
        .app_build = app_info.app_build,
        .app_org = app_info.org,
        .app_bundle_output = app_info.app_bundle,
        .full_screen = true,
        .bundles = &.{
            // By default, resources are loaded from a bundle file named
            // in the `build.zig` file.
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

    // Command line options may override the location to load app resources
    // and `make_bundle` requests that an app bundle is created.
    var bundle_info: std.ArrayListUnmanaged(engine.BundleInfo) = .empty;
    defer bundle_info.deinit(init.arena.allocator());

    var ai = init.minimal.args.iterate();
    if (ai.skip()) {
        while (ai.next()) |value| {
            if (std.ascii.eqlIgnoreCase(value, "make_bundle")) {
                // Request that the app is initialised, and any required
                // resource (image, audio, font, etc...) is placed into
                // a bundle file. The app must then exit.
                config.command = .make_bundle;
                continue;
            }
            if (std.ascii.endsWithIgnoreCase(value, ".bd")) {
                // A parameter with a `.bd` extension is an app bundle to load.
                try bundle_info.append(init.arena.allocator(), .{
                    .filename = try init.arena.allocator().dupe(u8, value),
                });
                continue;
            }
            if (value.len > 0) {
                // A parameter without a `.bd` extension is a resource folder.
                try bundle_info.append(init.arena.allocator(), .{
                    .folder = try init.arena.allocator().dupe(u8, value),
                });
            }
        }
    }
    if (bundle_info.items.len > 0)
        config.bundles = bundle_info.items;

    app = App.create(init.gpa, init.io, &config) catch |f| {
        err("App.create() failed: {t}", .{f});
        return error.AppInitFailed;
    };
    errdefer app.?.destroy();

    return app.?.display;
}

/// After the display (window) is closed, this is an opportunity
/// to release memory and file handles.
pub fn shutdown(_: *const std.process.Init) void {
    if (app) |a| {
        a.destroy();
    }
}

/// Redirect all log messages to the engine log handler.
pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = engine.log.log_capture,
};

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const err = engine.log.err;
const info = engine.log.info;

const App = @import("App.zig");
const app_info = @import("app_info");
