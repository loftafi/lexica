pub const MAX_SEARCH_RESULTS: usize = 30;

var panel: *Element = undefined;
pub var scroller: *Element = undefined;
var text_input: *Element = undefined;

var seen_result: AutoHashMap(u24, *Form) = undefined;
var search_results: [MAX_SEARCH_RESULTS]*Element = undefined;
var search_result_form: [MAX_SEARCH_RESULTS]?*praxis.Form = [_]?*praxis.Form{null} ** MAX_SEARCH_RESULTS;
var search_transliterations: [MAX_SEARCH_RESULTS][praxis.MAX_WORD_SIZE * 2]u8 = undefined;

var string_buffers: [MAX_SEARCH_RESULTS * 2]ArrayList(u8) = undefined;
var string_buffer_index: usize = 0;

pub fn show(display: *Display, _: *Element) error{OutOfMemory}!void {
    display.choose_panel("search.screen");
}

pub fn init(context: *AppContext) !void {
    seen_result = AutoHashMap(u24, *Form).init(context.display.allocator);
    for (0..string_buffers.len) |i| {
        string_buffers[i] = ArrayList(u8).init(context.display.allocator);
    }
    string_buffer_index = 0;

    panel = try context.display.root.add(try engine.create_panel(
        context.display,
        "",
        .{
            .name = "search.screen",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .visible = .hidden,
            .type = .{ .panel = .{ .direction = .top_to_bottom, .spacing = 35 } },
        },
    ));

    _ = try context.display.add_spacer(panel, 1);

    text_input = try panel.add(try engine.create_text_input(
        context.display,
        "",
        "αγαπη, agape, love",
        "icon search",
        "white rounded rect",
        .{
            .name = "search_query",
            .rect = .{ .width = 500, .height = 20 },
            .layout = .{ .x = .grows },
            .minimum = .{ .height = 20 },
            .type = .{ .text_input = .{
                .max_runes = @min(30, praxis.MAX_WORD_SIZE),
                .on_change = search_query_changed,
                .on_submit = search_query_changed,
            } },
        },
    ));

    scroller = try panel.add(try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 400, .height = 600 },
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
            .on_resized = vertical_scroller_resize,
        },
    ));

    // Keep a global array of these for easy access to their position in the element tree.
    var x: usize = 0;
    for (0..MAX_SEARCH_RESULTS) |i| {
        const element = try create_search_result_panel(context.display, 100);
        search_results[i] = element;
        search_result_form[i] = null;
        if (i < ac.app_context.?.view_history.items.len) {
            search_result_form[i] = ac.app_context.?.view_history.items[i];
            try update_search_result_row(search_result_form[i].?, &x, &seen_result, "");
        }
        try scroller.add_element(element);
    }
}

pub fn deinit() void {
    seen_result.deinit();
    for (0..string_buffers.len) |i| {
        string_buffers[i].deinit();
    }
}

pub fn remove_form_from_view_history(form: *praxis.Form) void {
    for (0..ac.app_context.?.view_history.items.len) |i| {
        if (ac.app_context.?.view_history.items[i].uid == form.uid) {
            _ = ac.app_context.?.view_history.orderedRemove(i);
            return;
        }
    }
}

pub fn search_word_tap(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type != .label) {
        return;
    }
    for (search_results, 0..) |_, x| {
        if (search_result_form[x]) |form| {
            if (!std.mem.eql(u8, form.word, element.type.label.text)) {
                continue;
            }
            remove_form_from_view_history(form);
            if (ac.app_context.?.view_history.items.len == ac.MAX_SEARCH_HISTORY) {
                _ = ac.app_context.?.view_history.pop();
            }
            try ac.app_context.?.view_history.insert(0, form);
            ac.app_context.?.save_view_history();
            if (form.lexeme) |lexeme| {
                return show_word_panel(display, lexeme);
            }
            warn("tap on search result {d} has form with no lexeme", .{x});
            return;
        } else {
            warn("tap on search result {d} with no form", .{x});
            return;
        }
    }
    warn("tap on search result found no form", .{});
    return;
}

pub fn search_result_tap(display: *Display, element: *Element) error{OutOfMemory}!void {
    for (search_results, 0..) |i, x| {
        if (i == element) {
            if (search_result_form[x]) |form| {
                remove_form_from_view_history(form);
                if (ac.app_context.?.view_history.items.len == ac.MAX_SEARCH_HISTORY) {
                    _ = ac.app_context.?.view_history.pop();
                }
                try ac.app_context.?.view_history.insert(0, form);
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

/// When the search query text input box changes, update the search results entities.
pub fn search_query_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const query = element.type.text_input.text.items;

    trace("search query text_input changed: {s}", .{query});

    var i: usize = 0;
    seen_result.clearRetainingCapacity();

    if (ac.app_context.?.dictionary.by_form.lookup(query)) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) {
                break;
            }
            const selected = select_primary_form(word.*, query);
            try update_search_result_row(selected, &i, &seen_result, query);
        }
    }

    if (ac.app_context.?.dictionary.by_gloss.lookup(query)) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) {
                break;
            }
            const selected = select_primary_form(word.*, query);
            try update_search_result_row(selected, &i, &seen_result, query);
        }
    }

    if (ac.app_context.?.dictionary.by_transliteration.lookup(query)) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) {
                break;
            }
            const selected = select_primary_form(word.*, query);
            try update_search_result_row(selected, &i, &seen_result, query);
        }
    }

    trace("search for '{s}' found {d} result(s)", .{ query, i });

    if (i == 0 and query.len == 0) {
        for (ac.app_context.?.view_history.items) |form| {
            search_result_form[i] = form;
            try update_search_result_row(form, &i, &seen_result, query);
        }
    }

    while (i < MAX_SEARCH_RESULTS) : (i += 1) {
        const top = search_results[i].type.panel.children.items[0];
        try top.type.panel.children.items[0].set_text(display, "", false);
        try top.type.panel.children.items[1].set_text(display, "", false);
        try search_results[i].type.panel.children.items[1].set_text(display, "", false);
        search_results[i].visible = .hidden;
        search_result_form[i] = null;
    }

    scroller.offset = .{ .x = 0, .y = 0 };

    display.need_relayout = true;
}

pub fn show_search_history(display: *Display) error{OutOfMemory}!void {
    var x: usize = 0;
    for (0..MAX_SEARCH_RESULTS) |i| {
        if (i < ac.app_context.?.view_history.items.len) {
            search_result_form[i] = ac.app_context.?.view_history.items[i];
            try update_search_result_row(search_result_form[i].?, &x, &seen_result, "");
        } else {
            const top = search_results[i].type.panel.children.items[0];
            try top.type.panel.children.items[0].set_text(display, "", false);
            try top.type.panel.children.items[1].set_text(display, "", false);
            try search_results[i].type.panel.children.items[1].set_text(display, "", false);
            search_results[i].visible = .hidden;
            search_result_form[i] = null;
        }
    }
}

pub inline fn best_width(display: *Display) f32 {
    if (display.root.rect.width > 1020) {
        return 1000;
    } else if (display.root.rect.width < 500) {
        return 500;
    } else {
        return display.root.rect.width - 20;
    }
}

pub fn vertical_scroller_resize(display: *Display, scroll: *Element) bool {
    var updated = false;
    const menu_area = MenuUI.menubar_height(display);
    debug("handle resize. menu_height={d} root.height={d} scroller.top={d}, safe.top={d}, safe.bottom={d}", .{
        menu_area,
        display.root.rect.height,
        scroll.rect.y,
        display.safe_area.top,
        display.safe_area.bottom,
    });
    const want_scroller_height = display.root.rect.height - scroll.rect.y - menu_area - display.safe_area.bottom - display.safe_area.top;
    if (scroll.rect.height != want_scroller_height) {
        scroll.rect.height = want_scroller_height;
        scroll.minimum.height = scroll.rect.height;
        scroll.maximum.height = scroll.rect.height;
        updated = true;
    }
    return updated;
}

inline fn update_search_result_row(
    form: *praxis.Form,
    i: *usize,
    seen: *AutoHashMap(u24, *Form),
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

    const transliterated = praxis.transliterate(form.word, true, search_transliterations[i.*][0 .. praxis.MAX_WORD_SIZE * 2]) catch "";

    const top = search_result.type.panel.children.items[0];
    const bottom = search_result.type.panel.children.items[1];
    try top.type.panel.children.items[0].set_text(display, form.word, false);
    try top.type.panel.children.items[1].set_text(display, transliterated, false);
    try bottom.set_text(display, string_buffers[string_buffer_index].items, false);
    search_result.visible = .visible;
    search_result_form[i.*] = form;
    string_buffer_index += 1;
    if (string_buffer_index >= string_buffers.len) {
        string_buffer_index = 0;
    }
    i.* += 1;
}

/// If the query text matches the root/primary lexeme form, use the
/// root/primary lexeme form instead of the search result form.
pub fn select_primary_form(word: *praxis.Form, query: []const u8) *Form {
    if (word.lexeme == null) {
        return word;
    }
    const primary = word.lexeme.?.primary_form();
    if (primary == null) {
        return word;
    }

    // Check prefix presuming Greek letters
    var normalised_word = std.BoundedArray(u8, praxis.MAX_WORD_SIZE + 1){};
    var unaccented_word = std.BoundedArray(u8, praxis.MAX_WORD_SIZE + 1){};
    praxis.normalise_word(primary.?.word, &unaccented_word, &normalised_word) catch |e| {
        warn("select_primary_form({s},{s}) normalise failed. {any}", .{ word.word, query, e });
        return word;
    };
    if (std.mem.startsWith(u8, unaccented_word.slice(), query)) {
        return primary.?;
    }
    if (std.mem.startsWith(u8, normalised_word.slice(), query)) {
        return primary.?;
    }

    // Check prefix presuming transliterated English
    var buffer: [praxis.MAX_WORD_SIZE * 2]u8 = undefined;
    const transliterated = praxis.transliterate(primary.?.word, false, &buffer) catch |e| {
        warn("select_primary_form({s},{s}) transliterate failed {any}", .{ word.word, query, e });
        return word;
    };
    if (std.ascii.startsWithIgnoreCase(transliterated, query)) {
        return primary.?;
    }

    return word;
}

pub fn create_search_result_panel(display: *Display, y_offset: f32) !*Element {
    var result = try engine.create_panel(
        display,
        "",
        .{
            .name = "search.result",
            .focus = .never_focus,
            .visible = .hidden,
            .pad = .{ .left = 15 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .type = .{ .panel = .{
                .direction = .top_to_bottom,
                .on_click = search_result_tap,
            } },
        },
    );

    var top = try engine.create_panel(
        display,
        "",
        .{
            .name = "search.result.top.row",
            .focus = .never_focus,
            .minimum = .{ .width = 300, .height = 10 },
            .pad = .{ .left = 0, .right = 0, .top = 10, .bottom = 5 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .start, .y = .start },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 20,
            } },
        },
    );
    try result.add_element(top);
    var l1 = try engine.create_label(
        display,
        "",
        .{
            .name = "word",
            .minimum = .{ .width = 50, .height = 10 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .label = .{
                .text = "",
                .text_size = .subheading,
                .text_colour = .tinted,
                .on_click = search_word_tap,
            } },
        },
    );
    l1.pad.left = 5;
    l1.pad.right = 5;
    l1.pad.top = 2;
    l1.pad.bottom = 2;
    try top.add_element(l1);

    var l2 = try engine.create_label(
        display,
        "",
        .{
            .name = "transliteration",
            .focus = .never_focus,
            .minimum = .{ .width = 50 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .label = .{
                .text = "",
                .text_size = .normal,
                .text_colour = .tinted,
            } },
        },
    );
    l2.pad.left = 5;
    l2.pad.right = 0;
    l2.pad.top = 9;
    l2.pad.bottom = 5;
    try top.add_element(l2);

    const l3 = try engine.create_label(
        display,
        "",
        .{
            .name = "glosses.row",
            .focus = .never_focus,
            .rect = .{ .x = 0, .y = y_offset + 50, .width = 600, .height = 60 },
            .minimum = .{ .width = 300, .height = 10 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .type = .{ .label = .{
                .text = "",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    );
    l3.pad.top = 0;
    l3.pad.bottom = 2;
    l3.pad.left = 8;
    try result.add_element(l3);

    return result;
}

const std = @import("std");
const praxis = @import("praxis");
const Form = praxis.Form;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const ac = @import("app_context.zig");
const MenuUI = @import("menu_ui.zig");
const AppContext = ac.AppContext;
const engine = @import("engine");
const Display = engine.Display;
const Element = engine.Element;
const debug = engine.debug;
const trace = engine.trace;
const warn = engine.warn;
const Lang = @import("praxis").Lang;
const show_word_panel = @import("screen_word_info.zig").show;
