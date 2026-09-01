//! Present the menu that has shortcut to common words used
//! for parsing, and any special user created parsing sets.
//!
//! `init` builds up the entire screen, without any word sets
//! that may exist. `setupLists` is then used to add/update
//! the list ofavailable word sets.
pub const ParsingMenuScreen = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,
scroller: *Entity = undefined,
info2: *Entity = undefined,
new_list_button: *Entity = undefined,
bottom_spacer: *Entity = undefined,

const ICON_PAD = 15;

pub fn show(
    self: *ParsingMenuScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    self.setupLists() catch |e| {
        if (e == error.OutOfMemory) return error.OutOfMemory;
        err("update_lists failed: {any}", .{e});
    };

    try display.choosePanel(self.panel.name, event);
}

pub fn deinit(self: *ParsingMenuScreen) void {
    self.* = undefined;
}

pub fn init(
    self: *ParsingMenuScreen,
    context: *AppContext,
) (engine.Error || error{ OutOfMemory, UnknownImageFormat, ResourceNotFound, ResourceReadError } || ResourcesError)!void {
    var display = context.display;
    self.app = context;

    self.panel = try display.addPanel(.{
        .name = "parsing.menu",
        .visible = .hidden,
        .rect = .{ .x = 0, .y = 0 },
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
            .spacing = 5,
            .choosable = .choosable,
        } },
    });

    _ = try self.panel.add(.{
        .name = "parsing.heading",
        .minimum = .{ .height = 10 },
        .child_align = .{ .x = .centre },
        .layout = .{ .y = .shrinks, .x = .grows },
        .pad = .{ .top = 10, .bottom = 10 },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Parsing Quiz",
            .text_size = .heading,
        } },
    }, display);

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .rect = .{ .x = 0, .y = 0 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .minimum = .{ .height = 600 },
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
        .on_resized = .{ .func = @ptrCast(&resizeVerticalScroller), .ptr = self },
    }, display);

    _ = try self.scroller.add(.{
        .name = "top.expander",
        .rect = .{ .width = 100, .height = 20 },
        .minimum = .{ .width = 100, .height = 0 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    _ = try self.scroller.add(.{
        .name = "parsing instructions",
        .layout = .{ .x = .grows, .y = .shrinks },
        .minimum = .{ .height = 10 },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Practice parsing one of the following words.",
        } },
    }, display);

    try self.make_button_bar(display, self.scroller, "verb.buttons", &[_][]const u8{ "λύω", "βλέπω", "περιπατέω" });
    try self.make_button_bar(display, self.scroller, "contract.buttons", &[_][]const u8{ "ἀγαπάω", "ποιέω", "πληρόω" });
    try self.make_button_bar(display, self.scroller, "other.buttons", &[_][]const u8{ "ῥύομαι", "δίδωμι", "ἐγώ", "εἰμί" });

    _ = try display.add_spacer(self.scroller, 20);

    try self.make_button_bar(display, self.scroller, "masculine.buttons", &[_][]const u8{ "ἄνθρωπος", "λόγος", "θεός" });
    try self.make_button_bar(display, self.scroller, "feminine.buttons", &[_][]const u8{ "γραφή", "ἠμέρα", "δόξα" });
    try self.make_button_bar(display, self.scroller, "neuter.buttons", &[_][]const u8{ "βιβλίον", "ἔργον", "τέκνον" });

    _ = try display.add_spacer(self.scroller, 20);

    try self.make_button_bar(display, self.scroller, "parsing.other", &[_][]const u8{ "βασιλεύς", "πόλις", "σάρξ", "πᾶς" });

    _ = try self.scroller.add(.{
        .name = "bottom.expander",
        .rect = .{ .width = 100, .height = 20 },
        .minimum = .{ .width = 100, .height = 20 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1.2 } },
    }, display);

    _ = try self.scroller.add(.{
        .name = "bottom.pad",
        .rect = .{ .width = 70, .height = 120 },
        .minimum = .{ .width = 70, .height = 20 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 0 } },
    }, display);

    self.info2 = try self.scroller.add(.{
        .name = "list.instructions",
        .layout = .{ .x = .grows, .y = .shrinks },
        .minimum = .{ .height = 10 },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Parsing Sets",
        } },
        .pad = .{ .top = 5, .left = 0 },
    }, display);

    const list_menu = try self.scroller.add(.{
        .name = "list_menu",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 30, .right = 30, .top = 8, .bottom = 8 },
        .minimum = .{ .width = 200, .height = 20 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 22,
        } },
    }, display);

    self.new_list_button = try list_menu.add(.{
        .name = "new.word.list",
        .minimum = .{ .width = 10, .height = 15 },
        .background = .{
            .corner_radius = 14,
            .image_corner_radius = 50,
        },
        .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .faded,
        .type = .{ .button = .{
            .text = "New Word Set",
            .icon = .{
                .default_name = "new list button",
                .hover_name = "new list button",
                .pressed_name = "new list button",
                .size = .{ .width = 20, .height = 20 },
            },
            .button = .{
                .default_name = "default button",
                .pressed_name = "pressed button",
                .hover_name = "hover button",
            },
            .on_pressed = .{ .func = @ptrCast(&tapNewWordList), .ptr = self },
            .spacing = 8,
        } },
    }, display);

    self.bottom_spacer = try context.display.add_spacer(self.panel, 80);
    self.bottom_spacer.on_resized = .{ .func = @ptrCast(&MenuUI.update_bottom_spacing), .ptr = self };
}

pub fn setupLists(self: *ParsingMenuScreen) (error{ OutOfMemory, UnknownImageFormat, ResourceNotFound, ResourceReadError } || engine.Error || ResourcesError)!void {
    const ctx = ac.app_context.?;
    const display = ctx.display;

    // Remove existing list items
    var list_pos: usize = 0;
    for (self.scroller.type.panel.children.items, 0..) |child, i| {
        if (std.mem.eql(u8, child.name, "list.instructions")) {
            list_pos = i + 1;
            break;
        }
    }

    while (true) {
        if (list_pos >= self.scroller.type.panel.children.items.len) {
            break;
        }
        const item = self.scroller.type.panel.children.items[list_pos];
        if (!std.mem.eql(u8, item.name, "list.item")) {
            break;
        }
        const found = self.scroller.removeEntityAt(display, list_pos);
        found.destroy(display);
    }

    for (ac.app_context.?.lists.sets.items) |list| {
        // Add refreshed list items
        _ = try self.scroller.insert(list_pos, .{
            .name = "list.item",
            .layout = .{ .x = .grows, .y = .shrinks },
            .minimum = .{ .height = 10 },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = list.name.items,
                .on_pressed = .{ .func = @ptrCast(&tapPracticeList), .ptr = self },
            } },
        }, display);
    }
    display.relayout();
}

fn make_button_bar(
    self: *ParsingMenuScreen,
    display: *Display,
    parent: *Entity,
    row_name: []const u8,
    words: []const []const u8,
) !void {
    var button_bar = try parent.add(.{
        .name = row_name,
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .top = 2, .bottom = 2 },
        .minimum = .{ .width = 200, .height = 20 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 12,
        } },
    }, display);

    for (words) |word| {
        _ = try button_bar.add(.{
            .name = word,
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = 15, .right = 15, .top = 12, .bottom = 12 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .background = .{
                .corner_radius = 14,
                .image_corner_radius = 50,
            },
            .type = .{ .button = .{
                .text = word,
                .on_pressed = .{ .func = @ptrCast(&tapPracticeWord), .ptr = self },
                .button = .{
                    .default_name = "default button",
                    .pressed_name = "pressed button",
                    .hover_name = "hover button",
                },
            } },
        }, display);
    }
}

pub fn tapPracticeList(
    _: *ParsingMenuScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    if (ac.app_context.?.lists.lookup(element.type.label.text)) |list| {
        try ac.app_context.?.parsing_setup.study_by_list(display, list, ac.Screen.parsing_menu, event);
        info("Picked list to study {s}", .{list.name.items});
        return;
    }
    err("Unknown list picked {s}", .{element.name});
}

pub fn tapPracticeWord(
    self: *ParsingMenuScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    var found: ?*praxis.Lexeme = null;

    const i = ac.app_context.?.dictionary.by_form.lookup(element.type.button.text) catch {
        notice("practice word parsing for {s} not found.", .{element.type.button.text});
        return;
    };
    if (i) |result| {
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
        try self.app.parsing_setup.study_by_form(display, lexeme, ac.Screen.parsing_menu, event);
        return;
    }

    warn("practice word parsing for {s} not in dictionary.", .{element.type.button.text});
}

pub fn tapNewWordList(
    self: *ParsingMenuScreen,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try self.app.list_new.show(display, entity, event);
}

pub fn resizeVerticalScroller(
    _: *ParsingMenuScreen,
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
    const want_scroller_height = display.root.rect.height -
        scroll.rect.y - menu_area - display.safe_area.bottom -
        display.safe_area.top - 30;
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
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const err = engine.log.err;
const warn = engine.log.warn;
const info = engine.log.info;
const notice = engine.log.notice;
const debug = engine.log.debug;

const praxis = @import("praxis");
const Lang = praxis.Lang;

const ac = @import("App.zig");
const AppContext = ac.AppContext;
const MenuUI = @import("MenuUI.zig");
const ResourcesError = @import("resources").Resources.Error;
const Lists = @import("Lists.zig");
