//! This panel allows creating a word set.

var panel: *Element = undefined;
var new_button: *Element = undefined;
var text_input: *Element = undefined;

const ICON_PAD = 30;

pub fn show(display: *Display) error{OutOfMemory}!void {
    try text_input.set_text(display, "", false);
    display.choose_panel("new.list.screen");
}

pub fn init(context: *AppContext) error{ OutOfMemory, ResourceNotFound, ResourceReadError, UnknownImageFormat }!void {
    var display = context.display;

    panel = try engine.create_panel(
        display,
        "",
        .{
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
            } },
            .visible = .hidden,
            .on_resized = handle_resize,
        },
    );

    _ = try display.add_back_button(panel, go_back);

    var heading = try panel.add(try engine.create_label(
        display,
        "",
        .{
            .name = "new.list.heading",
            .minimum = .{ .width = 580 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .type = .{ .label = .{
                .text = "New Word Set",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    ));
    heading.pad.top = 30;
    heading.pad.bottom = 0;

    text_input = try panel.add(try engine.create_text_input(
        context.display,
        "",
        "Textbook Chapter 3",
        "",
        "white rounded rect",
        .{
            .name = "new_list_name",
            .rect = .{ .width = 500, .height = 20 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .minimum = .{ .height = 20, .width = 580 },
            .type = .{
                .text_input = .{
                    .max_runes = Lists.MAX_SET_NAME,
                    .on_submit = add_list,
                },
            },
        },
    ));

    var button_bar = try engine.create_panel(
        display,
        "",
        .{
            .name = "new_list_row",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .left = 30, .right = 30, .top = 8, .bottom = 8 },
            .minimum = .{ .width = 200, .height = 20 },
            .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 22 } },
        },
    );
    try panel.add_element(button_bar);

    new_button = try button_bar.add(try engine.create_button(
        display,
        "edit list button",
        "edit list button",
        "edit list button",
        .{
            .name = "create.word.list",
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .button = .{
                .text = "New Word Set",
                .on_click = add_list,
                .spacing = 20,
            } },
        },
        "white rounded rect2",
        "white rounded rect2",
        "white rounded rect2",
    ));

    try display.add_element(panel);
}

pub fn deinit() void {
    //
}

fn go_back(display: *Display, element: *Element) error{OutOfMemory}!void {
    try ParsingMenuScreen.show(display, element);
}

fn add_list(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (text_input.type.text_input.text.items.len == 0) {
        info("No list name entered.", .{});
        return;
    }
    info("Creating list named {s}.", .{text_input.type.text_input.text.items});
    const a = try Lists.WordSet.create(display.allocator);
    try a.name.appendSlice(text_input.type.text_input.text.items);
    try ac.app_context.?.lists.sets.append(a);
    ParsingMenuScreen.update_sets() catch |e| {
        if (e == error.OutOfMemory) return error.OutOfMemory;
        err("update_lists failed: {any}", .{e});
    };
    ListEditScreen.list = a;
    try ListEditScreen.show(display, element);
    try text_input.set_text(display, "", false);
}

pub fn handle_resize(display: *Display, _: *Element) bool {
    var updated = false;

    const size = display.text_height * display.scale * engine.TextSize.normal.height();
    const height = size + (ICON_PAD * 2);
    if (new_button.minimum.height != height) {
        new_button.minimum.height = height;
        new_button.type.button.icon_size.x = size;
        new_button.type.button.icon_size.y = size;
        new_button.minimum.width = height;
        new_button.rect.height = height;
        new_button.minimum.height = height;
        updated = true;
    }

    return updated;
}

const std = @import("std");
const engine = @import("engine");
const Element = engine.Element;
const info = engine.info;
const err = engine.err;
const Display = engine.Display;
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const Lists = @import("lists.zig");
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const ListEditScreen = @import("screen_list_edit.zig");
