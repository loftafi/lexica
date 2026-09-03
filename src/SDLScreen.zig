//! Display required information about the SDL3 library.
pub const SDLScreen = @This();

app: *App = undefined,
panel: *Entity = undefined,

pub var back_button: *Entity = undefined;
pub var scroller: *Entity = undefined;

pub fn deinit(self: *SDLScreen) void {
    self.* = undefined;
}

pub fn show(
    self: *SDLScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) std.mem.Allocator.Error!void {
    try display.choosePanel(self.panel.name, event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .hidden;
    }
    _ = self.vertical_scroller_resize(display, scroller);
    display.need_relayout = true;
}

pub fn init(self: *SDLScreen, app: *App) !void {
    self.app = app;
    var display = app.display;

    self.panel = try display.root.add(.{
        .name = "sdl.license",
        .rect = .{ .x = 0, .y = 0 },
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .visible = .hidden,
        .type = .{ .panel = .{
            .spacing = 10,
            .direction = .top_to_bottom,
            .choosable = .choosable,
        } },
    }, display);

    back_button = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    _ = try self.panel.add(.{
        .name = "licenses_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "SDL 3.0",
            .text_size = .heading,
        } },
        .pad = .{ .top = 30, .bottom = 5 },
    }, display);

    _ = try display.add_spacer(self.panel, 60);

    scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .minimum = .{ .height = 500 },
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
        .on_resized = .{ .func = @ptrCast(&vertical_scroller_resize), .ptr = self },
    }, display);

    try display.add_paragraph(scroller, .normal, "p1", "SDL 3 is used under the zlib license:");
    try display.add_paragraph(scroller, .normal, "p2", "This software is provided 'as-is', without any express or implied warranty.  In no event will the authors be held liable for any damages arising from the use of this software.");
    try display.add_paragraph(scroller, .normal, "p3", "Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:");
    try display.add_paragraph(scroller, .normal, "p4", "1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.");
    try display.add_paragraph(scroller, .normal, "p5", "2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.");
    try display.add_paragraph(scroller, .normal, "p6", "3. This notice may not be removed or altered from any source distribution.");
}

pub fn tapBack(_: *SDLScreen, display: *Display, _: *Entity, event: *Event) Allocator.Error!void {
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
    try display.choosePanel("license.screen", event);
}

pub fn vertical_scroller_resize(
    _: *SDLScreen,
    display: *Display,
    scroll: *Entity,
) bool {
    var updated = false;
    const menu_area = MenuUI.menubar_height();
    debug("handle resize. menu_height={d} root.height={d} scroller.top={d}, safe.top={d}, safe.bottom={d}", .{
        menu_area,
        display.root.rect.height,
        scroll.rect.y,
        display.safe_area.top,
        display.safe_area.bottom,
    });
    const want_scroller_height = display.root.rect.height - scroll.rect.y - menu_area - display.safe_area.bottom - display.safe_area.top;
    if (scroll.rect.height != want_scroller_height) {
        scroll.rect.height = want_scroller_height;
        scroll.minimum.height = scroll.rect.height;
        scroll.maximum.height = scroll.rect.height;
        updated = true;
    }
    return updated;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const praxis = @import("praxis");
const Lang = praxis.Lang;

const engine = @import("engine");
const debug = engine.log.debug;
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;

const ac = @import("App.zig");
const APP_NAME = ac.APP_NAME;
const APP_OWNER = "the author";
const App = ac.App;
const Theme = ac.Theme;
const MenuUI = @import("MenuUI.zig");
