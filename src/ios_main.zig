//! Entry point for iOS build of the dictionary app. This is used
//! to request SDL settings specific to iOS.

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = engine.log_output_handler,
};

pub export fn SDL_main(argc: c_int, argv: [*:null]const ?[*:0]const u8) c_int {
    _ = argc;
    _ = argv;

    std.debug.print("Starting ios.", .{});
    const custom = sdl.SDL_WINDOW_FULLSCREEN | sdl.SDL_WINDOW_BORDERLESS | sdl.SDL_WINDOW_RESIZABLE;
    @import("main.zig").startup("", std.heap.smp_allocator, custom) catch |e| {
        debug("Error: {any}", .{e});
    };
    debug("Exiting.", .{});

    return 0;
}

const std = @import("std");
const sdl = @import("dep_sdl_module");
const engine = @import("engine");
const debug = engine.debug;
