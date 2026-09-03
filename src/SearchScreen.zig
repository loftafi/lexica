pub const SearchScreen = @This();

pub const MAX_SEARCH_RESULTS: usize = 30;

app: *AppContext = undefined,

panel: *Entity = undefined,
scroller: *Entity = undefined,
text_input: *Entity = undefined,

seen_result: AutoHashMap(u24, *Form) = undefined,
search_results: [MAX_SEARCH_RESULTS]*Entity = undefined,
search_result_form: [MAX_SEARCH_RESULTS]?*praxis.Form = @splat(null),
search_transliterations: [MAX_SEARCH_RESULTS][praxis.max_word_size * 2]u8 = undefined,

string_buffers: [MAX_SEARCH_RESULTS * 2]std.Io.Writer.Allocating = undefined,
string_buffer_index: usize = 0,

pub fn show(
    _: *SearchScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try display.choosePanel("search.screen", event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
}

pub fn init(self: *SearchScreen, app: *AppContext) !void {
    self.app = app;

    try app.display.requireResourceRecord("dict", .bin);

    self.seen_result = AutoHashMap(u24, *Form).init(app.display.allocator);
    for (0..self.string_buffers.len) |i| {
        self.string_buffers[i] = .init(app.display.allocator);
    }
    self.string_buffer_index = 0;

    self.panel = try app.display.addPanel(.{
        .name = "search.screen",
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .visible = .hidden,
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
            .spacing = 17,
            .choosable = .choosable,
        } },
    });

    _ = try app.display.add_spacer(self.panel, 1);

    self.text_input = try self.panel.add(.{
        .name = "search_query",
        .background = .{
            .image_name = "white rounded rect",
            .corner_radius = 14,
            .image_corner_radius = 14,
        },
        .rect = .{ .width = 500, .height = 20 },
        .layout = .{ .x = .grows },
        .minimum = .{ .height = 20 },
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .type = .{ .text_input = .{
            .max_length = @min(30, praxis.max_word_size),
            .on_change = .{ .func = @ptrCast(&search_query_changed), .ptr = self },
            .on_submit = .{ .func = @ptrCast(&search_query_changed), .ptr = self },
            .placeholder_text = "αγαπη, agape, love",
            .icon_texture_name = "icon search",
        } },
    }, app.display);

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .minimum = .{ .width = 300, .height = 300 },
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
        .on_resized = .{ .func = @ptrCast(&vertical_scroller_resize), .ptr = self },
    }, app.display);

    // Keep a global array of these for easy access to their position in the element tree.
    var x: usize = 0;
    for (0..MAX_SEARCH_RESULTS) |i| {
        const element = try self.initSearchResultPanel(app.display, self.scroller, 100);
        self.search_results[i] = element;
        self.search_result_form[i] = null;
        if (i < app.view_history.items.len) {
            self.search_result_form[i] = app.view_history.items[i];
            try self.update_search_result_row(self.search_result_form[i].?, &x, &self.seen_result, "");
        }
    }
}

pub fn deinit(self: *SearchScreen, _: Allocator) void {
    self.seen_result.deinit();
    for (0..self.string_buffers.len) |i| {
        self.string_buffers[i].deinit();
    }
}

pub fn remove_form_from_view_history(self: *SearchScreen, form: *praxis.Form) void {
    for (0..self.app.view_history.items.len) |i| {
        if (self.app.view_history.items[i].uid == form.uid) {
            _ = self.app.view_history.orderedRemove(i);
            return;
        }
    }
}

pub fn tapSearchResult(
    self: *SearchScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    for (self.search_results, 0..) |i, x| {
        if (i == element) {
            if (self.search_result_form[x]) |form| {
                self.remove_form_from_view_history(form);
                if (ac.app_context.?.view_history.items.len == ac.MAX_SEARCH_HISTORY) {
                    _ = ac.app_context.?.view_history.pop();
                }
                try ac.app_context.?.view_history.insert(display.allocator, 0, form);
                ac.app_context.?.save_view_history() catch {
                    err("Save word view history failed.", .{});
                };
                if (form.lexeme) |lexeme| {
                    //debug("tap on search result found matching form", .{});
                    return ac.app_context.?.word_info.show(display, lexeme, event);
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
pub fn search_query_changed(
    self: *SearchScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) error{OutOfMemory}!void {
    const query = element.type.text_input.text.items;

    trace("search query text_input changed: {s}", .{query});

    var i: usize = 0;
    self.seen_result.clearRetainingCapacity();

    var item = ac.app_context.?.dictionary.by_form.lookup(query) catch null;
    if (item) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) {
                break;
            }
            const selected = select_primary_form(word.*, query);
            try self.update_search_result_row(selected, &i, &self.seen_result, query);
        }
    }

    item = ac.app_context.?.dictionary.by_gloss.lookup(query) catch null;
    if (item) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) {
                break;
            }
            const selected = select_primary_form(word.*, query);
            try self.update_search_result_row(selected, &i, &self.seen_result, query);
        }
    }

    item = ac.app_context.?.dictionary.by_transliteration.lookup(query) catch null;
    if (item) |result| {
        var iter = result.iterator();
        while (iter.next()) |*word| {
            if (i >= MAX_SEARCH_RESULTS) {
                break;
            }
            const selected = select_primary_form(word.*, query);
            try self.update_search_result_row(selected, &i, &self.seen_result, query);
        }
    }

    trace("search for '{s}' found {d} result(s)", .{ query, i });

    if (i == 0 and query.len == 0) {
        for (ac.app_context.?.view_history.items) |form| {
            self.search_result_form[i] = form;
            try self.update_search_result_row(form, &i, &self.seen_result, query);
        }
    }

    while (i < MAX_SEARCH_RESULTS) : (i += 1) {
        const top = self.search_results[i].type.panel.children.items[0];
        try top.type.panel.children.items[0].setText(display, "");
        try top.type.panel.children.items[1].setText(display, "");
        try self.search_results[i].type.panel.children.items[1].setText(display, "");
        self.search_results[i].visible = .hidden;
        self.search_result_form[i] = null;
    }

    self.scroller.offset = .{ .x = 0, .y = 0 };

    display.need_relayout = true;
}

pub fn show_search_history(self: *SearchScreen, display: *Display) error{OutOfMemory}!void {
    var x: usize = 0;
    for (0..MAX_SEARCH_RESULTS) |i| {
        if (i < ac.app_context.?.view_history.items.len) {
            self.search_result_form[i] = ac.app_context.?.view_history.items[i];
            try self.update_search_result_row(self.search_result_form[i].?, &x, &self.seen_result, "");
        } else {
            const top = self.search_results[i].type.panel.children.items[0];
            try top.type.panel.children.items[0].setText(display, "");
            try top.type.panel.children.items[1].setText(display, "");
            try self.search_results[i].type.panel.children.items[1].setText(display, "");
            self.search_results[i].visible = .hidden;
            self.search_result_form[i] = null;
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

pub fn vertical_scroller_resize(
    _: *SearchScreen,
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
    self: *SearchScreen,
    form: *praxis.Form,
    i: *usize,
    seen: *AutoHashMap(u24, *Form),
    _: []const u8,
) Allocator.Error!void {
    var search_result = self.search_results[i.*];
    const display = ac.app_context.?.display;

    if (form.lexeme) |lexeme| {
        if (seen.contains(lexeme.uid)) {
            return;
        }
        try seen.put(lexeme.uid, form);
    }
    self.string_buffers[self.string_buffer_index].clearRetainingCapacity();
    if (form.glossesByLang(Lang.english)) |value| {
        value.string(&self.string_buffers[self.string_buffer_index].writer) catch return;
    } else {
        return;
    }

    const transliterated = praxis.transliterate(form.word, true, self.search_transliterations[i.*][0 .. praxis.max_word_size * 2]) catch "";

    search_result.aria_label = self.app.bucket.addFmt("View '{s}' details", .{form.word}) catch "View Details";

    const top = search_result.type.panel.children.items[0];
    const bottom = search_result.type.panel.children.items[1];
    try top.type.panel.children.items[0].setText(display, form.word);
    try top.type.panel.children.items[1].setText(display, transliterated);
    try bottom.setText(display, self.string_buffers[self.string_buffer_index].written());
    search_result.visible = .visible;
    self.search_result_form[i.*] = form;
    self.string_buffer_index += 1;
    if (self.string_buffer_index >= self.string_buffers.len) {
        self.string_buffer_index = 0;
    }
    i.* += 1;
}

/// If the query text matches the root/primary lexeme form, use the
/// root/primary lexeme form instead of the search result form.
pub fn select_primary_form(word: *praxis.Form, query: []const u8) *Form {
    if (word.lexeme == null) {
        return word;
    }
    const primary = word.lexeme.?.primaryForm();
    if (primary == null) {
        return word;
    }

    // Check prefix presuming Greek letters
    var normalised: praxis.Normaliser.Keywords(praxis.max_word_size + 1) = .empty;
    const k = normalised.normalise(primary.?.word) catch |e| {
        warn("select_primary_form({s},{s}) normalise failed. {any}", .{ word.word, query, e });
        return word;
    };
    if (std.mem.startsWith(u8, k.unaccented, query)) {
        return primary.?;
    }
    if (std.mem.startsWith(u8, k.accented, query)) {
        return primary.?;
    }

    // Check prefix presuming transliterated English
    var buffer: [praxis.max_word_size * 2]u8 = undefined;
    const transliterated = praxis.transliterate(primary.?.word, false, &buffer) catch |e| {
        warn("select_primary_form({s},{s}) transliterate failed {any}", .{ word.word, query, e });
        return word;
    };
    if (std.ascii.startsWithIgnoreCase(transliterated, query)) {
        return primary.?;
    }

    return word;
}

pub fn initSearchResultPanel(
    self: *SearchScreen,
    display: *Display,
    parent: *Entity,
    y_offset: f32,
) !*Entity {
    var result = try parent.add(.{
        .name = "search.result",
        .aria_label = "Search Result Row",
        .visible = .hidden,
        .pad = .{ .left = 7 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
            .on_pressed = .{ .func = @ptrCast(&tapSearchResult), .ptr = self },
        } },
    }, display);

    var top_row = try result.add(.{
        .name = "search.result.top.row",
        .focus = .never_focus,
        .minimum = .{ .height = 10 },
        .pad = .{ .top = 10, .bottom = 0 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .start, .y = .start },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 10,
        } },
    }, display);

    _ = try top_row.add(.{
        .name = "word",
        .focus = .accessibility_focus,
        .minimum = .{ .width = 30, .height = 10 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{ .label = .{
            .text_size = .subheading,
        } },
        .pad = .{ .left = 3, .right = 3, .top = 0, .bottom = 0 },
    }, display);

    _ = try top_row.add(.{
        .name = "transliteration",
        .focus = .accessibility_focus,
        .minimum = .{ .width = 30 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{ .label = .{} },
        .pad = .{ .left = 3, .right = 0, .top = 4, .bottom = 0 },
    }, display);

    _ = try result.add(.{
        .name = "glosses.row",
        .focus = .accessibility_focus,
        .rect = .{ .x = 0, .y = y_offset + 25, .width = 300, .height = 20 },
        .minimum = .{ .width = 300, .height = 10 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .label = .{} },
        .pad = .{ .left = 4, .right = 0, .top = 0, .bottom = 1 },
    }, display);

    return result;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const debug = engine.log.debug;
const trace = engine.log.trace;
const warn = engine.log.warn;
const err = engine.log.err;

const praxis = @import("praxis");
const Lang = praxis.Lang;
const Form = praxis.Form;

const ac = @import("App.zig");
const AppContext = ac.AppContext;
const MenuUI = @import("MenuUI.zig");
const WordInfoScreen = @import("WordInfoScreen.zig");
const show_word_panel = WordInfoScreen.show;
