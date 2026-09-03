//! Setup the word information panel. This shows all information
//! about a word.
pub const WordInfoScreen = @This();

const ICON_PAD = 15;
const FIELD_LABEL_WIDTH = 205;
const FIELD_WIDTH = 205;

app: *App = undefined,
panel: *Entity = undefined,
scroller: *Entity = undefined,
back_button: *Entity = undefined,
practice_button: *Entity = undefined,

word_pos: *Entity = undefined,
word_strongs: *Entity = undefined,
word_tags: *Entity = undefined,
word_articles: *Entity = undefined,
word_title: *Entity = undefined,
word_glosses: *Entity = undefined,
word_transliteration: *Entity = undefined,

row_pos: *Entity = undefined,
row_tags: *Entity = undefined,
row_strongs: *Entity = undefined,
row_articles: *Entity = undefined,

string_buffers: [2][praxis.max_word_size * 2]u8 = undefined,
string_buffers_i: usize = 0,
strongs_buffer: std.Io.Writer.Allocating = undefined,
gloss_buffer: std.Io.Writer.Allocating = undefined,
tags_buffer: std.Io.Writer.Allocating = undefined,

pub fn init(self: *WordInfoScreen, app: *App) !void {
    self.app = app;
    var display = app.display;

    self.gloss_buffer = .init(display.allocator);
    self.strongs_buffer = .init(display.allocator);
    self.tags_buffer = .init(display.allocator);
    self.string_buffers_i = 0;

    self.panel = try display.addPanel(
        .{
            .name = "word.info",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre },
            .visible = .hidden,
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{
                .width = ac.APP_MINIMUM_WIDTH,
                .height = ac.APP_MINIMUM_HEIGHT,
            },
            .type = .{ .panel = .{
                .direction = .top_to_bottom,
                .spacing = 2,
                .choosable = .choosable,
            } },
            .on_resized = .{ .func = @ptrCast(&handle_resize), .ptr = self },
        },
    );

    self.back_button = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&SearchScreen.show),
        .ptr = &app.search_screen,
    });

    _ = try display.add_spacer(self.panel, 10);

    self.word_title = try self.panel.add(.{
        .name = "word",
        .focus = .accessibility_focus,
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "ἄρτος",
            .text_size = .heading,
        } },
        .pad = .{ .top = 15, .bottom = 2 },
    }, display);

    self.word_transliteration = try self.panel.add(.{
        .name = "transliteration",
        .focus = .accessibility_focus,
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows },
        .type = .{ .label = .{
            .text = "artos",
        } },
    }, display);

    self.word_glosses = try self.panel.add(.{
        .name = "glosses",
        .focus = .accessibility_focus,
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .label = .{
            .text = "Bread, food.",
        } },
        .pad = .{ .top = 18, .bottom = 18 },
    }, display);

    _ = try self.panel.add(.{
        .minimum = .{ .width = 10, .height = 10 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .panel = .{} },
    }, display);

    self.row_pos = try self.panel.add(.{
        .name = "row_pos",
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .minimum = .{ .width = 250, .height = 20 },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 10 } },
    }, display);

    _ = try self.row_pos.add(.{
        .name = "pos_label",
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{
            .label = .{
                .text = "Part of Speech",
            },
        },
    }, display);

    self.word_pos = try self.row_pos.add(.{
        .name = "pos",
        .focus = .accessibility_focus,
        .rect = .{ .width = FIELD_WIDTH, .height = 20 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "Verb",
            },
        },
    }, display);

    self.row_strongs = try self.panel.add(.{
        .name = "row_strongs",
        .rect = .{ .width = 10, .height = 20 },
        .minimum = .{ .width = 100, .height = 20 },
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 10 } },
    }, display);

    _ = try self.row_strongs.add(.{
        .name = "strongs_label",
        .focus = .accessibility_focus,
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 20 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{
            .label = .{
                .text = "STRONGS",
            },
        },
    }, display);

    self.word_strongs = try self.row_strongs.add(.{
        .name = "strongs",
        .focus = .accessibility_focus,
        .rect = .{ .width = FIELD_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{},
        },
    }, display);

    self.row_articles = try self.panel.add(.{
        .name = "row_articles",
        .child_align = .{ .x = .centre },
        .minimum = .{ .width = 10, .height = 20 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 10 } },
    }, display);

    _ = try self.row_articles.add(.{
        .name = "articles_label",
        .focus = .accessibility_focus,
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 20 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{
            .label = .{
                .text = "ARTICLES",
            },
        },
    }, display);

    self.word_articles = try self.row_articles.add(.{
        .name = "articles",
        .focus = .accessibility_focus,
        .rect = .{ .width = FIELD_WIDTH, .height = 20 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "---",
            },
        },
    }, display);

    self.row_tags = try self.panel.add(.{
        .name = "row_tags",
        .focus = .accessibility_focus,
        .rect = .{ .width = 10, .height = 20 },
        .minimum = .{ .width = 100, .height = 20 },
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 10 } },
    }, display);

    _ = try self.row_tags.add(.{
        .name = "tags_label",
        .focus = .accessibility_focus,
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 20 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{
            .label = .{
                .text = "Tags",
            },
        },
    }, display);

    self.word_tags = try self.row_tags.add(.{
        .name = "tags",
        .rect = .{ .width = FIELD_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{},
        },
    }, display);

    _ = try display.add_spacer(self.panel, 10);

    _ = try self.panel.add(.{
        .name = "top.expander",
        .rect = .{ .x = 0, .y = 0, .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    self.scroller = try self.panel.add(.{
        .name = "parsing_table_panels",
        .rect = .{ .width = 300, .height = 150 },
        .minimum = .{ .width = 300, .height = 150 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .pad = .{ .left = 20, .right = 20 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 12,
            .scrollable = .{
                .scroll = .{ .x = true, .y = false },
                .size = .{ .width = 300, .height = 150 },
            },
        } },
    }, display);

    for (0..ac.MAX_PANEL_TABLES) |i| {
        const parsing_panel = try initFormPanel(display, self.scroller);
        ac.app_context.?.panel_tables[i] = parsing_panel;
    }

    _ = try display.add_spacer(self.panel, 5);

    _ = try self.panel.add(.{
        .name = "middle.expander",
        .rect = .{ .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    var button_align = try self.panel.add(.{
        .name = "parsing.button.align",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 15, .right = 15, .top = 4, .bottom = 4 },
        .minimum = .{ .width = 250, .height = 10 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 13,
        } },
    }, display);

    self.practice_button = try button_align.add(.{
        .name = "start.button",
        .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
        .background = .{ .corner_radius = 22, .image_corner_radius = 50 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .faded,
        .type = .{
            .button = .{
                .icon = .{
                    .default_name = "parsing button",
                    .hover_name = "parsing button",
                    .pressed_name = "parsing button",
                },
                .button = .{
                    .default_name = "button default",
                    .pressed_name = "button pressed",
                    .hover_name = "button hover",
                },
                .text = "Practice",
                .on_pressed = .{ .func = @ptrCast(&show_parsing_setup), .ptr = self },
                .spacing = 10,
            },
        },
    }, display);

    _ = try self.panel.add(.{
        .name = "bottom.expander",
        .rect = .{ .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    _ = try display.add_spacer(self.panel, 40);
}

pub fn deinit(self: *WordInfoScreen) void {
    self.gloss_buffer.deinit();
    self.strongs_buffer.deinit();
    self.tags_buffer.deinit();
}

/// Handle tap on the "Practice" button.
pub fn show_parsing_setup(
    self: *WordInfoScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    try self.app.parsing_setup.study_by_form(
        display,
        ac.app_context.?.word_lexeme.?,
        ac.Screen.word_info,
        event,
    );
}

pub fn handle_resize(
    self: *WordInfoScreen,
    display: *Display,
    _: *Entity,
) bool {
    var updated = false;

    const size = engine.TextSize.normal.size();
    const height = size + (ICON_PAD * 2);
    if (self.practice_button.type.button.icon.size.width != size) {
        self.practice_button.type.button.icon.size.width = size;
        self.practice_button.type.button.icon.size.height = size;
        self.practice_button.minimum.width = height;
        self.practice_button.rect.height = height;
        self.practice_button.minimum.height = height;
        updated = true;
    }

    self.scroller.maximum.width = display.root.rect.width - 10;
    return updated;
}

pub fn initFormPanel(
    display: *Display,
    parent_panel: *Entity,
) !*Entity {
    var parsing_panel = try parent_panel.add(.{
        .name = "present",
        .background = .{
            .image_name = "white rounded rect",
            .image_corner_radius = 14,
        },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 14, .right = 14, .top = 10, .bottom = 10 },
        .minimum = .{ .width = 145, .height = 130 },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
        } },
    }, display);

    _ = try parsing_panel.add(.{
        .name = "panel.heading",
        .rect = .{ .width = 135, .height = 5 },
        .minimum = .{ .width = 135, .height = 7 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Present",
        } },
        .pad = .{ .left = 1, .right = 1 },
    }, display);

    _ = try parsing_panel.add(.{
        .name = "panel.subheading",
        .rect = .{ .width = 135, .height = 7 },
        .minimum = .{ .width = 135, .height = 7 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Active",
        } },
        .pad = .{ .left = 1, .right = 1 },
    }, display);

    _ = try display.add_spacer(parsing_panel, 7);

    for (0..8) |i| {
        if (i == 3 or i == 4) {
            _ = try display.add_spacer(parsing_panel, 7);
        }

        const row = try parsing_panel.add(.{
            .name = "row",
            .rect = .{ .width = 75, .height = 5 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .minimum = .{ .width = 40, .height = 5 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 7,
            } },
        }, display);

        _ = try row.add(.{
            .name = "col.article",
            .rect = .{ .width = 35, .height = 5 },
            .minimum = .{ .width = 45, .height = 5 },
            .type = .{ .label = .{
                .text = "τὸν",
            } },
            .child_align = .{ .x = .end },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .pad = .{
                .left = 1,
                .right = 1,
                .top = 1,
                .bottom = 1,
            },
        }, display);

        _ = try row.add(.{
            .name = "col.form",
            .rect = .{ .width = 75, .height = 0 },
            .minimum = .{ .width = 75, .height = 0 },
            .type = .{ .label = .{
                .text = "ἄρτος",
            } },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .pad = .{
                .left = 0,
                .right = 0,
                .top = 1,
                .bottom = 1,
            },
        }, display);
    }
    return parsing_panel;
}

pub fn show(
    self: *WordInfoScreen,
    display: *Display,
    lexeme: *praxis.Lexeme,
    event: *const Event,
) Allocator.Error!void {
    ac.app_context.?.word_lexeme = lexeme;
    try self.word_title.setText(display, lexeme.word);

    //const pos = praxis.pos_to_english(lexeme.pos);
    const pos = lexeme.pos.english_part_of_speech();
    try self.word_pos.setText(display, pos);

    self.gloss_buffer.clearRetainingCapacity();
    try self.word_glosses.setText(display, "");
    if (lexeme.glossesByLang(Lang.english)) |value| {
        value.string(&self.gloss_buffer.writer) catch {};
    }
    try self.word_glosses.setText(display, self.gloss_buffer.written());

    self.string_buffers_i += 1;
    if (self.string_buffers_i >= self.string_buffers.len) {
        self.string_buffers_i = 0;
    }
    const transliterated = praxis.transliterate(lexeme.word, true, &self.string_buffers[self.string_buffers_i]) catch "";
    try self.word_transliteration.setText(display, transliterated);

    const uk = ac.app_context.?.preference.uk_order;

    self.practice_button.visible = if (can_practice_lexeme(lexeme)) .visible else .hidden;

    self.row_strongs.visible = .hidden;
    if (ac.app_context.?.preference.show_strongs and lexeme.strongs.items.len > 0) {
        self.strongs_buffer.clearRetainingCapacity();
        self.row_strongs.visible = .visible;
        for (lexeme.strongs.items, 0..) |strongs, i| {
            if (i > 0)
                self.strongs_buffer.writer.writeAll(", ") catch {};
            self.strongs_buffer.writer.print("{d}", .{strongs}) catch {};
        }
        try self.word_strongs.setText(display, self.app.bucket.add(self.strongs_buffer.written()) catch self.strongs_buffer.written());
    }

    self.row_tags.visible = .hidden;
    if (lexeme.tags) |tags| {
        if (tags.len > 0) {
            try self.word_tags.setText(display, "");
            self.tags_buffer.clearRetainingCapacity();
            self.row_tags.visible = .visible;
            for (tags, 0..) |tag, i| {
                if (i > 0)
                    self.tags_buffer.writer.writeAll(", ") catch {};
                self.tags_buffer.writer.writeAll(tag) catch {};
            }
            try self.word_tags.setText(display, self.tags_buffer.written());
        }
    }

    switch (lexeme.article) {
        .masculine => {
            self.row_articles.visible = .visible;
            try self.word_articles.setText(display, "ὁ");
        },
        .feminine => {
            self.row_articles.visible = .visible;
            try self.word_articles.setText(display, "ἡ");
        },
        .neuter => {
            self.row_articles.visible = .visible;
            try self.word_articles.setText(display, "τό");
        },
        .masculine_feminine => {
            self.row_articles.visible = .visible;
            try self.word_articles.setText(display, "ὁ ἡ");
        },
        .masculine_neuter => {
            self.row_articles.visible = .visible;
            try self.word_articles.setText(display, "ὁ τό");
        },
        else => self.row_articles.visible = .hidden,
    }

    const HEADING = 0;
    const SUBHEADING = 1;
    const ROW1 = 3;
    const ROW2 = 4;
    const ROW3 = 5;
    const SPACE3 = 6;
    const ROW4 = 7;
    const SPACE4 = 8;
    const ROW5 = 9;
    const ROW6 = 10;
    const ROW7 = 11;
    const ROW8 = 12;

    ac.app_context.?.panels.*.setLexeme(lexeme);
    const panels = try ac.app_context.?.panels.panels(display.allocator);
    var i: usize = 0;
    for (panels) |*table| {
        if (i >= ac.MAX_PANEL_TABLES) {
            break;
        }
        var current = ac.app_context.?.panel_tables[i];
        var items = current.type.panel.children.items;
        current.visible = .visible;
        try items[HEADING].setText(display, table.*.title);
        try items[SUBHEADING].setText(display, table.*.subtitle);

        {
            // Clear the panel
            try clearTableRow(display, items[ROW1]);
            try clearTableRow(display, items[ROW2]);
            try clearTableRow(display, items[ROW3]);
            try clearTableRow(display, items[ROW4]);
            try clearTableRow(display, items[ROW5]);
            try clearTableRow(display, items[ROW6]);
            try clearTableRow(display, items[ROW7]);
            try clearTableRow(display, items[ROW8]);
        }

        if (lexeme.pos.part_of_speech == .verb) {
            current.type.panel.children.items[SUBHEADING].visible = .visible;
            if (lexeme.pos.mood == .imperative) {
                try setTableRow(display, items[ROW1], "", table.*.top[0]);
                try setTableRow(display, items[ROW2], "", table.*.top[1]);
                try setTableRow(display, items[ROW3], "", table.*.bottom[0]);
                try setTableRow(display, items[ROW4], "", table.*.bottom[1]);
            } else {
                current.type.panel.children.items[SPACE3].visible = .visible;
                current.type.panel.children.items[SPACE4].visible = .hidden;
                try setTableRow(display, items[ROW1], "", table.*.top[0]);
                try setTableRow(display, items[ROW2], "", table.*.top[1]);
                try setTableRow(display, items[ROW3], "", table.*.top[2]);
                try setTableRow(display, items[ROW4], "", table.*.bottom[0]);
                try setTableRow(display, items[ROW5], "", table.*.bottom[1]);
                try setTableRow(display, items[ROW6], "", table.*.bottom[2]);
            }
        } else if (lexeme.pos.part_of_speech == .noun or lexeme.pos.part_of_speech == .adjective or lexeme.uid == 17770 or (lexeme.pos.part_of_speech == .proper_noun and !lexeme.pos.indeclinable)) {
            items[SUBHEADING].visible = .hidden;
            items[SPACE3].visible = .hidden;
            items[SPACE4].visible = .visible;
            if (table.*.gender == .masculine) {
                try setTableRow(display, items[ROW1], "ὁ", table.*.top[0]);
                if (uk) {
                    try setTableRow(display, items[ROW2], "τὸν", table.*.top[3]);
                    try setTableRow(display, items[ROW3], "τοῦ", table.*.top[1]);
                    try setTableRow(display, items[ROW4], "τῷ", table.*.top[2]);
                } else {
                    try setTableRow(display, items[ROW2], "τοῦ", table.*.top[1]);
                    try setTableRow(display, items[ROW3], "τῷ", table.*.top[2]);
                    try setTableRow(display, items[ROW4], "τὸν", table.*.top[3]);
                }

                try setTableRow(display, items[ROW5], "οἱ", table.*.bottom[0]);
                if (uk) {
                    try setTableRow(display, items[ROW6], "τούς", table.*.bottom[3]);
                    try setTableRow(display, items[ROW7], "τῶν", table.*.bottom[1]);
                    try setTableRow(display, items[ROW8], "τοῖς", table.*.bottom[2]);
                } else {
                    try setTableRow(display, items[ROW6], "τῶν", table.*.bottom[1]);
                    try setTableRow(display, items[ROW7], "τοῖς", table.*.bottom[2]);
                    try setTableRow(display, items[ROW8], "τούς", table.*.bottom[3]);
                }
            } else if (table.*.gender == .feminine) {
                try setTableRow(display, items[ROW1], "ἡ", table.*.top[0]);
                if (uk) {
                    try setTableRow(display, items[ROW2], "τὴν", table.*.top[3]);
                    try setTableRow(display, items[ROW3], "τῆς", table.*.top[1]);
                    try setTableRow(display, items[ROW4], "τῇ", table.*.top[2]);
                } else {
                    try setTableRow(display, items[ROW2], "τῆς", table.*.top[1]);
                    try setTableRow(display, items[ROW3], "τῇ", table.*.top[2]);
                    try setTableRow(display, items[ROW4], "τὴν", table.*.top[3]);
                }

                try setTableRow(display, items[ROW5], "αἱ", table.*.bottom[0]);
                if (uk) {
                    try setTableRow(display, items[ROW6], "τάς", table.*.bottom[3]);
                    try setTableRow(display, items[ROW7], "τῶν", table.*.bottom[1]);
                    try setTableRow(display, items[ROW8], "ταῖς", table.*.bottom[2]);
                } else {
                    try setTableRow(display, items[ROW6], "τῶν", table.*.bottom[1]);
                    try setTableRow(display, items[ROW7], "ταῖς", table.*.bottom[2]);
                    try setTableRow(display, items[ROW8], "τάς", table.*.bottom[3]);
                }
            } else if (table.*.gender == .neuter) {
                try setTableRow(display, items[ROW1], "τὸ", table.*.top[0]);
                if (uk) {
                    try setTableRow(display, items[ROW2], "τὸ", table.*.top[3]);
                    try setTableRow(display, items[ROW3], "τοῦ", table.*.top[1]);
                    try setTableRow(display, items[ROW4], "τῷ", table.*.top[2]);
                } else {
                    try setTableRow(display, items[ROW2], "τοῦ", table.*.top[1]);
                    try setTableRow(display, items[ROW3], "τῷ", table.*.top[2]);
                    try setTableRow(display, items[ROW4], "τὸ", table.*.top[3]);
                }

                try setTableRow(display, items[ROW5], "τὰ", table.*.bottom[0]);
                if (uk) {
                    try setTableRow(display, items[ROW6], "τὰ", table.*.bottom[3]);
                    try setTableRow(display, items[ROW7], "τῶν", table.*.bottom[1]);
                    try setTableRow(display, items[ROW8], "τοῖς", table.*.bottom[2]);
                } else {
                    try setTableRow(display, items[ROW6], "τῶν", table.*.bottom[1]);
                    try setTableRow(display, items[ROW7], "τοῖς", table.*.bottom[2]);
                    try setTableRow(display, items[ROW8], "τὰ", table.*.bottom[3]);
                }
            } else {
                warn("Unhandled gender. {s}", .{@tagName(table.*.gender)});
            }
        } else if (lexeme.pos.part_of_speech == .personal_pronoun or lexeme.pos.part_of_speech == .demonstrative_pronoun) {
            items[SUBHEADING].visible = .hidden;
            items[SPACE3].visible = .hidden;
            items[SPACE4].visible = .hidden;
            try setTableRow(display, items[ROW1], "", table.*.top[0]);
            if (uk) {
                try setTableRow(display, items[ROW2], "", table.*.top[3]);
                try setTableRow(display, items[ROW3], "", table.*.top[1]);
                try setTableRow(display, items[ROW4], "", table.*.top[2]);
            } else {
                try setTableRow(display, items[ROW2], "", table.*.top[1]);
                try setTableRow(display, items[ROW3], "", table.*.top[2]);
                try setTableRow(display, items[ROW4], "", table.*.top[3]);
            }
        }

        i += 1;
    }

    // Hide the final unused panels
    while (i < ac.MAX_PANEL_TABLES) {
        ac.app_context.?.panel_tables[i].visible = .hidden;
        i += 1;
    }

    self.scroller.offset = .{ .x = 0, .y = 0 };
    try display.choosePanel("word.info", event);
}

fn clearTableRow(display: *Display, row: *Entity) error{OutOfMemory}!void {
    try row.type.panel.children.items[0].setText(display, "");
    try row.type.panel.children.items[1].setText(display, "");
    row.visible = .hidden;
}

fn setTableRow(
    display: *Display,
    row: *Entity,
    article: []const u8,
    form: ?*praxis.Form,
) error{OutOfMemory}!void {
    const show_article = article.len > 0;
    row.type.panel.children.items[0].visible = if (show_article) .visible else .hidden;
    try row.type.panel.children.items[0].setText(display, article);
    if (form != null) {
        try row.type.panel.children.items[1].setText(display, form.?.word);
    }
    row.visible = .visible;
}

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const warn = engine.log.warn;

const praxis = @import("praxis");
const Panels = praxis.Panels;
const Lang = praxis.Lang;

const ac = @import("App.zig");
const App = ac.App;
const SearchScreen = @import("SearchScreen.zig");
const can_practice_lexeme = @import("filter_stats.zig").can_practice_lexeme;
