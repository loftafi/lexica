//! This scene allows viewing and editing the words in a word set.
//!
//! The scroll panel is overloaded three operating modes. The scroll panel
//! shows:
//!
//!  - The word set contents,
//!  - Search result contents, or
//!  - help instructions when it is empty.
pub const ListEditScreen = @This();

pub const MAX_SEARCH_RESULTS: usize = 30;
pub const MAX_LIST_ENTRIES: usize = Lists.MAX_FORMS_IN_SET;
pub var icon_size: f32 = 18;
pub var icon_pad: f32 = 10;

app: *App = undefined,
panel: *Entity = undefined,
list: ?*WordSet = null,
heading: *Entity = undefined,
scroller: *Entity = undefined,
text_input: *Entity = undefined,
help_line: *Entity = undefined,

// Save and display search results when searching for new words to add.
var seen_result: std.AutoHashMap(u24, *Form) = undefined;
var search_results: [MAX_SEARCH_RESULTS]*Entity = undefined;
var search_result_form: [MAX_SEARCH_RESULTS]?*praxis.Form = @splat(null);
var search_transliterations: [MAX_SEARCH_RESULTS][praxis.MAX_WORD_SIZE * 2]u8 = undefined;

// Hold and display the contents of the word set.
var list_entries: [MAX_LIST_ENTRIES]*Entity = undefined;
var list_transliterations: [MAX_LIST_ENTRIES][praxis.MAX_WORD_SIZE * 2]u8 = undefined;

// String buffers for labels.
var string_buffers: [MAX_SEARCH_RESULTS * 2 + MAX_LIST_ENTRIES * 2]std.Io.Writer.Allocating = undefined;
var string_buffer_index: usize = 0;

pub fn show(
    self: *ListEditScreen,
    display: *Display,
    element: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (self.list == null) {
        err("ListEditScreen.show() expects list was set.", .{});
        return;
    }
    if (self.list) |list| {
        err("Show ListEditScreen: {s}", .{list.name.items});
        try self.heading.setText(display, list.name.items);
        try self.show_list_entries(display, element, event);
        try display.choosePanel(self.panel.name, event);
    } else {
        err("Show ListEditScreen called without a list", .{});
    }
}

pub fn deinit(self: *ListEditScreen, _: Allocator) void {
    seen_result.deinit();
    for (0..string_buffers.len) |i| {
        string_buffers[i].deinit();
    }
    self.* = undefined;
}

pub fn init(
    self: *ListEditScreen,
    app: *App,
) (error{OutOfMemory} || engine.Error || Resources.Error)!void {
    const display = app.display;

    seen_result = std.AutoHashMap(u24, *Form).init(display.allocator);
    for (0..string_buffers.len) |i| {
        string_buffers[i] = .init(display.allocator);
    }
    string_buffer_index = 0;

    self.panel = try display.addPanel(.{
        .name = "list.edit.screen",
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .visible = .hidden,
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
            .spacing = 3,
            .choosable = .choosable,
        } },
        .on_resized = .{ .func = @ptrCast(&resizeList), .ptr = self },
    });
    _ = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    self.heading = try self.panel.add(.{
        .name = "parsing.heading",
        .child_align = .{ .x = .centre },
        .layout = .{ .y = .shrinks, .x = .grows },
        .style = .tinted,
        .type = .{ .label = .{
            .text_size = .heading,
        } },
        .pad = .{ .top = 15, .bottom = 10 },
    }, display);

    _ = try display.add_spacer(self.panel, 1);

    var input_line = try self.panel.add(.{
        .name = "list.edit.screen",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 10, .right = 10 },
        .minimum = .{ .width = 250, .height = 15 },
        .maximum = .{ .width = 500 },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 3 } },
        //.on_resized = .{ .func = @ptrCast(&resizeList), .ptr = self },
    }, display);

    self.text_input = try input_line.add(.{
        .name = "search_query",
        .background = .{
            .image_name = "white rounded rect",
            .corner_radius = 14,
            .image_corner_radius = 50,
        },
        .layout = .{ .x = .grows, .y = .shrinks },
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .minimum = .{ .height = 10 },
        .type = .{ .text_input = .{
            .max_length = @min(30, praxis.max_word_size),
            .on_change = .{ .func = @ptrCast(&changedTextInput), .ptr = self },
            .on_submit = .{ .func = @ptrCast(&changedTextInput), .ptr = self },
            .placeholder_text = "αγαπη, agape, love",
            .icon_texture_name = "icon search",
        } },
    }, display);

    _ = try display.add_spacer(self.panel, 20);

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .minimum = .{ .width = 200, .height = 300 },
        .pad = .{ .left = 10, .right = 10 },
        .type = .{
            .panel = .{
                .scrollable = .{
                    .scroll = .{ .x = false, .y = true },
                    .size = .{ .width = 300, .height = 300 },
                },
                .direction = .top_to_bottom,
                .spacing = 10,
            },
        },
    }, display);

    self.help_line = try self.scroller.add(.{
        .name = "help.line",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Add Verbs, Nouns and Adjectives to this set.",
        } },
    }, display);

    // Build the search result elements
    var x: usize = 0;
    for (0..MAX_SEARCH_RESULTS) |i| {
        const element = try self.initSearchResultRow(display, self.scroller);
        search_results[i] = element;
        search_result_form[i] = null;
        if (i < ac.app_context.?.view_history.items.len) {
            search_result_form[i] = ac.app_context.?.view_history.items[i];
            try update_search_result_panel(search_result_form[i].?, &x, &seen_result, "");
        }
    }

    // Build the list entry elements
    x = 0;
    for (0..MAX_LIST_ENTRIES) |i| {
        list_entries[i] = try self.initListEntryPanel(display, self.scroller);
    }

    _ = try display.add_spacer(self.scroller, 80);
}

pub fn tapSearchResult(display: *Display, element: *Entity) error{OutOfMemory}!void {
    for (search_results, 0..) |i, x| {
        if (i == element) {
            if (search_result_form[x]) |form| {
                try ac.app_context.?.view_history.insert(0, form);
                if (ac.app_context.?.view_history.items.len == ac.MAX_SEARCH_HISTORY) {
                    _ = ac.app_context.?.view_history.pop();
                }
                ac.app_context.?.save_view_history();
                if (form.lexeme) |lexeme| {
                    //debug("tap on search result found matching form", .{});
                    return show_word_panel(display, lexeme);
                }
                warn("tap on search result {d} has form with no lexeme", .{x});
                return;
            } else {
                warn("tap on search result {d} with no form", .{x});
                return;
            }
        }
    }
    warn("tap on search result found no form", .{});
    return;
}

pub fn tapBack(
    self: *ListEditScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try ac.app_context.?.parsing_quiz.setup_with_word_set(self.list.?);
    try display.choosePanel("parsing.setup", event);
}

pub fn show_list_entries(
    self: *ListEditScreen,
    display: *Display,
    _: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {

    // Clear any visible search results to make way for list entries
    var i: usize = 0;
    while (i < MAX_SEARCH_RESULTS) : (i += 1) {
        const result = search_results[i].type.panel.children.items;
        try result[1].setText(display, "");
        try result[2].setText(display, "");
        search_results[i].visible = .hidden;
        search_result_form[i] = null;
    }
    display.need_relayout = true;

    if (self.list == null) {
        err("show_list_entries expects valid list", .{});
        return;
    }

    trace("showing list '{s}' with {d} entries", .{
        self.list.?.name.items,
        self.list.?.forms.items.len,
    });
    const result_count = self.list.?.forms.items.len;
    i = 0;

    for (self.list.?.forms.items) |form| {
        const result = list_entries[i].type.panel.children.items;

        string_buffers[string_buffer_index].clearRetainingCapacity();
        if (form.glossesByLang(Lang.english)) |value| {
            value.string(&string_buffers[string_buffer_index].writer) catch {};
        } else {
            return;
        }

        try result[0].setText(display, form.word);
        try result[1].setText(display, string_buffers[string_buffer_index].written());
        list_entries[i].visible = .visible;
        //_ = self.resizeListEntry(display, list_entries[i], event);

        i += 1;
    }

    while (i < MAX_LIST_ENTRIES) : (i += 1) {
        const result = list_entries[i].type.panel.children.items;
        try result[0].setText(display, "");
        try result[1].setText(display, "");
        list_entries[i].visible = .hidden;
    }

    if (result_count == 0) {
        self.help_line.visible = .visible;
    } else {
        self.help_line.visible = .hidden;
    }

    if (self.list.?.forms.items.len >= Lists.MAX_FORMS_IN_SET) {
        self.text_input.visible = .hidden;
    } else {
        self.text_input.visible = .visible;
    }

    self.scroller.offset = .{ .x = 0, .y = 0 };
    display.relayout();
    display.need_relayout = true;
}

/// Search query text change handler.
///
/// If input box has a search query, show search results.
/// If input box is blank, show list contents or help line.
///
pub fn changedTextInput(
    self: *ListEditScreen,
    display: *Display,
    element: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    const ctx = ac.app_context.?;
    const query = element.type.text_input.text.items;

    trace("search text_input box changed to: {s}", .{query});

    if (query.len == 0) {
        try self.show_list_entries(display, element, event);
        return;
    }

    var i: usize = 0;
    while (i < MAX_LIST_ENTRIES) : (i += 1) {
        const result = list_entries[i].type.panel.children.items;
        try result[1].setText(display, "");
        try result[2].setText(display, "");
        list_entries[i].visible = .hidden;
    }

    i = 0;
    seen_result.clearRetainingCapacity();

    var r = ctx.dictionary.by_form.lookup(query) catch null;
    if (r) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) break;
            if (!can_practice_form(word.*)) continue;
            if (word.*.lexeme) |lexeme| {
                if (lexeme.primaryForm()) |first| {
                    try update_search_result_panel(first, &i, &seen_result, query);
                }
            }
        }
    }

    r = ctx.dictionary.by_gloss.lookup(query) catch null;
    if (r) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) break;
            if (!can_practice_form(word.*)) continue;
            if (word.*.lexeme) |lexeme| {
                if (lexeme.primaryForm()) |first| {
                    try update_search_result_panel(first, &i, &seen_result, query);
                }
            }
        }
    }

    r = ctx.dictionary.by_transliteration.lookup(query) catch null;
    if (r) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) break;
            if (!can_practice_form(word.*)) continue;
            if (word.*.lexeme) |lexeme| {
                if (lexeme.primaryForm()) |first| {
                    try update_search_result_panel(first, &i, &seen_result, query);
                }
            }
        }
    }

    trace("search for '{s}' found {d} result(s)", .{ query, i });
    const result_count = i;

    while (i < MAX_SEARCH_RESULTS) : (i += 1) {
        const result = search_results[i].type.panel.children.items;
        try result[1].setText(display, "");
        try result[2].setText(display, "");
        search_results[i].visible = .hidden;
        search_result_form[i] = null;
    }

    if (result_count == 0) {
        self.help_line.visible = .visible;
    } else {
        self.help_line.visible = .hidden;
    }

    self.scroller.offset = .{ .x = 0, .y = 0 };

    display.need_relayout = true;
}

pub fn tapRemoveWord(
    self: *ListEditScreen,
    display: *Display,
    element: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (self.get_form_from_list_entry_panels(element)) |form| {
        _ = self.list.?.remove(form);
        try ac.app_context.?.lists.save(display.allocator, display.io, &display.config);
        try self.show_list_entries(display, element, event);
    }
}

pub fn get_form_from_list_entry_panels(self: *ListEditScreen, element: *Entity) ?*Form {
    for (list_entries, 0..) |result, i| {
        if (result.type != .panel) {
            continue;
        }
        if (list_entries[i].type.panel.children.items[2] == element) {
            if (i < self.list.?.forms.items.len) {
                //const word = result.type.panel.children.items[1].type.label.text;
                debug("match found {s}", .{self.list.?.forms.items[i].word});
                return self.list.?.forms.items[i];
            }
        }
    }
    debug("no match found", .{});
    return null;
}

/// Handle tapping + in the word search result list.
pub fn tapAddWord(
    self: *ListEditScreen,
    display: *Display,
    element: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    const form_item = self.get_form_from_scroll_list(element);
    if (form_item) |form| {
        info("Adding word {s} to list {s}", .{ form.word, self.list.?.name.items });
        _ = try self.list.?.add(display.allocator, form);
        try ac.app_context.?.lists.save(display.allocator, display.io, &display.config);
        try self.text_input.setText(display, "");
        try self.show_list_entries(display, element, event);
    }
}

pub fn get_form_from_scroll_list(_: *ListEditScreen, element: *Entity) ?*Form {
    for (search_results, 0..) |result, i| {
        if (result.type != .panel) {
            continue;
        }
        if (result.type.panel.children.items[0] == element) {
            if (search_result_form[i]) |word| {
                //const word = result.type.panel.children.items[1].type.label.text;
                debug("match found {s}", .{word.word});
                return word;
            }
        }
    }
    debug("no match found", .{});
    return null;
}

pub fn resizeList(
    self: *ListEditScreen,
    display: *Display,
    _: *Entity,
    _: *const Event,
) bool {
    var updated = false;
    if (self.scroller.rect.height != display.root.rect.height - 170) {
        self.scroller.rect.height = display.root.rect.height - 170;
        self.scroller.minimum.height = self.scroller.rect.height;
        self.scroller.maximum.height = self.scroller.rect.height;
        updated = true;
    }
    for (search_results) |result| {
        if (result.visible == .visible)
            self.resizeSearchResult(display, result, self.scroller.rect.width);
    }
    for (list_entries) |entry| {
        if (entry.visible == .visible)
            self.resizeListEntry(display, entry, self.scroller.rect.width);
    }
    return updated;
}

pub fn resizeListEntry(
    _: *ListEditScreen,
    _: *Display,
    element: *Entity,
    available_width: f32,
) void {
    const word = element.type.panel.children.items[0];
    const gloss = element.type.panel.children.items[1];
    const delete = element.type.panel.children.items[2];
    const gloss_width = available_width - word.rect.width - delete.rect.width - 13;

    gloss.rect.width = gloss_width;
    gloss.minimum.width = gloss_width;
    gloss.maximum.width = gloss_width;
}

pub fn resizeSearchResult(
    _: *ListEditScreen,
    _: *Display,
    element: *Entity,
    available_width: f32,
) void {
    const add = element.type.panel.children.items[0];
    const word = element.type.panel.children.items[1];
    const gloss = element.type.panel.children.items[2];
    const gloss_width = available_width - word.rect.width - add.rect.width - 13;

    gloss.rect.width = gloss_width;
    gloss.minimum.width = gloss_width;
    gloss.maximum.width = gloss_width;
}

inline fn update_search_result_panel(
    form: *praxis.Form,
    i: *usize,
    seen: *std.AutoHashMap(u24, *Form),
    _: []const u8,
) error{OutOfMemory}!void {
    var search_result = search_results[i.*];
    const display = ac.app_context.?.display;

    if (form.lexeme) |lexeme| {
        if (seen.contains(lexeme.uid)) {
            return;
        }
        try seen.put(lexeme.uid, form);
    }
    string_buffers[string_buffer_index].clearRetainingCapacity();
    if (form.glossesByLang(Lang.english)) |value| {
        value.string(&string_buffers[string_buffer_index].writer) catch {};
    } else {
        return;
    }

    const result = search_results[i.*].type.panel.children.items;
    try result[1].setText(display, form.word);
    try result[2].setText(display, string_buffers[string_buffer_index].written());

    search_result.visible = .visible;
    search_result_form[i.*] = form;
    string_buffer_index += 1;
    if (string_buffer_index >= string_buffers.len) {
        string_buffer_index = 0;
    }
    i.* += 1;
}

pub fn initSearchResultRow(
    self: *ListEditScreen,
    display: *Display,
    parent: *Entity,
) (error{OutOfMemory} || engine.Error || Resources.Error)!*Entity {
    var result = try parent.add(.{
        .name = "search.result",
        .visible = .hidden,
        .pad = .{ .left = 15 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{
            .panel = .{
                .direction = .left_to_right,
                .spacing = 5,
            },
        },
        //.on_resized = .{ .func = @ptrCast(&resizeSearchResult), .ptr = self },
    }, display);

    _ = try result.add(.{
        .name = "add.word.button",
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .pad = .{
            .left = icon_pad,
            .right = icon_pad,
            .top = icon_pad,
            .bottom = icon_pad,
        },
        .child_align = .{ .x = .start, .y = .start },
        .background = .{ .corner_radius = 16, .image_corner_radius = 50 },
        .type = .{
            .button = .{
                .on_pressed = .{ .func = @ptrCast(&tapAddWord), .ptr = self },
                .icon = .{
                    .default_name = "add button",
                    .hover_name = "add button",
                    .pressed_name = "add button",
                    .size = .{ .width = icon_size, .height = icon_size },
                },
                .button = .{
                    .default_name = "default button",
                    .hover_name = "hover button",
                    .pressed_name = "pressed button",
                },
            },
        },
    }, display);

    _ = try result.add(.{
        .name = "word",
        .minimum = .{ .width = 25, .height = 25 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .start },
        .style = .tinted,
        .type = .{ .label = .{
            .text_size = .subheading,
        } },
        .pad = .{ .right = 2, .bottom = 3 },
    }, display);

    _ = try result.add(.{
        .name = "glosses.row",
        .minimum = .{ .width = 150, .height = 30 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .label = .{} },
        .pad = .{ .left = 2, .right = 4 },
    }, display);

    return result;
}

pub fn initListEntryPanel(self: *ListEditScreen, display: *Display, parent: *Entity) !*Entity {
    var result = try parent.add(.{
        .name = "list.entry",
        .visible = .hidden,
        .pad = .{ .left = 7 },
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .start, .y = .start },
        .type = .{
            .panel = .{
                .direction = .left_to_right,
                .spacing = 5,
            },
        },
        //.on_resized = .{ .func = @ptrCast(&resizeListEntry), .ptr = self },
    }, display);

    _ = try result.add(.{
        .name = "word.label",
        .minimum = .{ .width = 25, .height = 25 },
        .maximum = .{ .height = 50 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .start },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "",
            .text_size = .subheading,
        } },
        .pad = .{ .right = 2, .top = 2, .bottom = 2 },
    }, display);

    _ = try result.add(.{
        .name = "gloss.label",
        .visible = .visible,
        .minimum = .{ .width = 125, .height = 30 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .label = .{} },
        .pad = .{ .left = 2, .right = 2, .top = 6, .bottom = 4 },
    }, display);

    _ = try result.add(.{
        .name = "delete.word",
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .pad = .{
            .left = icon_pad,
            .right = icon_pad,
            .top = icon_pad,
            .bottom = icon_pad,
        },
        .background = .{ .corner_radius = 16, .image_corner_radius = 50 },
        .child_align = .{ .x = .start, .y = .start },
        .type = .{
            .button = .{
                .icon = .{
                    .size = .{ .width = icon_size, .height = icon_size },
                    .default_name = "trash button",
                    .pressed_name = "trash button",
                    .hover_name = "trash button",
                },
                .button = .{
                    .default_name = "default button",
                    .pressed_name = "pressed button",
                    .hover_name = "hover button",
                },
                .on_pressed = .{ .func = @ptrCast(&tapRemoveWord), .ptr = self },
            },
        },
    }, display);

    return result;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const praxis = @import("praxis");
const Form = praxis.Form;
const Lang = @import("praxis").Lang;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const Resources = @import("resources").Resources;

const err = engine.log.err;
const warn = engine.log.warn;
const info = engine.log.info;
const debug = engine.log.debug;
const trace = engine.log.trace;

const ac = @import("App.zig");
const App = ac.App;

const Lists = @import("Lists.zig");
const WordSet = Lists.WordSet;
const show_word_panel = @import("WordInfoScreen.zig").show;
const can_practice_form = @import("filter_stats.zig").can_practice_form;
