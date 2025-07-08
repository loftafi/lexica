//! Display required information about the SDL3 library.

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
    display.choose_panel("sdl.license");
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
            .name = "sdl.license",
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
            .name = "licenses_heading",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "SDL 3.0",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    ));
    heading.pad.top = 30;
    heading.pad.bottom = 5;

    _ = try display.add_spacer(panel, 60);

    scroller = try panel.add(try engine.create_panel(
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
    ));

    try display.add_paragraph(scroller, .normal, "p1", "SDL 3 is used under the zlib license:");
    try display.add_paragraph(scroller, .normal, "p2", "This software is provided 'as-is', without any express or implied warranty.  In no event will the authors be held liable for any damages arising from the use of this software.");
    try display.add_paragraph(scroller, .normal, "p3", "Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:");
    try display.add_paragraph(scroller, .normal, "p4", "1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.");
    try display.add_paragraph(scroller, .normal, "p5", "2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.");
    try display.add_paragraph(scroller, .normal, "p6", "3. This notice may not be removed or altered from any source distribution.");
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
const Lang = praxis.Lang;
const Display = engine.Display;
const Element = engine.Element;
const ac = @import("app_context.zig");
const APP_NAME = ac.APP_NAME;
const APP_OWNER = "the author";
const AppContext = ac.AppContext;
const Theme = ac.Theme;
const vertical_scroller_resize = @import("screen_search.zig").vertical_scroller_resize;
