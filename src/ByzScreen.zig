pub const ByzScreen = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,

pub var back_button: *Entity = undefined;
pub var scroller: *Entity = undefined;

pub fn deinit(self: *ByzScreen) void {
    self.* = undefined;
}

pub fn show(
    self: *ByzScreen,
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

pub fn init(self: *ByzScreen, app: *AppContext) !void {
    self.app = app;
    var display = app.display;

    self.panel = try display.addPanel(.{
        .name = "byz.license",
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
    });

    back_button = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    _ = try self.panel.add(.{
        .name = "byz_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Robinson-Pierpont",
            .text_size = .heading,
        } },
        .pad = .{ .top = 10 },
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

    try display.add_paragraph(scroller, .subheading, "p1", "This Compilation is Copyright ©2005 by Robinson and Pierpont");
    try display.add_paragraph(scroller, .normal, "p2", "Anyone is permitted to copy and distribute this text or any portion of this text. It may be incorporated in a larger work, and/or quoted from, stored in a database retrieval system, photocopied, reprinted, or otherwise duplicated by anyone without prior notification, permission, compensation to the holder, or any other restrictions. All rights to this text are released to everyone and no one can reduce these rights at any time. Copyright is not claimed nor asserted for the new and revised form of the Greek NT text of this edition, nor for the original form of such as initially released into the public domain by the editors, first as printed textual notes in 1979 and in continuous-text electronic form in 1986. Likewise, we hereby release into the public domain the introduction and appendix which have been especially prepared for this edition.");
    try display.add_paragraph(scroller, .normal, "p3", "The permitted use or reproduction of the Greek text or other material contained within this volume (whether by print, electronic media, or other form) does not imply doctrinal or theological agreement by the present editors and publisher with whatever views may be maintained or promulgated by other publishers. For the purpose of assigning responsibility, it is requested that the present editors’ names and the title associated with this text as well as this disclaimer be retained in any subsequent reproduction of this material.");
}

pub fn tapBack(
    _: *ByzScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
    try display.choosePanel("license.screen", event);
}

pub fn vertical_scroller_resize(
    _: *ByzScreen,
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

const engine = @import("engine");
const debug = std.log.debug;
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;

const praxis = @import("praxis");

const ac = @import("App.zig");
const AppContext = ac.AppContext;
const MenuUI = @import("MenuUI.zig");
