//! Present the menu that has shortcut to common words used
//! for parsing, and any special user created parsing sets.
//!
//! `init` builds up the entire screen, without any word sets
//! that may exist. `update_sets` is then used to add/update
//! the list ofavailable word sets.

var panel: *Element = undefined;
var scroller: *Element = undefined;
var info2: *Element = undefined;
var new_button: *Element = undefined;
var bottom_spacer: *Element = undefined;

const ICON_PAD = 30;

pub fn show(display: *Display, _: *Element) error{OutOfMemory}!void {
    display.choose_panel("parsing.menu");
}

pub fn deinit() void {
    //
}

pub fn init(context: *AppContext) error{ OutOfMemory, UnknownImageFormat, ResourceNotFound, ResourceReadError }!void {
    var display = context.display;

    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "parsing.menu",
            .visible = .hidden,
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .type = .{ .panel = .{
                .direction = .top_to_bottom,
                .spacing = 5,
            } },
        },
    ));

    const title = try engine.create_label(
        display,
        "",
        .{
            .name = "parsing.heading",
            .minimum = .{ .width = 500, .height = 10 },
            .child_align = .{ .x = .centre },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .label = .{
                .text = "Parsing Quiz",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    );
    title.pad.top = 30;
    title.pad.bottom = 30;
    try panel.add_element(title);

    scroller = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 400, .height = 600 },
            .type = .{
                .panel = .{
                    .scrollable = .{
                        .scroll = .{ .x = false, .y = true },
                        .size = .{ .width = 600, .height = 600 },
                    },
                    .direction = .top_to_bottom,
                    .spacing = 10,
                },
            },
            .on_resized = vertical_scroller_resize,
        },
    );
    try panel.add_element(scroller);

    try scroller.add_element(try engine.create_expander(
        display,
        .{
            .name = "top.expander",
            .rect = .{ .width = 100, .height = 20 },
            .minimum = .{ .width = 100, .height = 0 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 1 } },
        },
    ));

    try scroller.add_element(try engine.create_label(
        display,
        "",
        .{
            .name = "parsing instructions",
            .layout = .{ .x = .grows, .y = .shrinks },
            .minimum = .{ .width = 500, .height = 10 },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Practice parsing one of the following words.",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    ));

    try make_button_bar(display, scroller, "verb.buttons", &[_][]const u8{ "λύω", "βλέπω", "περιπατέω" });
    try make_button_bar(display, scroller, "contract.buttons", &[_][]const u8{ "ἀγαπάω", "ποιέω", "πληρόω" });
    try make_button_bar(display, scroller, "other.buttons", &[_][]const u8{ "ῥύομαι", "δίδωμι", "ἐγώ", "εἰμί" });

    _ = try display.add_spacer(scroller, 20);

    try make_button_bar(display, scroller, "masculine.buttons", &[_][]const u8{ "ἄνθρωπος", "λόγος", "θεός" });
    try make_button_bar(display, scroller, "feminine.buttons", &[_][]const u8{ "γραφή", "ἠμέρα", "δόξα" });
    try make_button_bar(display, scroller, "neuter.buttons", &[_][]const u8{ "βιβλίον", "ἔργον", "τέκνον" });

    _ = try display.add_spacer(scroller, 20);

    try make_button_bar(display, scroller, "parsing.other", &[_][]const u8{ "βασιλεύς", "πόλις", "σάρξ", "πᾶς" });

    try scroller.add_element(try engine.create_expander(
        display,
        .{
            .name = "bottom.expander",
            .rect = .{ .width = 100, .height = 20 },
            .minimum = .{ .width = 100, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 1.2 } },
        },
    ));

    try scroller.add_element(try engine.create_expander(
        display,
        .{
            .name = "bottom.pad",
            .rect = .{ .width = 70, .height = 120 },
            .minimum = .{ .width = 70, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 0 } },
        },
    ));

    info2 = try engine.create_label(
        display,
        "",
        .{
            .name = "list.instructions",
            .layout = .{ .x = .grows, .y = .shrinks },
            .minimum = .{ .width = 500, .height = 10 },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Parsing Sets",
                .text_size = .normal,
                .text_colour = .tinted,
            } },
        },
    );
    info2.pad.top = 0;
    try scroller.add_element(info2);

    const list_menu = try scroller.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "list_menu",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 30, .right = 30, .top = 8, .bottom = 8 },
            .minimum = .{ .width = 200, .height = 20 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 22,
            } },
        },
    ));
    new_button = try list_menu.add(try engine.create_button(
        display,
        "new list button",
        "new list button",
        "new list button",
        .{
            .name = "new.word.list",
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .button = .{
                .text = "New Word Set",
                .on_click = show_new_word_list,
                .spacing = 15,
                .icon_size = .{ .x = 40, .y = 40 },
            } },
        },
        "white rounded rect2",
        "white rounded rect2",
        "white rounded rect2",
    ));

    bottom_spacer = try context.display.add_spacer(panel, 80);
    bottom_spacer.on_resized = MenuUI.update_bottom_spacing;
}

pub fn update_sets() error{ OutOfMemory, UnknownImageFormat, ResourceNotFound, ResourceReadError }!void {
    const display = ac.app_context.?.display;

    // Remove existing list items
    var list_pos: usize = 0;
    for (scroller.type.panel.children.items, 0..) |child, i| {
        if (std.mem.eql(u8, child.name, "list.instructions")) {
            list_pos = i + 1;
            break;
        }
    }

    while (true) {
        if (list_pos >= scroller.type.panel.children.items.len) {
            break;
        }
        const item = scroller.type.panel.children.items[list_pos];
        if (!std.mem.eql(u8, item.name, "list.item")) {
            break;
        }
        const found = scroller.remove_element_at(list_pos);
        found.destroy(display, display.allocator);
    }

    for (ac.app_context.?.lists.sets.items) |list| {
        // Add refreshed list items
        const item = try engine.create_label(
            display,
            "",
            .{
                .name = "list.item",
                .layout = .{ .x = .grows, .y = .shrinks },
                .minimum = .{ .width = 500, .height = 10 },
                .child_align = .{ .x = .centre },
                .type = .{ .label = .{
                    .text = list.name.items,
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_click = list_tapped,
                } },
            },
        );
        try scroller.insert_element(list_pos, item);
    }
    display.relayout();
}

fn make_button_bar(
    display: *Display,
    parent: *Element,
    row_name: []const u8,
    words: []const []const u8,
) !void {
    var button_bar = try engine.create_panel(
        display,
        "",
        .{
            .name = row_name,
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
    try parent.add_element(button_bar);

    for (words) |word| {
        const button = try engine.create_button(
            display,
            "", // No image on this button
            "", // No image on this button
            "", // No image on this button
            .{
                .name = word,
                .minimum = .{ .width = 10, .height = 15 },
                .pad = .{ .left = 30, .right = 30, .top = 25, .bottom = 25 },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{ .button = .{
                    .text = word,
                    .on_click = show_parsing_setup,
                } },
            },
            "white rounded rect2",
            "white rounded rect2",
            "white rounded rect2",
        );
        try button_bar.add_element(button);
    }
}

pub inline fn best_width(display: *Display) f32 {
    if (display.root.rect.width > 1020) {
        return 1000;
    } else if (display.root.rect.width < 600) {
        return 600;
    } else {
        return display.root.rect.width - 20;
    }
}

pub fn list_tapped(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (ac.app_context.?.lists.lookup(element.type.label.text)) |list| {
        try ParsingSetupScreen.study_by_list(display, list, ac.Screen.parsing_menu);
        info("Picked list to study {s}", .{list.name.items});
        return;
    }
    err("Unknown list picked {s}", .{element.name});
}

pub fn show_parsing_setup(display: *Display, element: *Element) error{OutOfMemory}!void {
    var found: ?*praxis.Lexeme = null;

    if (ac.app_context.?.dictionary.by_form.lookup(element.type.button.text)) |result| {
        if (result.exact_accented.items.len > 0) {
            if (result.exact_accented.items[0].lexeme) |lexeme| {
                found = lexeme;
            }
        }
        if (found == null and result.exact_unaccented.items.len > 0) {
            if (result.exact_unaccented.items[0].lexeme) |lexeme| {
                found = lexeme;
            }
        }
    }
    if (found) |lexeme| {
        try ParsingSetupScreen.study_by_form(display, lexeme, ac.Screen.parsing_menu);
        return;
    }

    warn("practice word parsing for {s} not in dictionary.", .{element.type.button.text});
}

pub fn show_new_word_list(display: *Display, _: *Element) error{OutOfMemory}!void {
    try ListNewScreen.show(display);
}

pub fn _handle_resize(display: *Display, _: *Element) bool {
    var updated = false;
    const new_width = best_width(display);
    if (panel.rect.width != new_width) {
        panel.rect.width = new_width;
        panel.minimum.width = new_width;
        panel.maximum.width = new_width;
        updated = true;
    }

    if (scroller.rect.height != display.root.rect.height - 340) {
        scroller.rect.height = display.root.rect.height - 340;
        scroller.minimum.height = scroller.rect.height;
        scroller.maximum.height = scroller.rect.height;
        updated = true;
    }

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
const Allocator = std.mem.Allocator;
const ac = @import("app_context.zig");
const ParsingSetupScreen = @import("screen_parsing_setup.zig");
const ListNewScreen = @import("screen_list_new.zig");
const MenuUI = @import("menu_ui.zig");
const AppContext = ac.AppContext;
const engine = @import("engine");
const err = engine.err;
const warn = engine.warn;
const info = engine.info;
const Lists = @import("lists.zig");
const Display = engine.Display;
const Element = engine.Element;
const praxis = @import("praxis");
const Lang = praxis.Lang;
const vertical_scroller_resize = @import("screen_search.zig").vertical_scroller_resize;
