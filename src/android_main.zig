//! The andriod library doesn't use the SDL_main api, instead it uses the
//! callback API's
//!
//! Each of these functions are called using the Android JNI interface.

pub export fn my_startup(_: c_int, _: [*:null]const ?[*:0]const u8) c_uint {
    info("Starting on android.", .{});
    const custom = sdl.SDL_WINDOW_FULLSCREEN | sdl.SDL_WINDOW_BORDERLESS | sdl.SDL_WINDOW_RESIZABLE;
    const android_allocator = std.heap.smp_allocator;

    // Create completes all setup needed to get to a blank startup screen.
    // Setup continues in a background thread so that initial startup
    // screen drawing may occur.
    app.app_context = app.AppContext.create(android_allocator, "", custom) catch |e| {
        err("Start android failed. Error: {any}", .{e});
        return sdl.SDL_APP_FAILURE;
    };
    app.app_context.?.display.initial_draw() catch |e| {
        err("Android initial draw failed. Error: {any}", .{e});
        return sdl.SDL_APP_FAILURE;
    };
    app.app_context.?.setup_screens() catch |e| {
        err("Start screens failed. Error: {any}", .{e});
        return sdl.SDL_APP_FAILURE;
    };
    return sdl.SDL_APP_CONTINUE;
}

/// Any data changes are saved as each change occurs. No special
/// operations are needed on shutdown.
pub export fn my_quit(_: c_uint) void {
    info("Exiting android.", .{});
    if (app.app_context) |*c| {
        c.*.destroy();
    }
}

/// Bridge the SDL event que into the engine event handler
pub export fn my_event(event: *sdl.SDL_Event) c_uint {
    app.app_context.?.display.handle_event(event) catch |e| {
        err("Exiting android. Error: {any}", .{e});
        return sdl.SDL_APP_FAILURE;
    };
    if (app.app_context.?.display.quit) {
        return sdl.SDL_APP_SUCCESS;
    } else {
        return sdl.SDL_APP_CONTINUE;
    }
}

pub export fn my_iterate() c_uint {
    if (app.app_context) |*context| {
        context.*.display.iterate() catch |e| {
            err("Iterate android failed. Error: {any}", .{e});
            return sdl.SDL_APP_FAILURE;
        };
        if (context.*.display.quit) {
            return sdl.SDL_APP_SUCCESS;
        } else {
            return sdl.SDL_APP_CONTINUE;
        }
    }
    return sdl.SDL_APP_FAILURE;
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = engine.log_output_handler,
};

const builtin = @import("builtin");
const app = @import("app_context.zig");
const std = @import("std");
const engine = @import("engine");
const err = engine.err;
const info = engine.info;
const sdl = @import("dep_sdl_module");
