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
    display.choose_panel("byz.license");
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .hidden;
    }
    _ = vertical_scroller_resize(display, scroller);
    display.need_relayout = true;
}

pub fn init(context: *AppContext) !void {
    var display = context.display;
    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "byz.license",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .visible = .hidden,
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        },
    ));

    back_button = try display.add_back_button(panel, close_me);

    var heading = try panel.add(try engine.create_label(
        display,
        "",
        .{
            .name = "byz_heading",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Robinson-Pierpont",
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

    try display.add_paragraph(scroller, .subheading, "p1", "This Compilation is Copyright ©2005 by Robinson and Pierpont");
    try display.add_paragraph(scroller, .normal, "p2", "Anyone is permitted to copy and distribute this text or any portion of this text. It may be incorporated in a larger work, and/or quoted from, stored in a database retrieval system, photocopied, reprinted, or otherwise duplicated by anyone without prior notification, permission, compensation to the holder, or any other restrictions. All rights to this text are released to everyone and no one can reduce these rights at any time. Copyright is not claimed nor asserted for the new and revised form of the Greek NT text of this edition, nor for the original form of such as initially released into the public domain by the editors, first as printed textual notes in 1979 and in continuous-text electronic form in 1986. Likewise, we hereby release into the public domain the introduction and appendix which have been especially prepared for this edition.");
    try display.add_paragraph(scroller, .normal, "p3", "The permitted use or reproduction of the Greek text or other material contained within this volume (whether by print, electronic media, or other form) does not imply doctrinal or theological agreement by the present editors and publisher with whatever views may be maintained or promulgated by other publishers. For the purpose of assigning responsibility, it is requested that the present editors’ names and the title associated with this text as well as this disclaimer be retained in any subsequent reproduction of this material.");
}

pub fn close_me(display: *Display, _: *Element) Allocator.Error!void {
    deinit();
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .visible;
    }
    display.choose_panel("license.screen");
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
