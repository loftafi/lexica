/// Display information about an individual lexeme.
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

row_tags: *Entity = undefined,
row_strongs: *Entity = undefined,
row_articles: *Entity = undefined,

string_buffers: [2][praxis.max_word_size * 2]u8 = undefined,
string_buffers_i: usize = 0,
strongs_buffer: std.Io.Writer.Allocating = undefined,
gloss_buffer: std.Io.Writer.Allocating = undefined,
tags_buffer: std.Io.Writer.Allocating = undefined,

word_chart: WordChart = undefined,

pub fn init(
    self: *WordInfoScreen,
    app: *App,
) (engine.Error || Allocator.Error || Resources.Error)!void {
    self.app = app;
    var display = app.display;

    self.gloss_buffer = .init(display.allocator);
    self.strongs_buffer = .init(display.allocator);
    self.tags_buffer = .init(display.allocator);
    self.string_buffers_i = 0;

    _ = try display.appendPanel(
        \\panel:panel name "word.info" hidden top_left choosable
        \\  layout grows grows align start start
        \\  spacing 2 on_resized resizePanel
        \\{
        \\    panel name "header" align start start vertical layout grows shrinks
        \\    {
        \\      button:back_button name "back"
        \\        layout shrinks shrinks
        \\        pad 0.5em 0.5em 1em 1em
        \\        icon_default "icon-back"
        \\        icon_size width=1.5em height=1.5em
        \\        on_pressed tapBack
        \\    }
        \\    panel name "content" align start start vertical layout grows grows
        \\      pad bottom=2em
        \\    {
        \\      label:word_title align centre centre layout grows shrinks
        \\        style tinted text "ἄρτος" text_size heading
        \\        pad top=0.5em bottom=2
        \\      label:word_transliteration align centre centre layout grows shrinks
        \\        text "artos"
        \\        pad top=0.2em bottom=2
        \\      label:word_glosses name "glosses"
        \\        align centre centre layout grows shrinks
        \\        text "Bread, food." pad top=0.8em bottom=0.8em
        \\      panel layout fixed fixed rect width=10 height=10
        \\    panel name "row" horizontal align centre centre
        \\      layout grows shrinks spacing 0.5em {
        \\        label text "Part of Speech" style tinted
        \\            layout fixed shrinks align end centre rect width=10em
        \\        label:word_pos text "Verb"
        \\            layout fixed shrinks align start centre rect width=10em
        \\    }
        \\    panel:row_strongs name "row" horizontal align centre centre
        \\      layout grows shrinks spacing 0.5em {
        \\        label text "STRONGS" style tinted
        \\            layout fixed shrinks align end centre rect width=10em
        \\        label:word_strongs text "Verb"
        \\            layout fixed shrinks align start centre rect width=10em
        \\    }
        \\    panel:row_articles name "row" horizontal align centre centre
        \\      layout grows shrinks spacing 0.5em {
        \\        label text "ARTICLES" style tinted
        \\            layout fixed shrinks align end centre rect width=10em
        \\        label:word_articles text "--"
        \\            layout fixed shrinks align start centre rect width=10em
        \\    }
        \\    panel:row_tags name "row" horizontal align centre centre
        \\      layout grows shrinks spacing 0.5em {
        \\        label text "Tags" style tinted
        \\            layout fixed shrinks align end centre rect width=10em
        \\        label:word_tags text "--"
        \\            layout fixed shrinks align start centre rect width=10em
        \\    }
        \\      expander name "expander" weight 1
        \\      panel:scroller layout grows shrinks  scroll horizontal
        \\        horizontal align start start
        \\        pad left=1em right=1em minimum height=7em spacing 0.5em
        \\      panel name "button.align" layout grows shrinks align centre centre
        \\        pad top=1em bottom=1em
        \\      {
        \\        button:practice_button name "start.button"
        \\        pad left=0.6em right=0.6em top=0.6em bottom=0.6em
        \\        corner_radius 1em image_corner_radius 50
        \\        layout shrinks shrinks style faded
        \\        text "PRACTICE" spacing 1em on_pressed tapPracticeButton
        \\        icon_default  "parsing button"
        \\        icon_hover  "parsing button"
        \\        icon_pressed "parsing button"
        \\        button_default "button default"
        \\        button_pressed "button pressed"
        \\        button_hover  "button hover"
        \\      }
        \\      expander name "expander" weight 1
        \\    }
        \\}
    , WordInfoScreen, self);

    try self.word_chart.init(display, self.scroller);
}

pub fn deinit(self: *WordInfoScreen) void {
    self.word_chart.deinit(self.app.display);
    self.gloss_buffer.deinit();
    self.strongs_buffer.deinit();
    self.tags_buffer.deinit();
    self.word_chart.deinit(self.app.display);
    self.* = undefined;
}

/// Handle a tap on the "Practice" button.
pub fn tapBack(
    self: *WordInfoScreen,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try self.app.search_screen.show(display, entity, event);
}

/// Handle a tap on the "Practice" button.
pub fn tapPracticeButton(
    self: *WordInfoScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try self.app.parsing_setup.study_by_form(
        display,
        self.app.word_lexeme.?,
        App.Screen.word_info,
        event,
    );
}

pub fn resizePanel(
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

pub fn show(
    self: *WordInfoScreen,
    display: *Display,
    lexeme: *praxis.Lexeme,
    event: *const Event,
) Allocator.Error!void {
    self.app.word_lexeme = lexeme;
    try self.word_title.setText(display, lexeme.word);

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
    const transliterated = praxis.transliterateSyllables(lexeme.word, true, "·", &self.string_buffers[self.string_buffers_i]) catch "";
    try self.word_transliteration.setText(display, transliterated);

    self.practice_button.visible = if (can_practice_lexeme(lexeme)) .visible else .hidden;

    self.row_strongs.visible = .hidden;
    if (self.app.preference.show_strongs and lexeme.strongs.items.len > 0) {
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

    const uk = self.app.preference.uk_order;

    try self.word_chart.setup(display, uk, lexeme);
    try display.choosePanel("word.info", event);
}

pub const WordChart = struct {
    pub const max_panel_tables: usize = 20;

    chart: [max_panel_tables]FormPanel = undefined,
    panels: praxis.Panels = .empty,
    parent: *Entity = undefined,

    pub fn init(
        self: *WordChart,
        display: *Display,
        parent: *Entity,
    ) (engine.Error || Allocator.Error || Resources.Error)!void {
        self.parent = parent;
        self.panels = .empty;
        for (&self.chart) |*panel| {
            try panel.init(display, parent);
        }
    }

    pub fn deinit(self: *WordChart, display: *Display) void {
        self.panels.deinit(display.allocator);
        self.* = undefined;
    }

    pub fn setup(
        self: *WordChart,
        display: *Display,
        uk: bool,
        lexeme: *praxis.Lexeme,
    ) Allocator.Error!void {
        self.panels.setLexeme(lexeme);
        const panels = try self.panels.panels(display.allocator);
        var i: usize = 0;
        for (panels) |*table| {
            if (i >= max_panel_tables) break;
            try self.chart[i].setup(display, table, lexeme, uk);
            i += 1;
        }

        // Hide the final unused panels
        while (i < max_panel_tables) {
            self.chart[i].panel.visible = .hidden;
            i += 1;
        }

        self.parent.offset = .{ .x = 0, .y = 0 };
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const warn = engine.log.warn;

const resources = @import("resources");
const Resources = resources.Resources;

const praxis = @import("praxis");
const Lang = praxis.Lang;

const App = @import("App.zig");
const SearchScreen = @import("SearchScreen.zig");
const FormPanel = @import("FormPanel.zig");
const can_practice_lexeme = @import("filter_stats.zig").can_practice_lexeme;
