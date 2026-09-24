/// Present the menu that has shortcut to common words used
/// for parsing, and any special user created parsing sets.
///
/// `init` builds up the entire screen, without any word sets
/// that may exist. `setupLists` is then used to add/update
/// the list ofavailable word sets.
pub const ParsingMenuScreen = @This();

app: *App = undefined,
panel: *Entity = undefined,
scroller: *Entity = undefined,
info2: *Entity = undefined,
new_list_button: *Entity = undefined,
bottom_spacer: *Entity = undefined,

const ICON_PAD = 12;

pub fn show(
    self: *ParsingMenuScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (display.currentPanel()) |current| if (current == self.panel) return;
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
    context: *App,
) (engine.Error || error{ OutOfMemory, UnknownImageFormat, ResourceNotFound, ResourceReadError } || Resources.Error)!void {
    var display = context.display;
    self.app = context;

    _ = try display.appendPanel(
        \\panel:panel name "parsing.menu" spacing 5 vertical hidden
        \\  choosable avoid_safe_area
        \\  layout grows grows
        \\  align centre start
        \\  minimum 100 100
        \\  maximum width=420
        \\  pad left=1em right=1em pad top=0.5em
        \\  on_resized resizeVerticalScroller
        \\{
        \\  panel horizontal
        \\    layout grows shrinks align centre centre
        \\    spacing 0.6em pad bottom=1em
        \\  {
        \\    button name "heading_icon" icon_default "icon-parsing-check" never_focus
        \\      rect width=1.5em height=1.5em
        \\      layout fixed fixed
        \\      align centre centre
        \\      icon_size width=1.5em height=1.5em
        \\
        \\    label name "heading_text" text "PARSING_QUIZ"
        \\      style tinted accessibility_focus
        \\      layout shrinks shrinks align centre centre
        \\      text_size heading
        \\      pad top=0em bottom=0em
        \\  }
        \\  panel:scroller name "scroll.panel" vertical spacing 0.5em
        \\    layout grows shrinks align centre start
        \\    minimum height=600 scroll vertical
        \\  {
        \\  }
        \\  panel:bottom_spacer name "bottom.spacer" horizontal
        \\    layout fixed fixed rect 2em 2em
        \\}
    , ParsingMenuScreen, self);

    try self.initButtonBar(display, self.scroller, "verb.buttons", &[_][]const u8{ "λύω", "βλέπω", "περιπατέω" });
    try self.initButtonBar(display, self.scroller, "contract.buttons", &[_][]const u8{ "ἀγαπάω", "ποιέω", "πληρόω" });
    try self.initButtonBar(display, self.scroller, "other.buttons", &[_][]const u8{ "ῥύομαι", "δίδωμι", "ἐγώ", "εἰμί" });

    _ = try display.add_spacer(self.scroller, 15);

    try self.initButtonBar(display, self.scroller, "masculine.buttons", &[_][]const u8{ "ἄνθρωπος", "λόγος", "θεός" });
    try self.initButtonBar(display, self.scroller, "feminine.buttons", &[_][]const u8{ "γραφή", "ἠμέρα", "δόξα" });
    try self.initButtonBar(display, self.scroller, "neuter.buttons", &[_][]const u8{ "βιβλίον", "ἔργον", "τέκνον" });

    _ = try display.add_spacer(self.scroller, 15);

    try self.initButtonBar(display, self.scroller, "parsing.other", &[_][]const u8{ "βασιλεύς", "πόλις", "σάρξ", "πᾶς" });

    //_ = try self.scroller.add(.{
    //    .name = "bottom.pad",
    //    .rect = .{ .width = 70, .height = 120 },
    //    .minimum = .{ .width = 70, .height = 20 },
    //    .layout = .{ .x = .shrinks, .y = .shrinks },
    //    .type = .{ .expander = .{ .weight = 0 } },
    //}, display);

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
}

pub fn setupLists(self: *ParsingMenuScreen) (error{ OutOfMemory, UnknownImageFormat, ResourceNotFound, ResourceReadError } || engine.Error || Resources.Error)!void {
    const display = self.app.display;

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

    for (self.app.lists.sets.items) |list| {
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

fn initButtonBar(
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
            .pad = .{ .left = 15, .right = 15, .top = 12, .bottom = 12 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .background = .{
                .corner_radius = 22,
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
    self: *ParsingMenuScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    if (self.app.lists.lookup(element.type.label.text)) |list| {
        try self.app.parsing_setup.study_by_list(display, list, App.Screen.parsing_menu, event);
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
    var found: ?*Lexeme = null;

    const i = self.app.dictionary.by_form.lookup(element.type.button.text) catch {
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
        try self.app.parsing_setup.study_by_form(display, lexeme, App.Screen.parsing_menu, event);
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
    self: *ParsingMenuScreen,
    display: *Display,
    _: *Entity,
) bool {
    var updated = false;

    const menu_area = MenuUI.menubar_height();
    debug("handle resize. menu_height={d} root.height={d} scroller.top={d}, safe.top={d}, safe.bottom={d}", .{
        menu_area,
        display.root.rect.height,
        self.scroller.rect.y,
        display.safe_area.top,
        display.safe_area.bottom,
    });
    //const want_scroller_height = display.root.rect.height -
    //    self.scroller.rect.y - menu_area - display.safe_area.bottom -
    //    display.safe_area.top - 30;
    const want_scroller_height = self.panel.rect.height - 60 - self.scroller.rect.y;
    if (self.scroller.rect.height != want_scroller_height) {
        self.scroller.rect.height = want_scroller_height;
        self.scroller.minimum.height = self.scroller.rect.height;
        self.scroller.maximum.height = self.scroller.rect.height;
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
const Lexeme = praxis.Lexeme;

const App = @import("App.zig");
const MenuUI = @import("MenuUI.zig");
const Resources = @import("resources").Resources;
const Lists = @import("Lists.zig");
