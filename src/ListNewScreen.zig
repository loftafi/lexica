//! This panel allows creating a word set.
pub const ListNewScreen = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,
new_button: *Entity = undefined,
text_input: *Entity = undefined,

const ICON_PAD = 15;

pub fn show(
    self: *ListNewScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try self.text_input.setText(display, "");
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
        .minimum = .{ .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
            .spacing = 17,
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
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "New Word Set",
            .text_size = .heading,
        } },
        .pad = .{ .top = 15 },
    }, display);

    self.text_input = try self.panel.add(.{
        .name = "new_list_name",
        .background = .{
            .image_name = "white rounded rect",
            .image_corner_radius = 50,
            .corner_radius = 14,
        },
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .rect = .{ .width = 250, .height = 10 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .minimum = .{ .height = 20, .width = 290 },
        .type = .{
            .text_input = .{
                .max_length = Lists.MAX_SET_NAME,
                .on_submit = .{ .func = @ptrCast(&tapAddList), .ptr = self },
                .placeholder_text = "Textbook Chapter 3",
            },
        },
    }, display);

    var button_bar = try self.panel.add(.{
        .name = "new_list_row",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = 15, .right = 15, .top = 4, .bottom = 4 },
        .minimum = .{ .width = 100, .height = 10 },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 11 } },
    }, display);

    self.new_button = try button_bar.add(.{
        .name = "create.word.list",
        .background = .{ .image_corner_radius = 50, .corner_radius = 14 },
        .minimum = .{ .width = 5, .height = 7 },
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
                .default_name = "default button",
                .hover_name = "hover button",
                .pressed_name = "pressed button",
            },
            .on_pressed = .{ .func = @ptrCast(&tapAddList), .ptr = self },
            .spacing = 10,
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
    event: *const Event,
) error{OutOfMemory}!void {
    try self.app.parsing_menu.show(display, element, event);
}

fn tapAddList(
    self: *ListNewScreen,
    display: *Display,
    element: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (self.text_input.type.text_input.text.items.len == 0) {
        info("No list name entered.", .{});
        return;
    }
    info("Creating list named {s}.", .{self.text_input.type.text_input.text.items});
    const a = try Lists.WordSet.create(display.allocator);
    try a.name.appendSlice(display.allocator, self.text_input.type.text_input.text.items);
    try self.app.lists.sets.append(display.allocator, a);
    self.app.list_edit.list = a;
    try self.app.list_edit.show(display, element, event);
    try self.text_input.setText(display, "");
}

pub fn resizeList(
    self: *ListNewScreen,
    _: *Display,
    _: *Entity,
) bool {
    var updated = false;

    const size = engine.TextSize.normal.size();
    const height = size + (ICON_PAD * 2);
    if (self.new_button.minimum.height != height) {
        self.new_button.minimum.height = height;
        self.new_button.type.button.icon.size.width = size;
        self.new_button.type.button.icon.size.height = size;
        self.new_button.minimum.width = height;
        self.new_button.rect.height = height;
        self.new_button.minimum.height = height;
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

const Lists = @import("Lists.zig");
const ParsingMenuScreen = @import("ParsingMenuScreen.zig");
const ListEditScreen = @import("ListEditScreen.zig");
