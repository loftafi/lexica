//! This panel allows creating a word set.
pub const ListNewScreen = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,

var new_button: *Entity = undefined;
var text_input: *Entity = undefined;

const ICON_PAD = 30;

pub fn show(
    self: *ListNewScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    try text_input.setText(display, "");
    try display.choosePanel(self.panel.name, event);
}

pub fn init(
    self: *ListNewScreen,
    app: *AppContext,
) (error{ OutOfMemory, ResourceNotFound, ResourceReadError, UnknownImageFormat } || engine.Error || ResourcesError)!void {
    self.app = app;

    var display = app.display;

    self.panel = try display.addPanel(.{
        .name = "new.list.screen",
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

    _ = try self.panel.add(.{
        .name = "new.list.heading",
        .minimum = .{ .width = 580 },
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "New Word Set",
            .text_size = .heading,
        } },
        .pad = .{ .top = 30 },
    }, display);

    text_input = try self.panel.add(.{
        .name = "new_list_name",
        .background = .{ .image_name = "white rounded rect" },
        .rect = .{ .width = 500, .height = 20 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .minimum = .{ .height = 20, .width = 580 },
        .type = .{
            .text_input = .{
                .max_length = Lists.MAX_SET_NAME,
                .on_submit = .{ .func = @ptrCast(&addList), .ptr = self },
                .placeholder_text = "Textbook Chapter 3",
            },
        },
    }, display);

    var button_bar = try self.panel.add(.{
        .name = "new_list_row",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = 30, .right = 30, .top = 8, .bottom = 8 },
        .minimum = .{ .width = 200, .height = 20 },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 22 } },
    }, display);

    new_button = try button_bar.add(.{
        .name = "create.word.list",
        .minimum = .{ .width = 10, .height = 15 },
        .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .button = .{
            .text = "New Word Set",
            .icon = .{
                .default_name = "edit list button",
                .pressed_name = "edit list button",
                .hover_name = "edit list button",
            },
            .button = .{
                .default_name = "white rounded rect2",
                .hover_name = "white rounded rect2",
                .pressed_name = "white rounded rect2",
            },
            .on_pressed = .{ .func = @ptrCast(&addList), .ptr = self },
            .spacing = 20,
        } },
    }, display);
}

pub fn deinit(self: *ListNewScreen) void {
    self.* = undefined;
}

fn tapBack(
    self: *ListNewScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    try self.app.parsing_menu.show(display, element, event);
}

fn addList(
    self: *ListNewScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    if (text_input.type.text_input.text.items.len == 0) {
        info("No list name entered.", .{});
        return;
    }
    info("Creating list named {s}.", .{text_input.type.text_input.text.items});
    const a = try Lists.WordSet.create(display.allocator);
    try a.name.appendSlice(display.allocator, text_input.type.text_input.text.items);
    try self.app.lists.sets.append(display.allocator, a);
    self.app.parsing_menu.update_sets() catch |e| {
        if (e == error.OutOfMemory) return error.OutOfMemory;
        err("update_lists failed: {any}", .{e});
    };
    self.app.list_edit.list = a;
    try self.app.list_edit.show(display, element, event);
    try text_input.setText(display, "");
}

pub fn resizeList(
    _: *ListNewScreen,
    _: *Display,
    _: *Entity,
) bool {
    var updated = false;

    const size = engine.TextSize.normal.size();
    const height = size + (ICON_PAD * 2);
    if (new_button.minimum.height != height) {
        new_button.minimum.height = height;
        new_button.type.button.icon.size.width = size;
        new_button.type.button.icon.size.height = size;
        new_button.minimum.width = height;
        new_button.rect.height = height;
        new_button.minimum.height = height;
        updated = true;
    }

    return updated;
}

const std = @import("std");

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const info = engine.log.info;
const err = engine.log.err;

const Resources = @import("resources").Resources;
const ResourcesError = Resources.Error;

const ac = @import("App.zig");
const AppContext = ac.AppContext;

const Lists = @import("lists.zig");
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const ListEditScreen = @import("screen_list_edit.zig");
