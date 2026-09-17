//! This file provides two possible entry points. It provides a `main` function
//! for launching this app as a standard app. It also provides `SDL_AppInit`
//! as an entry point for Android applications.

/// On startup, register the startp and shutdown handler functions.
pub fn main(init: std.process.Init) !void {
    try engine.start.start(&startup, &shutdown, init.minimal.args);
}

var app: ?*App = null;

/// Creates an engine `Display` object, and loads it with all required
/// resources and screen layouts.
pub fn startup(
    gpa: Allocator,
    arena: Allocator,
    io: std.Io,
    args: []const [*:0]const u8, //args: std.process.Args,
) error{ OutOfMemory, AppInitFailed }!*engine.Display {
    info("Startup function started.", .{});

    // Display configuration defaults to iPhone 16 dimensions for testing.
    // iPhone 16 uses 393x852 logical pixels (1179x2556 physical pixels)
    // minus 59 logical pixels for the top safe area.

    // Read app configuration from `app_info` options provided by the
    // `build.zig` file.
    var config: engine.Config = .{
        .app_name = app_info.app_full_name,
        .app_version = app_info.app_version,
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
    defer bundle_info.deinit(arena);

    var cmd_args = args;
    if (args.len > 1 and std.ascii.eqlIgnoreCase(std.mem.span(args[1]), "make_bundle")) {
        config.command = .make_bundle;
        config.app_bundle_output = try arena.dupe(u8, std.mem.span(args[2]));
        cmd_args = args[2..];
    }

    for (cmd_args, 0..) |arg, i| {
        const value = std.mem.span(arg);
        if (i == 0) continue;
        if (std.ascii.endsWithIgnoreCase(value, ".bd")) {
            // A parameter with a `.bd` extension is an app bundle to load.
            try bundle_info.append(arena, .{
                .filename = try arena.dupe(u8, value),
            });
            continue;
        }
        if (value.len > 0) {
            // A parameter without a `.bd` extension is a resource folder.
            try bundle_info.append(arena, .{
                .folder = try arena.dupe(u8, value),
            });
        }
    }

    if (bundle_info.items.len > 0)
        config.bundles = bundle_info.items;

    app = App.create(gpa, io, &config) catch |f| {
        err("App.create() failed: {t}", .{f});
        return error.AppInitFailed;
    };
    errdefer app.?.destroy();

    info("Startup function complete.", .{});

    return app.?.display;
}

/// After the display (window) is closed, this is an opportunity
/// to release memory and file handles.
pub fn shutdown(
    _: Allocator,
    _: Allocator,
    _: std.Io,
) void {
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

pub export const SDL_AppQuit = engine.AppQuitC;
pub export const SDL_AppEvent = engine.AppEventC;
pub export const SDL_AppIterate = engine.AppIterateC;

pub export fn SDL_AppInit(
    appstate: [*c]?*anyopaque,
    argc: c_int,
    argv: [*c][*c]u8, // [*:null]?[*:0]u8
) callconv(.c) engine.sdl.SDL_AppResult {
    engine.start.startup_handler = startup;
    engine.start.shutdown_handler = shutdown;
    return engine.AppInitC(appstate, argc, argv);
}
