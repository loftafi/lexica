//! This scene allows viewing and editing the words in a word set.
//!
//! The scroll panel is overloaded three operating modes. The scroll panel
//! shows:
//!
//!  - The word set contents,
//!  - Search result contents, or
//!  - help instructions when it is empty.

pub const MAX_SEARCH_RESULTS: usize = 30;
pub const MAX_LIST_ENTRIES: usize = Lists.MAX_FORMS_IN_SET;
pub var icon_size: f32 = 54;
pub var icon_pad: f32 = 8;

var panel: *Element = undefined;
var heading: *Element = undefined;
pub var scroller: *Element = undefined;
var text_input: *Element = undefined;
var help_line: *Element = undefined;
pub var list: ?*WordSet = null;

// Save and display search results when searching for new words to add.
var seen_result: std.AutoHashMap(u24, *Form) = undefined;
var search_results: [MAX_SEARCH_RESULTS]*Element = undefined;
var search_result_form: [MAX_SEARCH_RESULTS]?*praxis.Form = [_]?*praxis.Form{null} ** MAX_SEARCH_RESULTS;
var search_transliterations: [MAX_SEARCH_RESULTS][praxis.MAX_WORD_SIZE * 2]u8 = undefined;

// Hold and display the contents of the word set.
var list_entries: [MAX_LIST_ENTRIES]*Element = undefined;
var list_transliterations: [MAX_LIST_ENTRIES][praxis.MAX_WORD_SIZE * 2]u8 = undefined;

// String buffers for labels.
var string_buffers: [MAX_SEARCH_RESULTS * 2 + MAX_LIST_ENTRIES * 2]std.ArrayList(u8) = undefined;
var string_buffer_index: usize = 0;

pub fn show(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (list == null) {
        err("ListEditScreen.show() expects list was set.", .{});
        return;
    }
    try heading.set_text(display, "", false);
    try heading.set_text(display, list.?.name.items, false);
    try show_list_entries(display, element);
    display.choose_panel("list.edit.screen");
}

pub fn deinit() void {
    seen_result.deinit();
    for (0..string_buffers.len) |i| {
        string_buffers[i].deinit();
    }
}

pub fn infer_icon_size() void {
    const display = ac.app_context.?.display;
    icon_size = display.text_height * display.scale * engine.TextSize.subheading.height();
    icon_size += 8;
    icon_pad = icon_size * 0.25;
}

pub fn init(context: *AppContext) !void {
    const display = context.display;

    seen_result = std.AutoHashMap(u24, *Form).init(display.allocator);
    for (0..string_buffers.len) |i| {
        string_buffers[i] = std.ArrayList(u8).init(display.allocator);
    }
    string_buffer_index = 0;

    panel = try engine.create_panel(
        display,
        "",
        .{
            .name = "list.edit.screen",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .visible = .hidden,
            .type = .{ .panel = .{ .direction = .top_to_bottom, .spacing = 5 } },
            .on_resized = handle_resize,
        },
    );
    _ = try display.add_back_button(panel, go_back);

    heading = try engine.create_label(
        display,
        "",
        .{
            .name = "parsing.heading",
            .child_align = .{ .x = .centre },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .label = .{
                .text = "",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    );
    heading.pad.top = 30;
    heading.pad.bottom = 20;
    try panel.add_element(heading);

    _ = try context.display.add_spacer(panel, 1);

    var input_line = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "list.edit.screen",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 20, .right = 20, .top = 0, .bottom = 0 },
            .minimum = .{ .width = 500, .height = 30 },
            .maximum = .{ .width = 1000 },
            .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 5 } },
            .on_resized = handle_resize,
        },
    );
    try panel.add_element(input_line);

    text_input = try engine.create_text_input(
        context.display,
        "",
        "αγαπη, agape, love",
        "icon search",
        "white rounded rect",
        .{
            .name = "search_query",
            .layout = .{ .x = .grows, .y = .shrinks },
            .pad = .{ .left = 20, .right = 20 },
            .minimum = .{ .height = 20 },
            .type = .{ .text_input = .{
                .max_runes = @min(30, praxis.MAX_WORD_SIZE),
                .on_change = search_update,
                .on_submit = search_update,
            } },
        },
    );
    try input_line.add_element(text_input);

    _ = try context.display.add_spacer(panel, 20);

    scroller = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 400, .height = 600 },
            .pad = .{ .left = 20, .right = 20 },
            .type = .{
                .panel = .{
                    .scrollable = .{
                        .scroll = .{ .x = false, .y = true },
                        .size = .{ .width = 600, .height = 600 },
                    },
                    .direction = .top_to_bottom,
                    .spacing = 20,
                },
            },
        },
    );
    try panel.add_element(scroller);

    help_line = try engine.create_label(
        context.display,
        "",
        .{
            .name = "help.line",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Add Verbs, Nouns and Adjectives to this set.",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    );
    try scroller.add_element(help_line);

    // Build the search result elements
    var x: usize = 0;
    for (0..MAX_SEARCH_RESULTS) |i| {
        const element = try create_search_result_panel(context.display);
        search_results[i] = element;
        search_result_form[i] = null;
        if (i < ac.app_context.?.view_history.items.len) {
            search_result_form[i] = ac.app_context.?.view_history.items[i];
            try update_search_result_panel(search_result_form[i].?, &x, &seen_result, "");
        }
        try scroller.add_element(element);
    }

    // Build the list entry elements
    x = 0;
    for (0..MAX_LIST_ENTRIES) |i| {
        const element = try create_list_entry_panel(context.display);
        list_entries[i] = element;
        try scroller.add_element(element);
    }

    _ = try context.display.add_spacer(scroller, 80);

    try context.display.add_element(panel);
}

pub fn search_result_tap(display: *Display, element: *Element) error{OutOfMemory}!void {
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

pub fn go_back(display: *Display, _: *Element) error{OutOfMemory}!void {
    try ac.app_context.?.parsing_quiz.setup_with_word_set(list.?);
    display.choose_panel("parsing.setup");
}

pub fn show_list_entries(display: *Display, _: *Element) error{OutOfMemory}!void {
    // Clear any visible search results to make way for list entries
    var i: usize = 0;
    while (i < MAX_SEARCH_RESULTS) : (i += 1) {
        const result = search_results[i].type.panel.children.items;
        try result[1].set_text(display, "", false);
        try result[2].set_text(display, "", false);
        search_results[i].visible = .hidden;
        search_result_form[i] = null;
    }
    display.need_relayout = true;

    if (list == null) {
        err("show_list_entries expects valid list", .{});
        return;
    }

    trace("showing list '{s}' with {d} entries", .{ list.?.name.items, list.?.forms.items.len });
    const result_count = list.?.forms.items.len;
    i = 0;

    for (list.?.forms.items) |form| {
        const result = list_entries[i].type.panel.children.items;

        string_buffers[string_buffer_index].clearRetainingCapacity();
        if (form.glosses_by_lang(Lang.english)) |value| {
            try value.string(string_buffers[string_buffer_index].writer());
        } else {
            return;
        }

        try result[0].set_text(display, form.word, false);
        try result[1].set_text(display, string_buffers[string_buffer_index].items, false);
        list_entries[i].visible = .visible;
        _ = fix_gloss_list_width(display, list_entries[i]);

        i += 1;
    }

    while (i < MAX_LIST_ENTRIES) : (i += 1) {
        const result = list_entries[i].type.panel.children.items;
        try result[0].set_text(display, "", false);
        try result[1].set_text(display, "", false);
        list_entries[i].visible = .hidden;
    }

    if (result_count == 0) {
        help_line.visible = .visible;
    } else {
        help_line.visible = .hidden;
    }

    if (list.?.forms.items.len >= Lists.MAX_FORMS_IN_SET) {
        text_input.visible = .hidden;
    } else {
        text_input.visible = .visible;
    }

    scroller.offset = .{ .x = 0, .y = 0 };
    display.relayout();
    display.need_relayout = true;
}

/// Search query text change handler.
///
/// If input box has a search query, show search results.
/// If input box is blank, show list contents or help line.
///
pub fn search_update(display: *Display, element: *Element) error{OutOfMemory}!void {
    const query = element.type.text_input.text.items;

    trace("search text_input box changed to: {s}", .{query});

    if (query.len == 0) {
        try show_list_entries(display, element);
        return;
    }

    var i: usize = 0;
    while (i < MAX_LIST_ENTRIES) : (i += 1) {
        const result = list_entries[i].type.panel.children.items;
        try result[1].set_text(display, "", false);
        try result[2].set_text(display, "", false);
        list_entries[i].visible = .hidden;
    }

    i = 0;
    seen_result.clearRetainingCapacity();

    if (ac.app_context.?.dictionary.by_form.lookup(query)) |result| {
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

    if (ac.app_context.?.dictionary.by_gloss.lookup(query)) |result| {
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

    if (ac.app_context.?.dictionary.by_transliteration.lookup(query)) |result| {
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
        try result[1].set_text(display, "", false);
        try result[2].set_text(display, "", false);
        search_results[i].visible = .hidden;
        search_result_form[i] = null;
    }

    if (result_count == 0) {
        help_line.visible = .visible;
    } else {
        help_line.visible = .hidden;
    }

    scroller.offset = .{ .x = 0, .y = 0 };

    display.need_relayout = true;
}

pub fn remove_word_from_list(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (get_form_from_list_entry_panels(element)) |form| {
        _ = list.?.remove(form);
        try ac.app_context.?.lists.save();
        try show_list_entries(display, element);
    }
}

pub fn get_form_from_list_entry_panels(element: *Element) ?*Form {
    for (list_entries, 0..) |result, i| {
        if (result.type != .panel) {
            continue;
        }
        if (list_entries[i].type.panel.children.items[2] == element) {
            if (i < list.?.forms.items.len) {
                //const word = result.type.panel.children.items[1].type.label.text;
                debug("match found {s}", .{list.?.forms.items[i].word});
                return list.?.forms.items[i];
            }
        }
    }
    debug("no match found", .{});
    return null;
}

/// Handle tapping + in the word search result list.
pub fn add_word_to_list(display: *Display, element: *Element) error{OutOfMemory}!void {
    const form_item = get_form_from_scroll_list(element);
    if (form_item) |form| {
        info("Adding word {s} to list {s}", .{ form.word, list.?.name.items });
        _ = try list.?.add(form);
        try ac.app_context.?.lists.save();
        try text_input.set_text(display, "", false);
        try show_list_entries(display, element);
    }
}

pub fn get_form_from_scroll_list(element: *Element) ?*Form {
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

pub fn fix_gloss_list_width(_: *Display, element: *Element) bool {
    var updated = false;
    const word = element.type.panel.children.items[0];
    const gloss = element.type.panel.children.items[1];
    const delete = element.type.panel.children.items[2];
    const gloss_width = element.rect.width - word.rect.width - delete.rect.width - 26;
    if (gloss.rect.width != gloss_width) {
        gloss.rect.width = gloss_width;
        gloss.minimum.width = gloss_width;
        gloss.maximum.width = gloss_width + 6;
        updated = true;
    }
    return updated;
}

pub fn fix_gloss_result_width(_: *Display, element: *Element) bool {
    var updated = false;
    const add = element.type.panel.children.items[0];
    const word = element.type.panel.children.items[1];
    const gloss = element.type.panel.children.items[2];
    const gloss_width = element.rect.width - word.rect.width - add.rect.width - 26;
    if (gloss.rect.width != gloss_width) {
        gloss.rect.width = gloss_width;
        gloss.minimum.width = gloss_width;
        gloss.maximum.width = gloss_width + 6;
        updated = true;
    }
    return updated;
}

pub fn handle_resize(display: *Display, _: *Element) bool {
    var updated = false;
    if (scroller.rect.height != display.root.rect.height - 340) {
        scroller.rect.height = display.root.rect.height - 340;
        scroller.minimum.height = scroller.rect.height;
        scroller.maximum.height = scroller.rect.height;
        updated = true;
    }
    updated = update_button_sizes() or updated;
    return updated;
}

fn update_button_sizes() bool {
    var updated = false;
    infer_icon_size();
    for (list_entries) |row| {
        updated = fix_button_size(row.type.panel.children.items[2]) or updated;
    }
    for (search_results) |row| {
        updated = fix_button_size(row.type.panel.children.items[0]) or updated;
    }
    return updated;
}

fn fix_button_size(button: *Element) bool {
    if (button.minimum.width == icon_size) {
        return false;
    }
    button.minimum.width = icon_size;
    button.minimum.height = icon_size;
    button.maximum.width = icon_size;
    button.maximum.height = icon_size;
    button.pad = .{ .left = icon_pad, .right = icon_pad, .top = icon_pad, .bottom = icon_pad };
    button.type.button.icon_size.x = icon_size - (icon_pad * 2);
    button.type.button.icon_size.y = icon_size - (icon_pad * 2);
    return true;
}

inline fn update_search_result_panel(
    form: *praxis.Form,
    i: *usize,
    seen: *std.AutoHashMap(u24, *Form),
    _: []const u8,
) !void {
    var search_result = search_results[i.*];
    const display = ac.app_context.?.display;

    if (form.lexeme) |lexeme| {
        if (seen.contains(lexeme.uid)) {
            return;
        }
        try seen.put(lexeme.uid, form);
    }
    string_buffers[string_buffer_index].clearRetainingCapacity();
    if (form.glosses_by_lang(Lang.english)) |value| {
        try value.string(string_buffers[string_buffer_index].writer());
    } else {
        return;
    }

    const result = search_results[i.*].type.panel.children.items;
    try result[1].set_text(display, form.word, false);
    try result[2].set_text(display, string_buffers[string_buffer_index].items, false);

    search_result.visible = .visible;
    search_result_form[i.*] = form;
    string_buffer_index += 1;
    if (string_buffer_index >= string_buffers.len) {
        string_buffer_index = 0;
    }
    i.* += 1;
}

pub fn create_search_result_panel(display: *Display) !*Element {
    var result = try engine.create_panel(
        display,
        "",
        .{
            .name = "search.result",
            .visible = .hidden,
            .pad = .{ .left = 15 },
            .layout = .{ .x = .grows },
            .type = .{
                .panel = .{
                    .direction = .left_to_right,
                    .spacing = 10,
                },
            },
            .on_resized = fix_gloss_result_width,
        },
    );

    try result.add_element(try engine.create_button(
        display,
        "add button",
        "add button",
        "add button",
        .{
            .name = "add.word.button",
            .rect = .{ .width = icon_size, .height = icon_size },
            .minimum = .{ .width = icon_size, .height = icon_size },
            .maximum = .{ .width = icon_size, .height = icon_size },
            .pad = .{
                .left = icon_pad,
                .right = icon_pad,
                .top = icon_pad,
                .bottom = icon_pad,
            },
            .child_align = .{ .x = .start, .y = .start },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{
                .button = .{
                    .text = "",
                    .icon_size = .{
                        .x = icon_size - (icon_pad * 2),
                        .y = icon_size - (icon_pad * 2),
                    },
                    .on_click = add_word_to_list,
                },
            },
        },
        "white rounded rect2",
        "white rounded rect2",
        "white rounded rect2",
    ));

    var word_label = try engine.create_label(
        display,
        "",
        .{
            .name = "word",
            .rect = .{ .height = 50 },
            .minimum = .{ .width = 50, .height = 50 },
            .maximum = .{ .height = 50 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .start },
            .type = .{ .label = .{
                .text = "",
                .text_size = .subheading,
                .text_colour = .tinted,
            } },
        },
    );
    word_label.pad.left = 0;
    word_label.pad.right = 5;
    word_label.pad.top = 0;
    word_label.pad.bottom = 7;
    try result.add_element(word_label);

    const gloss_label = try engine.create_label(
        display,
        "",
        .{
            .name = "glosses.row",
            .minimum = .{ .width = 300, .height = 60 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .type = .{ .label = .{
                .text = "",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    );
    try result.add_element(gloss_label);
    gloss_label.pad.left = 5;
    gloss_label.pad.top = 9;

    return result;
}

pub fn create_list_entry_panel(display: *Display) !*Element {
    var result = try engine.create_panel(
        display,
        "",
        .{
            .name = "list.entry",
            .visible = .hidden,
            .pad = .{ .left = 15 },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .start, .y = .start },
            .type = .{
                .panel = .{
                    .direction = .left_to_right,
                    .spacing = 10,
                },
            },
            .on_resized = fix_gloss_list_width,
        },
    );

    var word_label = try engine.create_label(
        display,
        "",
        .{
            .name = "word.label",
            .minimum = .{ .width = 50, .height = 50 },
            .maximum = .{ .height = 50 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .start },
            .type = .{ .label = .{
                .text = "",
                .text_size = .subheading,
                .text_colour = .tinted,
            } },
        },
    );
    word_label.pad.left = 0;
    word_label.pad.right = 5;
    word_label.pad.top = 5;
    word_label.pad.bottom = 5;
    try result.add_element(word_label);

    const gloss_label = try engine.create_label(
        display,
        "",
        .{
            .name = "gloss.label",
            .visible = .visible,
            .minimum = .{ .width = 250, .height = 60 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .label = .{
                .text = "",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    );
    try result.add_element(gloss_label);
    gloss_label.pad.left = 5;
    gloss_label.pad.right = 5;
    gloss_label.pad.top = 12;
    gloss_label.pad.bottom = 8;

    try result.add_element(try engine.create_button(
        display,
        "trash button",
        "trash button",
        "trash button",
        .{
            .name = "delete.word",
            .rect = .{ .width = icon_size, .height = icon_size },
            .minimum = .{ .width = icon_size, .height = icon_size },
            .maximum = .{ .width = icon_size, .height = icon_size },
            .pad = .{
                .left = icon_pad,
                .right = icon_pad,
                .top = icon_pad,
                .bottom = icon_pad,
            },
            .child_align = .{ .x = .start, .y = .start },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{
                .button = .{
                    .text = "",
                    .on_click = remove_word_from_list,
                    .icon_size = .{
                        .x = icon_size - (icon_pad * 2),
                        .y = icon_size - (icon_pad * 2),
                    },
                },
            },
        },
        "white rounded rect2",
        "white rounded rect2",
        "white rounded rect2",
    ));

    return result;
}

const std = @import("std");
const praxis = @import("praxis");
const Form = praxis.Form;
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const engine = @import("engine");
const Display = engine.Display;
const Element = engine.Element;
const err = engine.err;
const warn = engine.warn;
const info = engine.info;
const debug = engine.debug;
const trace = engine.trace;
const Lang = @import("praxis").Lang;
const Lists = @import("lists.zig");
const WordSet = Lists.WordSet;
const show_word_panel = @import("screen_word_info.zig").show;
const can_practice_form = @import("filter_stats.zig").can_practice_form;
