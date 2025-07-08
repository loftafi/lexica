var panel: *Element = undefined;
pub var back_button: *Element = undefined;
pub var scroller: *Element = undefined;

pub fn show(display: *Display, _: *Element) std.mem.Allocator.Error!void {
    init(ac.app_context.?) catch {
        return;
    };
    display.choose_panel("license.screen");
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .hidden;
    }
    _ = vertical_scroller_resize(display, scroller);
    display.relayout();
}

pub fn init(context: *AppContext) !void {
    var display = context.display;
    panel = try engine.create_panel(
        display,
        "",
        .{
            .name = "license.screen",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .visible = .hidden,
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        },
    );

    back_button = try display.add_back_button(panel, close_me);

    var heading = try engine.create_label(
        display,
        "",
        .{
            .name = "licenses_heading",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Resources",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    );
    try panel.add_element(heading);
    heading.pad.top = 30;

    _ = try display.add_spacer(panel, 60);

    scroller = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 600, .height = 500 },
            .type = .{
                .panel = .{
                    .scrollable = .{
                        .scroll = .{ .x = false, .y = true },
                        .size = .{ .width = 600, .height = 600 },
                    },
                    .direction = .top_to_bottom,
                    .spacing = 2,
                },
            },
            .on_resized = vertical_scroller_resize,
        },
    );
    try panel.add_element(scroller);

    try display.add_paragraph(scroller, .normal, "p1", "To support the goal that these resources should be available free of charge and restriction. This app only uses or supports components and resources that are available under a public domain or comparable license (i.e. MIT, CC0, ZLIB).");
    _ = try display.add_spacer(scroller, 60);

    try display.add_paragraph(scroller, .normal, "p2", "Koine Greek glosses are public domain. They are a combination of public domain sources and original work of the author.");
    _ = try display.add_spacer(scroller, 30);

    try display.add_paragraph(scroller, .normal, "p3", "Hand and computer generated parsing data is combined with the public domain Robinson and Pierpoint Byzantine text.");
    try scroller.add_element(try engine.create_label(
        display,
        "",
        .{
            .name = "byz.link",
            .layout = .{ .x = .grows },
            .type = .{ .label = .{
                .text = "Robinson Pierpoint Text",
                .text_size = .small,
                .text_colour = .tinted,
                .on_click = show_byz_screen,
            } },
        },
    ));
    _ = try display.add_spacer(scroller, 30);

    try display.add_paragraph(scroller, .normal, "p4", "NotoSans, and NotoSansTC font used under the SIL Open font license.");
    try scroller.add_element(try engine.create_label(
        display,
        "",
        .{
            .name = "noto.link",
            .layout = .{ .x = .grows },
            .type = .{ .label = .{
                .text = "Noto Sans and Noto Sans TC",
                .text_size = .small,
                .text_colour = .tinted,
                .on_click = show_noto_screen,
            } },
        },
    ));
    _ = try display.add_spacer(scroller, 30);

    try display.add_paragraph(scroller, .normal, "p5", "SDL3 is used under the zlib license.");
    try scroller.add_element(try engine.create_label(
        display,
        "",
        .{
            .name = "sdl.link",
            .layout = .{ .x = .grows },
            .type = .{ .label = .{
                .text = "SDL 3.0 License",
                .text_size = .small,
                .text_colour = .tinted,
                .on_click = show_sdl_screen,
            } },
        },
    ));

    try display.add_element(panel);
}

pub fn deinit() void {
    const display = ac.app_context.?.display;
    _ = display.root.remove_element(display, panel);
    panel.destroy(display, display.allocator);
    panel = undefined;
}

pub fn close_me(display: *Display, _: *Element) Allocator.Error!void {
    deinit();
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .visible;
    }
    display.choose_panel("preferences.screen");
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const praxis = @import("praxis");
const Display = engine.Display;
const Element = engine.Element;
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const best_width = @import("screen_parsing_menu.zig").best_width;
const show_byz_screen = @import("screen_byz.zig").show;
const show_noto_screen = @import("screen_noto.zig").show;
const show_sdl_screen = @import("screen_sdl.zig").show;
const vertical_scroller_resize = @import("screen_search.zig").vertical_scroller_resize;
