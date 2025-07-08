//! Display the privacy policy for this version of the app.

var panel: *Element = undefined;
pub var back_button: *Element = undefined;
pub var scroller: *Element = undefined;

pub fn deinit() void {
    const display = ac.app_context.?.display;
    _ = display.root.remove_element(display, panel);
    panel.destroy(display, display.allocator);
    panel = undefined;
}

pub fn show(display: *Display, _: *Element) std.mem.Allocator.Error!void {
    init(ac.app_context.?) catch {
        return;
    };
    display.choose_panel("privacy.screen");
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .hidden;
    }
    _ = vertical_scroller_resize(display, scroller);
    display.relayout();
}

pub fn init(context: *AppContext) !void {
    var display = context.display;
    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "privacy.screen",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .visible = .hidden,
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        },
    ));

    back_button = try display.add_back_button(panel, close_me);

    var heading = try panel.add(try engine.create_label(
        display,
        "",
        .{
            .name = "privacy_heading",
            .layout = .{ .y = .shrinks, .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Privacy",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    ));
    heading.pad.top = 30;

    _ = try display.add_spacer(panel, 60);

    scroller = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .width = 600, .height = 600 },
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

    try display.add_paragraph(scroller, .normal, "p1", "By using this app, you consent to this privacy policy and the terms of service.");
    try display.add_paragraph(scroller, .normal, "p2", "This app does not collect any personal identifying information or usage information.");
    try display.add_paragraph(scroller, .normal, "p3", "This app does not share any personal or usage information off your device.");
    try display.add_paragraph(scroller, .normal, "p4", "If new features are added that collect feedback or other types of information, it will be optional, and only be done after requesting your consent.");
    try display.add_paragraph(scroller, .normal, "p5", "Basic information about downloads or purchases through app stores are recorded by the app store provider and is used for accounting purposes.");
    try display.add_paragraph(scroller, .normal, "p6", "Questions about this privacy policy may be directed to the official social media accounts for this app.");
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
const vertical_scroller_resize = @import("screen_search.zig").vertical_scroller_resize;
