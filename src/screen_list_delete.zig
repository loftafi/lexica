//! This panel allows deleting a word set.

var panel: *Element = undefined;
var delete_button: *Element = undefined;
var heading: *Element = undefined;
var list_name_help: *Element = undefined;

const ICON_PAD = 30;

pub fn show(display: *Display, _: *Element) error{OutOfMemory}!void {
    const list = ParsingSetupScreen.list.?;
    try heading.set_text(display, "", false);
    try heading.set_text(display, list.name.items, false);
    display.choose_panel("delete.list.screen");
}

pub fn deinit() void {
    //
}

pub fn init(context: *AppContext) error{ OutOfMemory, ResourceNotFound, ResourceReadError, UnknownImageFormat }!void {
    var display = context.display;

    panel = try engine.create_panel(
        display,
        "",
        .{
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
            } },
            .visible = .hidden,
            .on_resized = handle_resize,
        },
    );

    _ = try display.add_back_button(panel, go_back);

    heading = try panel.add(try engine.create_label(
        display,
        "",
        .{
            .name = "delete.list.heading",
            .layout = .{ .y = .shrinks, .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Delete Word Set",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    ));
    heading.pad.top = 30;
    heading.pad.bottom = 0;

    list_name_help = try panel.add(try engine.create_label(
        context.display,
        "",
        .{
            .name = "list_name",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .minimum = .{ .height = 20 },
            .type = .{
                .label = .{ .text = "Confirm you wish to delete this set." },
            },
        },
    ));

    var button_bar = try engine.create_panel(
        display,
        "",
        .{
            .name = "delete_list_row",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 30, .right = 30, .top = 8, .bottom = 8 },
            .minimum = .{ .width = 200, .height = 20 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 22,
            } },
        },
    );
    try panel.add_element(button_bar);

    delete_button = try button_bar.add(try engine.create_button(
        display,
        "edit list button",
        "edit list button",
        "edit list button",
        .{
            .name = "delete.word.set.button",
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .button = .{
                .text = "Delete Word Set",
                .on_click = delete_list,
                .spacing = 20,
            } },
        },
        "white rounded rect2",
        "white rounded rect2",
        "white rounded rect2",
    ));

    try display.add_element(panel);
}

fn go_back(display: *Display, element: *Element) error{OutOfMemory}!void {
    try ParsingMenuScreen.show(display, element);
}

fn delete_list(display: *Display, element: *Element) error{OutOfMemory}!void {
    const list = ParsingSetupScreen.list.?;
    ParsingSetupScreen.list = null;
    ac.app_context.?.parsing_quiz.clear();
    info("Deleting list named {s}.", .{list.name.items});
    ac.app_context.?.lists.remove_list(list) catch |e| {
        if (e == error.OutOfMemory) return error.OutOfMemory;
        err("delete list failed: {any}", .{e});
        try ParsingMenuScreen.show(display, element);
        return;
    };
    ParsingMenuScreen.update_sets() catch |e| {
        if (e == error.OutOfMemory) return error.OutOfMemory;
        err("update_lists failed: {any}", .{e});
    };
    try ParsingMenuScreen.show(display, element);
}

pub fn handle_resize(display: *Display, _: *Element) bool {
    var updated = false;

    const size = display.text_height * display.scale * engine.TextSize.normal.height();
    const height = size + (ICON_PAD * 2);
    if (delete_button.minimum.height != height) {
        delete_button.minimum.height = height;
        delete_button.type.button.icon_size.x = size;
        delete_button.type.button.icon_size.y = size;
        delete_button.minimum.width = height;
        delete_button.rect.height = height;
        delete_button.minimum.height = height;
        updated = true;
    }

    return updated;
}

const std = @import("std");
const engine = @import("engine");
const Element = engine.Element;
const Display = engine.Display;
const err = engine.err;
const info = engine.info;
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const Lists = @import("lists.zig");
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const ParsingSetupScreen = @import("screen_parsing_setup.zig");
const ListEditScreen = @import("screen_list_edit.zig");
