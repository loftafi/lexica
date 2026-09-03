//! This panel allows deleting a word set.
pub const ListDeleteScreen = @This();

const ICON_PAD = 15;

app: *AppContext = undefined,
panel: *Entity = undefined,
delete_button: *Entity = undefined,
heading: *Entity = undefined,
list_name_help: *Entity = undefined,

pub fn show(
    self: *ListDeleteScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (self.app.parsing_setup.list) |list| {
        try self.heading.setText(display, list.name.items);
        try display.choosePanel(self.panel.name, event);
    } else {
        err("ListDelete not shown. parsing_setup does not have list", .{});
    }
}

pub fn deinit(self: *ListDeleteScreen) void {
    self.* = undefined;
}

pub fn init(
    self: *ListDeleteScreen,
    app: *AppContext,
) (error{ OutOfMemory, ResourceNotFound, ResourceReadError, UnknownImageFormat } || engine.Error || ResourceErrors)!void {
    self.app = app;
    var display = app.display;

    self.panel = try display.addPanel(.{
        .name = "delete.list.screen",
        .rect = .{ .x = 0, .y = 0 },
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .centre },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
            .spacing = 35,
            .choosable = .choosable,
        } },
        .visible = .hidden,
        .on_resized = .{ .func = @ptrCast(&resizeList), .ptr = self },
    });

    _ = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    self.heading = try self.panel.add(.{
        .name = "delete.list.heading",
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Delete Word Set",
            .text_size = .heading,
        } },
        .pad = .{ .top = 30 },
    }, display);

    self.list_name_help = try self.panel.add(.{
        .name = "list_name",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .minimum = .{ .height = 10 },
        .type = .{
            .label = .{ .text = "Confirm you wish to delete this set." },
        },
    }, display);

    var button_bar = try self.panel.add(.{
        .name = "delete_list_row",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 15, .right = 15, .top = 4, .bottom = 4 },
        .minimum = .{ .width = 100, .height = 10 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 11,
        } },
    }, display);

    self.delete_button = try button_bar.add(.{
        .name = "delete.word.set.button",
        .minimum = .{ .width = 5, .height = 7 },
        .background = .{
            .corner_radius = 22,
            .image_corner_radius = 50,
        },
        .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .button = .{
            .text = "Delete Word Set",
            .on_pressed = .{ .func = @ptrCast(&tapDeleteList), .ptr = self },
            .spacing = 10,
            .icon = .{
                .default_name = "edit list button",
                .pressed_name = "edit list button",
                .hover_name = "edit list button",
            },
            .button = .{
                .default_name = "default button",
                .pressed_name = "pressed button",
                .hover_name = "hover button",
            },
        } },
    }, display);
}

fn tapBack(
    _: *ListDeleteScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    try ac.app_context.?.parsing_menu.show(display, element, event);
}

fn tapDeleteList(
    self: *ListDeleteScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    const list = self.app.parsing_setup.list.?;
    self.app.parsing_setup.list = null;
    ac.app_context.?.parsing_quiz.clear(display.allocator);
    info("Deleting list named {s}.", .{list.name.items});
    ac.app_context.?.lists.remove_list(display, list) catch |e| {
        if (e == error.OutOfMemory) return error.OutOfMemory;
        err("delete list failed: {any}", .{e});
        try self.app.parsing_menu.show(display, element, event);
        return;
    };
    try self.app.parsing_menu.show(display, element, event);
}

pub fn resizeList(
    self: *ListDeleteScreen,
    _: *Display,
    _: *Entity,
) bool {
    var updated = false;

    const size = engine.TextSize.normal.size();
    const height = size + (ICON_PAD * 2);
    if (self.delete_button.minimum.height != height) {
        self.delete_button.minimum.height = height;
        self.delete_button.type.button.icon.size.width = size;
        self.delete_button.type.button.icon.size.height = size;
        self.delete_button.minimum.width = height;
        self.delete_button.rect.height = height;
        self.delete_button.minimum.height = height;
        updated = true;
    }

    return updated;
}

const std = @import("std");
const AppContext = ac.AppContext;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const err = engine.log.err;
const info = engine.log.info;

const ac = @import("App.zig");
const ResourceErrors = @import("resources").Resources.Error;

const Lists = @import("Lists.zig");
