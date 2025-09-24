//! Setup the word information panel. This shows all information
//! about a word.

var panel: *Element = undefined;
var scroller: *Element = undefined;
var back_button: *Element = undefined;
var practice_button: *Element = undefined;

var word_pos: *Element = undefined;
var word_strongs: *Element = undefined;
var word_tags: *Element = undefined;
var word_articles: *Element = undefined;
var word_title: *Element = undefined;
var word_glosses: *Element = undefined;
var word_transliteration: *Element = undefined;

var row_pos: *Element = undefined;
var row_tags: *Element = undefined;
var row_strongs: *Element = undefined;
var row_articles: *Element = undefined;

const ICON_PAD = 30;
const FIELD_LABEL_WIDTH = 410;
const FIELD_WIDTH = 410;

var string_buffers: [2][praxis.MAX_WORD_SIZE * 2]u8 = undefined;
var string_buffers_i: usize = 0;
var strongs_buffer: ArrayList(u8) = undefined;
var gloss_buffer: ArrayList(u8) = undefined;
var tags_buffer: ArrayList(u8) = undefined;

pub fn init(context: *AppContext) !void {
    var display = context.display;
    const allocator = context.allocator;

    gloss_buffer = ArrayList(u8).init(display.allocator);
    strongs_buffer = ArrayList(u8).init(display.allocator);
    tags_buffer = ArrayList(u8).init(display.allocator);
    string_buffers_i = 0;

    panel = try display.root.add(allocator, try engine.create_panel(
        allocator,
        display,
        .{
            .name = "word.info",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre },
            .visible = .hidden,
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .type = .{ .panel = .{
                .direction = .top_to_bottom,
                .spacing = 5,
            } },
            .on_resized = handle_resize,
        },
    ));

    back_button = try display.add_back_button(allocator, panel, SearchScreen.show);

    _ = try display.add_spacer(allocator, panel, 20);

    word_title = try panel.add_alloc(allocator, display, .{
        .name = "word",
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows },
        .type = .{ .label = .{
            .text = "ἄρτος",
            .text_size = .heading,
            .text_colour = .tinted,
        } },
        .pad = .{ .top = 30, .bottom = 5 },
    });

    word_transliteration = try panel.add_alloc(allocator, display, .{
        .name = "transliteration",
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows },
        .type = .{ .label = .{
            .text = "artos",
            .text_size = .normal,
            .text_colour = .normal,
        } },
        .pad = .{ .top = 0, .left = 0.001 },
    });

    word_glosses = try panel.add_alloc(allocator, display, .{
        .name = "glosses",
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .label = .{
            .text = "Bread, food.",
            .text_size = .normal,
            .text_colour = .normal,
        } },
        .pad = .{ .top = 36, .bottom = 36 },
    });

    _ = try panel.add_alloc(allocator, display, .{
        .name = "spacer",
        .minimum = .{ .width = 20, .height = 20 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .panel = .{} },
    });

    row_pos = try panel.add_alloc(allocator, display, .{
        .name = "row_pos",
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .minimum = .{ .width = 500, .height = 40 },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 20 } },
    });

    _ = try row_pos.add_alloc(allocator, display, .{
        .name = "pos_label",
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 80 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "Part of Speech",
                .text_size = .normal,
                .text_colour = .emphasised,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    word_pos = try row_pos.add_alloc(allocator, display, .{
        .name = "pos",
        .rect = .{ .width = FIELD_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "Verb",
                .text_size = .normal,
                .text_colour = .normal,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    row_strongs = try panel.add_alloc(allocator, display, .{
        .name = "row_strongs",
        .rect = .{ .width = 20, .height = 40 },
        .minimum = .{ .width = 200, .height = 40 },
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 20 } },
    });

    _ = try row_strongs.add_alloc(allocator, display, .{
        .name = "strongs_label",
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "Strongs",
                .text_size = .normal,
                .text_colour = .emphasised,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    word_strongs = try row_strongs.add_alloc(allocator, display, .{
        .name = "strongs",
        .rect = .{ .width = FIELD_WIDTH, .height = 80 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "",
                .text_size = .normal,
                .text_colour = .normal,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    row_articles = try panel.add_alloc(allocator, display, .{
        .name = "row_articles",
        .child_align = .{ .x = .centre },
        .minimum = .{ .width = 20, .height = 40 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 20 } },
    });

    _ = try row_articles.add_alloc(allocator, display, .{
        .name = "articles_label",
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "Articles",
                .text_size = .normal,
                .text_colour = .emphasised,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    word_articles = try row_articles.add_alloc(allocator, display, .{
        .name = "articles",
        .rect = .{ .width = FIELD_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "---",
                .text_size = .normal,
                .text_colour = .normal,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    row_tags = try panel.add_alloc(allocator, display, .{
        .name = "row_tags",
        .rect = .{ .width = 20, .height = 40 },
        .minimum = .{ .width = 200, .height = 40 },
        .child_align = .{ .x = .centre },
        .layout = .{ .x = .grows, .y = .shrinks },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 20 } },
    });

    _ = try row_tags.add_alloc(allocator, display, .{
        .name = "tags_label",
        .rect = .{ .width = FIELD_LABEL_WIDTH, .height = 40 },
        .minimum = .{ .width = FIELD_LABEL_WIDTH },
        .child_align = .{ .x = .end },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "Tags",
                .text_size = .normal,
                .text_colour = .emphasised,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    word_tags = try row_tags.add_alloc(allocator, display, .{
        .name = "tags",
        .rect = .{ .width = FIELD_WIDTH, .height = 80 },
        .minimum = .{ .width = FIELD_WIDTH },
        .child_align = .{ .x = .start },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .label = .{
                .text = "",
                .text_size = .normal,
                .text_colour = .normal,
            },
        },
        .pad = .{ .top = 0, .left = 0, .right = 0.001, .bottom = 0 },
    });

    _ = try display.add_spacer(allocator, panel, 10);

    _ = try panel.add_alloc(allocator, display, .{
        .name = "top.expander",
        .rect = .{ .x = 0, .y = 0, .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    });

    scroller = try panel.add_alloc(allocator, display, .{
        .name = "parsing_table_panels",
        .rect = .{ .width = 600, .height = 300 },
        .minimum = .{ .width = 600, .height = 300 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .pad = .{ .left = 40, .right = 40 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 25,
            .scrollable = .{
                .scroll = .{ .x = true, .y = false },
                .size = .{ .width = 600, .height = 300 },
            },
        } },
    });

    for (0..ac.MAX_PANEL_TABLES) |i| {
        const parsing_panel = try create_panel_table(allocator, display, scroller);
        ac.app_context.?.panel_tables[i] = parsing_panel;
    }

    _ = try display.add_spacer(allocator, panel, 10);

    _ = try panel.add_alloc(allocator, display, .{
        .name = "middle.expander",
        .rect = .{ .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    });

    var button_align = try panel.add_alloc(allocator, display, .{
        .name = "parsing.button.align",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 30, .right = 30, .top = 8, .bottom = 8 },
        .minimum = .{ .width = 500, .height = 20 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 26,
        } },
    });

    practice_button = try button_align.add_alloc(allocator, display, .{
        .name = "start.button",
        .pad = .{ .left = 30, .right = 30, .top = 30, .bottom = 30 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{
            .button = .{
                .icon_default_name = "parsing button",
                .icon_hover_name = "parsing button",
                .icon_pressed_name = "parsing button",
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
                .text = "Practice",
                .on_click = show_parsing_setup,
                .spacing = 20,
            },
        },
    });

    _ = try panel.add_alloc(allocator, display, .{
        .name = "bottom.expander",
        .rect = .{ .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    });

    _ = try display.add_spacer(allocator, panel, 80);
}

pub fn deinit() void {
    gloss_buffer.deinit();
    strongs_buffer.deinit();
    tags_buffer.deinit();
}

/// Handle tap on the "Practice" button.
pub fn show_parsing_setup(display: *Display, _: *Element) error{OutOfMemory}!void {
    try ParsingSetupScreen.study_by_form(display, ac.app_context.?.word_lexeme.?, ac.Screen.word_info);
}

pub fn handle_resize(display: *Display, _: *Element) bool {
    var updated = false;

    const size = display.text_height * display.scale * engine.TextSize.normal.height();
    const height = size + (ICON_PAD * 2);
    if (practice_button.type.button.icon_size.x != size) {
        practice_button.type.button.icon_size.x = size;
        practice_button.type.button.icon_size.y = size;
        practice_button.minimum.width = height;
        practice_button.rect.height = height;
        practice_button.minimum.height = height;
        updated = true;
    }

    scroller.maximum.width = display.root.rect.width - 20;
    return updated;
}

pub fn create_panel_table(allocator: Allocator, display: *Display, parent_panel: *Element) !*Element {
    var parsing_panel = try engine.create_panel(
        allocator,
        display,
        .{
            .name = "present",
            .background_texture_name = "white rounded rect",
            .rect = .{ .x = 0, .y = 0, .width = 290, .height = 260 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 28, .right = 28, .top = 20, .bottom = 20 },
            .minimum = .{ .width = 290, .height = 260 },
            .type = .{ .panel = .{
                .direction = .top_to_bottom,
            } },
        },
    );
    try parent_panel.add_element(allocator, parsing_panel);

    try parsing_panel.add_element(allocator, try engine.create_label(
        allocator,
        display,
        .{
            .name = "panel.heading",
            .rect = .{ .width = 270, .height = 10 },
            .minimum = .{ .width = 270, .height = 15 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .label = .{
                .text = "Present",
                .text_colour = .tinted,
            } },
            .pad = .{ .left = 2, .right = 2, .top = 0, .bottom = 0 },
        },
    ));

    const panel_subheading = try engine.create_label(
        allocator,
        display,
        .{
            .name = "panel.subheading",
            .rect = .{ .width = 270, .height = 15 },
            .minimum = .{ .width = 270, .height = 15 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .label = .{
                .text = "Active",
                .text_colour = .tinted,
            } },
            .pad = .{ .left = 2, .right = 2, .top = 0, .bottom = 0 },
        },
    );
    try parsing_panel.add_element(allocator, panel_subheading);

    _ = try display.add_spacer(allocator, parsing_panel, 15);

    for (0..8) |i| {
        if (i == 3 or i == 4) {
            _ = try display.add_spacer(allocator, parsing_panel, 15);
        }

        const row = try engine.create_panel(allocator, display, .{
            .name = "row",
            .rect = .{ .width = 150, .height = 10 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .minimum = .{ .width = 80, .height = 10 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 15,
            } },
        });
        try parsing_panel.add_element(allocator, row);

        const article = try engine.create_label(
            allocator,
            display,
            .{
                .name = "col.article",
                .rect = .{ .width = 70, .height = 10 },
                .minimum = .{ .width = 90, .height = 10 },
                .type = .{ .label = .{
                    .text = "τὸν",
                } },
                .child_align = .{ .x = .end },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .pad = .{
                    .left = 2,
                    .right = 2,
                    .top = display.text_height * 0.15,
                    .bottom = display.text_height * 0.15,
                },
            },
        );
        try row.add_element(allocator, article);

        const form_entry = try engine.create_label(
            allocator,
            display,
            .{
                .name = "col.form",
                .rect = .{ .width = 150, .height = 0 },
                .minimum = .{ .width = 150, .height = 0 },
                .type = .{ .label = .{
                    .text = "ἄρτος",
                } },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .pad = .{
                    .left = 0,
                    .right = 0,
                    .top = display.text_height * 0.15,
                    .bottom = display.text_height * 0.15,
                },
            },
        );
        try row.add_element(allocator, form_entry);
    }
    return parsing_panel;
}

pub fn show(display: *Display, lexeme: *praxis.Lexeme) Allocator.Error!void {
    const allocator = ac.app_context.?.allocator;

    ac.app_context.?.word_lexeme = lexeme;
    try word_title.set_text(allocator, display, lexeme.word, false);

    const pos = praxis.pos_to_english(lexeme.pos);
    try word_pos.set_text(allocator, display, pos, false);

    gloss_buffer.clearRetainingCapacity();
    try word_glosses.set_text(allocator, display, "", false);
    if (lexeme.glosses_by_lang(Lang.english)) |value| {
        try value.string(gloss_buffer.writer());
    }
    try word_glosses.set_text(allocator, display, gloss_buffer.items, false);

    string_buffers_i += 1;
    if (string_buffers_i >= string_buffers.len) {
        string_buffers_i = 0;
    }
    const transliterated = praxis.transliterate(lexeme.word, true, &string_buffers[string_buffers_i]) catch "";
    try word_transliteration.set_text(allocator, display, transliterated, false);

    const uk = ac.app_context.?.preference.uk_order;

    practice_button.visible = if (can_practice_lexeme(lexeme)) .visible else .hidden;

    row_strongs.visible = .hidden;
    if (ac.app_context.?.preference.show_strongs and lexeme.strongs.items.len > 0) {
        try word_strongs.set_text(allocator, display, "", false);
        strongs_buffer.clearRetainingCapacity();
        row_strongs.visible = .visible;
        for (lexeme.strongs.items, 0..) |strongs, i| {
            if (i > 0) {
                try strongs_buffer.appendSlice(", ");
            }
            strongs_buffer.writer().print("{d}", .{strongs}) catch {
                return Allocator.Error.OutOfMemory;
            };
        }
        try word_strongs.set_text(allocator, display, strongs_buffer.items, false);
    }

    row_tags.visible = .hidden;
    if (lexeme.tags) |tags| {
        if (tags.len > 0) {
            try word_tags.set_text(allocator, display, "", false);
            tags_buffer.clearRetainingCapacity();
            row_tags.visible = .visible;
            for (tags, 0..) |tag, i| {
                if (i > 0) {
                    try tags_buffer.appendSlice(", ");
                }
                tags_buffer.appendSlice(tag) catch {
                    return Allocator.Error.OutOfMemory;
                };
            }
            try word_tags.set_text(allocator, display, tags_buffer.items, false);
        }
    }

    switch (lexeme.article) {
        .masculine => {
            row_articles.visible = .visible;
            try word_articles.set_text(allocator, display, "ὁ", false);
        },
        .feminine => {
            row_articles.visible = .visible;
            try word_articles.set_text(allocator, display, "ἡ", false);
        },
        .neuter => {
            row_articles.visible = .visible;
            try word_articles.set_text(allocator, display, "τό", false);
        },
        .masculine_feminine => {
            row_articles.visible = .visible;
            try word_articles.set_text(allocator, display, "ὁ ἡ", false);
        },
        .masculine_neuter => {
            row_articles.visible = .visible;
            try word_articles.set_text(allocator, display, "ὁ τό", false);
        },
        else => row_articles.visible = .hidden,
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
    const panels = try ac.app_context.?.panels.panels();
    var i: usize = 0;
    for (panels) |*table| {
        if (i >= ac.MAX_PANEL_TABLES) {
            break;
        }
        var current = ac.app_context.?.panel_tables[i];
        var items = current.type.panel.children.items;
        current.visible = .visible;
        try items[HEADING].set_text(allocator, display, table.*.title, false);
        try items[SUBHEADING].set_text(allocator, display, table.*.subtitle, false);

        {
            // Clear the panel
            try clear_row(display, items[ROW1]);
            try clear_row(display, items[ROW2]);
            try clear_row(display, items[ROW3]);
            try clear_row(display, items[ROW4]);
            try clear_row(display, items[ROW5]);
            try clear_row(display, items[ROW6]);
            try clear_row(display, items[ROW7]);
            try clear_row(display, items[ROW8]);
        }

        if (lexeme.pos.part_of_speech == .verb) {
            current.type.panel.children.items[SUBHEADING].visible = .visible;
            if (lexeme.pos.mood == .imperative) {
                try set_row(display, items[ROW1], "", table.*.top[0]);
                try set_row(display, items[ROW2], "", table.*.top[1]);
                try set_row(display, items[ROW3], "", table.*.bottom[0]);
                try set_row(display, items[ROW4], "", table.*.bottom[1]);
            } else {
                current.type.panel.children.items[SPACE3].visible = .visible;
                current.type.panel.children.items[SPACE4].visible = .hidden;
                try set_row(display, items[ROW1], "", table.*.top[0]);
                try set_row(display, items[ROW2], "", table.*.top[1]);
                try set_row(display, items[ROW3], "", table.*.top[2]);
                try set_row(display, items[ROW4], "", table.*.bottom[0]);
                try set_row(display, items[ROW5], "", table.*.bottom[1]);
                try set_row(display, items[ROW6], "", table.*.bottom[2]);
            }
        } else if (lexeme.pos.part_of_speech == .noun or lexeme.pos.part_of_speech == .adjective or lexeme.uid == 17770 or (lexeme.pos.part_of_speech == .proper_noun and !lexeme.pos.indeclinable)) {
            items[SUBHEADING].visible = .hidden;
            items[SPACE3].visible = .hidden;
            items[SPACE4].visible = .visible;
            if (table.*.gender == .masculine) {
                try set_row(display, items[ROW1], "ὁ", table.*.top[0]);
                if (uk) {
                    try set_row(display, items[ROW2], "τὸν", table.*.top[3]);
                    try set_row(display, items[ROW3], "τοῦ", table.*.top[1]);
                    try set_row(display, items[ROW4], "τῷ", table.*.top[2]);
                } else {
                    try set_row(display, items[ROW2], "τοῦ", table.*.top[1]);
                    try set_row(display, items[ROW3], "τῷ", table.*.top[2]);
                    try set_row(display, items[ROW4], "τὸν", table.*.top[3]);
                }

                try set_row(display, items[ROW5], "οἱ", table.*.bottom[0]);
                if (uk) {
                    try set_row(display, items[ROW6], "τούς", table.*.bottom[3]);
                    try set_row(display, items[ROW7], "τῶν", table.*.bottom[1]);
                    try set_row(display, items[ROW8], "τοῖς", table.*.bottom[2]);
                } else {
                    try set_row(display, items[ROW6], "τῶν", table.*.bottom[1]);
                    try set_row(display, items[ROW7], "τοῖς", table.*.bottom[2]);
                    try set_row(display, items[ROW8], "τούς", table.*.bottom[3]);
                }
            } else if (table.*.gender == .feminine) {
                try set_row(display, items[ROW1], "ἡ", table.*.top[0]);
                if (uk) {
                    try set_row(display, items[ROW2], "τὴν", table.*.top[3]);
                    try set_row(display, items[ROW3], "τῆς", table.*.top[1]);
                    try set_row(display, items[ROW4], "τῇ", table.*.top[2]);
                } else {
                    try set_row(display, items[ROW2], "τῆς", table.*.top[1]);
                    try set_row(display, items[ROW3], "τῇ", table.*.top[2]);
                    try set_row(display, items[ROW4], "τὴν", table.*.top[3]);
                }

                try set_row(display, items[ROW5], "αἱ", table.*.bottom[0]);
                if (uk) {
                    try set_row(display, items[ROW6], "τάς", table.*.bottom[3]);
                    try set_row(display, items[ROW7], "τῶν", table.*.bottom[1]);
                    try set_row(display, items[ROW8], "ταῖς", table.*.bottom[2]);
                } else {
                    try set_row(display, items[ROW6], "τῶν", table.*.bottom[1]);
                    try set_row(display, items[ROW7], "ταῖς", table.*.bottom[2]);
                    try set_row(display, items[ROW8], "τάς", table.*.bottom[3]);
                }
            } else if (table.*.gender == .neuter) {
                try set_row(display, items[ROW1], "τὸ", table.*.top[0]);
                if (uk) {
                    try set_row(display, items[ROW2], "τὸ", table.*.top[3]);
                    try set_row(display, items[ROW3], "τοῦ", table.*.top[1]);
                    try set_row(display, items[ROW4], "τῷ", table.*.top[2]);
                } else {
                    try set_row(display, items[ROW2], "τοῦ", table.*.top[1]);
                    try set_row(display, items[ROW3], "τῷ", table.*.top[2]);
                    try set_row(display, items[ROW4], "τὸ", table.*.top[3]);
                }

                try set_row(display, items[ROW5], "τὰ", table.*.bottom[0]);
                if (uk) {
                    try set_row(display, items[ROW6], "τὰ", table.*.bottom[3]);
                    try set_row(display, items[ROW7], "τῶν", table.*.bottom[1]);
                    try set_row(display, items[ROW8], "τοῖς", table.*.bottom[2]);
                } else {
                    try set_row(display, items[ROW6], "τῶν", table.*.bottom[1]);
                    try set_row(display, items[ROW7], "τοῖς", table.*.bottom[2]);
                    try set_row(display, items[ROW8], "τὰ", table.*.bottom[3]);
                }
            } else {
                warn("Unhandled gender. {s}", .{@tagName(table.*.gender)});
            }
        } else if (lexeme.pos.part_of_speech == .personal_pronoun or lexeme.pos.part_of_speech == .demonstrative_pronoun) {
            items[SUBHEADING].visible = .hidden;
            items[SPACE3].visible = .hidden;
            items[SPACE4].visible = .hidden;
            try set_row(display, items[ROW1], "", table.*.top[0]);
            if (uk) {
                try set_row(display, items[ROW2], "", table.*.top[3]);
                try set_row(display, items[ROW3], "", table.*.top[1]);
                try set_row(display, items[ROW4], "", table.*.top[2]);
            } else {
                try set_row(display, items[ROW2], "", table.*.top[1]);
                try set_row(display, items[ROW3], "", table.*.top[2]);
                try set_row(display, items[ROW4], "", table.*.top[3]);
            }
        }

        i += 1;
    }

    // Hide the final unused panels
    while (i < ac.MAX_PANEL_TABLES) {
        ac.app_context.?.panel_tables[i].visible = .hidden;
        i += 1;
    }

    scroller.offset = .{ .x = 0, .y = 0 };
    display.choose_panel("word.info");
}

/// Clear row contents
fn clear_row(display: *Display, row: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    try row.type.panel.children.items[0].set_text(allocator, display, "", false);
    try row.type.panel.children.items[1].set_text(allocator, display, "", false);
    row.visible = .hidden;
}

/// Set row contents
fn set_row(display: *Display, row: *Element, article: []const u8, form: ?*praxis.Form) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    const show_article = article.len > 0;
    row.type.panel.children.items[0].visible = if (show_article) .visible else .hidden;
    try row.type.panel.children.items[0].set_text(allocator, display, article, false);
    if (form != null) {
        try row.type.panel.children.items[1].set_text(allocator, display, form.?.word, false);
    }
    row.visible = .visible;
}

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const engine = @import("engine");
const Display = engine.Display;
const Element = engine.Element;
const warn = engine.warn;
const praxis = @import("praxis");
const Panels = praxis.Panels;
const Lang = praxis.Lang;
const ParsingSetupScreen = @import("screen_parsing_setup.zig");
const SearchScreen = @import("screen_search.zig");
const MenuUI = @import("menu_ui.zig");
const can_practice_lexeme = @import("filter_stats.zig").can_practice_lexeme;
