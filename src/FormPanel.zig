pub const FormPanel = @This();

panel: *Entity,
divider: *Entity,

pub fn init(
    self: *FormPanel,
    display: *Display,
    parent_panel: *Entity,
) (engine.Error || Allocator.Error || Resources.Error)!void {
    self.panel = try parent_panel.add(.{
        .name = "form.panel",
        .background = .{
            .image_name = "white rounded rect",
            .image_corner_radius = 14,
        },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .minimum = .{ .width = 145, .height = 90 },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "panel.heading",
        .pad = .{ .left = 4, .right = 4 },
        .rect = .{ .width = 135, .height = 5 },
        .minimum = .{ .width = 80, .height = engine.TextSize.pixels },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Present",
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "panel.subheading",
        .rect = .{ .width = 135, .height = 7 },
        .pad = .{ .left = 4, .right = 4 },
        .minimum = .{ .width = 80, .height = engine.TextSize.pixels },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Active",
        } },
    }, display);

    _ = try self.panel.append(
        \\panel:divider layout grows fixed rect height=8 pad top=2 left=4 right=4 {
        \\panel background_image "white rounded rect"
        \\  layout grows fixed rect height=6
        \\  style faded image_corner_radius 12 corner_radius 3
        \\}
    , FormPanel, self, display);

    for (0..8) |i| {
        if (i == 2 or i == 3 or i == 4) {
            //_ = try display.add_spacer(parsing_panel, 7);
            _ = try self.panel.append(
                \\panel layout grows fixed rect height=8 pad top=2 left=4 right=4 {
                \\panel background_image "white rounded rect"
                \\  layout grows fixed rect height=6
                \\  style faded image_corner_radius 12 corner_radius 3
                \\ }
            , FormPanel, self, display);
        }

        const row = try self.panel.add(.{
            .name = "row",
            .rect = .{ .width = 75, .height = 5 },
            .background = .{
                .corner_radius = 8,
                .image_corner_radius = 14,
            },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .minimum = .{ .width = 40, .height = 5 },
            .pad = .{ .left = 4, .right = 4 },
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

        _ = try row.add(.{
            .name = "col.label",
            .rect = .{ .width = 35, .height = 5 },
            .minimum = .{ .width = 35, .height = 5 },
            .style = .tinted,
            .type = .{ .label = .{
                .text = "pres. act.",
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
    }
}

const HEADING = 0;
const SUBHEADING = 1;
const ROW1 = 3;
const ROW2 = 4;
const SPACE2 = 5;
const ROW3 = 6;
const SPACE3 = 7;
const ROW4 = 8;
const SPACE4 = 9;
const ROW5 = 10;
const ROW6 = 11;
const ROW7 = 12;
const ROW8 = 13;

pub fn setup(
    self: *FormPanel,
    display: *Display,
    table: *Panel,
    lexeme: *Lexeme,
    highlight: ?*Form,
    uk: bool,
) Allocator.Error!void {
    var current = self.panel;
    var items = current.type.panel.children.items;
    current.visible = .visible;
    try items[HEADING].setText(display, table.title);
    try items[SUBHEADING].setText(display, table.subtitle);

    // Clear the panel
    try clearRow(display, items[ROW1]);
    try clearRow(display, items[ROW2]);
    try clearRow(display, items[ROW3]);
    try clearRow(display, items[ROW4]);
    try clearRow(display, items[ROW5]);
    try clearRow(display, items[ROW6]);
    try clearRow(display, items[ROW7]);
    try clearRow(display, items[ROW8]);
    current.type.panel.children.items[SPACE2].visible = .hidden;
    current.type.panel.children.items[SPACE3].visible = .hidden;
    current.type.panel.children.items[SPACE4].visible = .hidden;

    if (lexeme.pos.part_of_speech == .verb) {
        current.type.panel.children.items[SUBHEADING].visible = .visible;
        if (table.count <= 2) {
            try setRowText(display, items[ROW1], "", table.top[0], table.top_label[0], highlight);
            try setRowText(display, items[ROW2], "", table.top[1], table.top_label[1], highlight);
            try setRowText(display, items[ROW3], "", table.bottom[0], table.bottom_label[0], highlight);
            try setRowText(display, items[ROW4], "", table.bottom[1], table.bottom_label[1], highlight);
            current.type.panel.children.items[SPACE2].visible = .visible;
        } else if (table.count == 3) {
            current.type.panel.children.items[SPACE3].visible = .visible;
            try setRowText(display, items[ROW1], "", table.top[0], table.top_label[0], highlight);
            try setRowText(display, items[ROW2], "", table.top[1], table.top_label[1], highlight);
            try setRowText(display, items[ROW3], "", table.top[2], table.top_label[2], highlight);
            try setRowText(display, items[ROW4], "", table.bottom[0], table.bottom_label[0], highlight);
            try setRowText(display, items[ROW5], "", table.bottom[1], table.bottom_label[1], highlight);
            try setRowText(display, items[ROW6], "", table.bottom[2], table.bottom_label[2], highlight);
        }
    } else if (lexeme.pos.part_of_speech == .noun or lexeme.pos.part_of_speech == .adjective or lexeme.uid == 17770 or (lexeme.pos.part_of_speech == .proper_noun and !lexeme.pos.indeclinable)) {
        items[SUBHEADING].visible = .hidden;
        items[SPACE4].visible = .visible;
        if (table.*.gender == .masculine) {
            try setRowText(display, items[ROW1], "ὁ", table.top[0], table.top_label[0], highlight);
            if (uk) {
                try setRowText(display, items[ROW2], "τὸν", table.top[3], table.top_label[3], highlight);
                try setRowText(display, items[ROW3], "τοῦ", table.top[1], table.top_label[1], highlight);
                try setRowText(display, items[ROW4], "τῷ", table.top[2], table.top_label[2], highlight);
            } else {
                try setRowText(display, items[ROW2], "τοῦ", table.top[1], table.top_label[1], highlight);
                try setRowText(display, items[ROW3], "τῷ", table.top[2], table.top_label[2], highlight);
                try setRowText(display, items[ROW4], "τὸν", table.top[3], table.top_label[3], highlight);
            }

            try setRowText(display, items[ROW5], "οἱ", table.bottom[0], table.bottom_label[0], highlight);
            if (uk) {
                try setRowText(display, items[ROW6], "τούς", table.bottom[3], table.bottom_label[3], highlight);
                try setRowText(display, items[ROW7], "τῶν", table.bottom[1], table.bottom_label[1], highlight);
                try setRowText(display, items[ROW8], "τοῖς", table.bottom[2], table.bottom_label[2], highlight);
            } else {
                try setRowText(display, items[ROW6], "τῶν", table.bottom[1], table.bottom_label[1], highlight);
                try setRowText(display, items[ROW7], "τοῖς", table.bottom[2], table.bottom_label[2], highlight);
                try setRowText(display, items[ROW8], "τούς", table.bottom[3], table.bottom_label[3], highlight);
            }
        } else if (table.gender == .feminine) {
            try setRowText(display, items[ROW1], "ἡ", table.top[0], table.top_label[0], highlight);
            if (uk) {
                try setRowText(display, items[ROW2], "τὴν", table.top[3], table.top_label[3], highlight);
                try setRowText(display, items[ROW3], "τῆς", table.top[1], table.top_label[1], highlight);
                try setRowText(display, items[ROW4], "τῇ", table.top[2], table.top_label[2], highlight);
            } else {
                try setRowText(display, items[ROW2], "τῆς", table.top[1], table.top_label[1], highlight);
                try setRowText(display, items[ROW3], "τῇ", table.top[2], table.top_label[2], highlight);
                try setRowText(display, items[ROW4], "τὴν", table.top[3], table.top_label[3], highlight);
            }

            try setRowText(display, items[ROW5], "αἱ", table.bottom[0], table.bottom_label[0], highlight);
            if (uk) {
                try setRowText(display, items[ROW6], "τάς", table.bottom[3], table.bottom_label[3], highlight);
                try setRowText(display, items[ROW7], "τῶν", table.bottom[1], table.bottom_label[1], highlight);
                try setRowText(display, items[ROW8], "ταῖς", table.bottom[2], table.bottom_label[2], highlight);
            } else {
                try setRowText(display, items[ROW6], "τῶν", table.bottom[1], table.bottom_label[1], highlight);
                try setRowText(display, items[ROW7], "ταῖς", table.bottom[2], table.bottom_label[2], highlight);
                try setRowText(display, items[ROW8], "τάς", table.bottom[3], table.bottom_label[3], highlight);
            }
        } else if (table.gender == .neuter) {
            try setRowText(display, items[ROW1], "τὸ", table.top[0], table.top_label[0], highlight);
            if (uk) {
                try setRowText(display, items[ROW2], "τὸ", table.top[3], table.top_label[3], highlight);
                try setRowText(display, items[ROW3], "τοῦ", table.top[1], table.top_label[1], highlight);
                try setRowText(display, items[ROW4], "τῷ", table.top[2], table.top_label[2], highlight);
            } else {
                try setRowText(display, items[ROW2], "τοῦ", table.top[1], table.top_label[1], highlight);
                try setRowText(display, items[ROW3], "τῷ", table.top[2], table.top_label[2], highlight);
                try setRowText(display, items[ROW4], "τὸ", table.top[3], table.top_label[3], highlight);
            }

            try setRowText(display, items[ROW5], "τὰ", table.bottom[0], table.bottom_label[0], highlight);
            if (uk) {
                try setRowText(display, items[ROW6], "τὰ", table.bottom[3], table.bottom_label[3], highlight);
                try setRowText(display, items[ROW7], "τῶν", table.bottom[1], table.bottom_label[1], highlight);
                try setRowText(display, items[ROW8], "τοῖς", table.bottom[2], table.bottom_label[2], highlight);
            } else {
                try setRowText(display, items[ROW6], "τῶν", table.bottom[1], table.bottom_label[1], highlight);
                try setRowText(display, items[ROW7], "τοῖς", table.bottom[2], table.bottom_label[2], highlight);
                try setRowText(display, items[ROW8], "τὰ", table.bottom[3], table.bottom_label[3], highlight);
            }
        } else {
            warn("Unhandled gender. {s}", .{@tagName(table.gender)});
        }
    } else if (lexeme.pos.part_of_speech == .personal_pronoun or lexeme.pos.part_of_speech == .demonstrative_pronoun) {
        items[SUBHEADING].visible = .hidden;
        try setRowText(display, items[ROW1], "", table.top[0], table.top_label[0], highlight);
        if (uk) {
            try setRowText(display, items[ROW2], "", table.top[3], table.top_label[3], highlight);
            try setRowText(display, items[ROW3], "", table.top[1], table.top_label[1], highlight);
            try setRowText(display, items[ROW4], "", table.top[2], table.top_label[2], highlight);
        } else {
            try setRowText(display, items[ROW2], "", table.top[1], table.top_label[1], highlight);
            try setRowText(display, items[ROW3], "", table.top[2], table.top_label[2], highlight);
            try setRowText(display, items[ROW4], "", table.top[3], table.top_label[3], highlight);
        }
    }
    self.calculateSizes(display);
}

/// Set the width of each column such that each column aligns
/// with the column below it.
fn calculateSizes(self: *FormPanel, _: *Display) void {
    var article_width: f32 = 0;
    var text_width: f32 = 60;
    var label_width: f32 = 0;
    var inner_width: f32 = 30;

    self.panel.type.panel.children.items[HEADING].minimum.width = 0;
    self.panel.type.panel.children.items[SUBHEADING].minimum.width = 0;
    const heading_width = @max(article_width, self.panel.type.panel.children.items[HEADING].minimumNeededWidth(1000));
    const subheading_width = @max(article_width, self.panel.type.panel.children.items[SUBHEADING].minimumNeededWidth(1000));

    // Find the maximum width of each column.
    for (&[8]usize{ ROW1, ROW2, ROW3, ROW4, ROW5, ROW6, ROW7, ROW8 }) |i| {
        const items = self.panel.type.panel.children.items;
        const row = items[i];
        if (row.visible == .hidden) continue;
        const article = row.type.panel.children.items[0];
        const text = row.type.panel.children.items[1];
        const label = row.type.panel.children.items[2];
        article.minimum.width = 0;
        text.minimum.width = 40;
        label.minimum.width = 0;
        article_width = @max(article_width, article.minimumNeededWidth(1000));
        text_width = @max(text_width, text.minimumNeededWidth(1000));
        label_width = @max(label_width, label.minimumNeededWidth(1000));
        var width = article_width + text_width + label_width +
            row.type.panel.spacing + row.pad.left + row.pad.right;
        if (article_width > 0) width += row.type.panel.spacing;
        inner_width = @max(inner_width, width);
    }
    // Update the width of each column.
    for (&[8]usize{ ROW1, ROW2, ROW3, ROW4, ROW5, ROW6, ROW7, ROW8 }) |i| {
        const items = self.panel.type.panel.children.items;
        const row = items[i];
        if (row.visible == .hidden) continue;
        const article = row.type.panel.children.items[0];
        const text = row.type.panel.children.items[1];
        const label = row.type.panel.children.items[2];
        article.rect.width = article_width;
        article.minimum.width = article_width;
        text.rect.width = text_width;
        text.minimum.width = text_width;
        label.rect.width = label_width;
        label.minimum.width = label_width;
        row.rect.width = inner_width;
    }
    inner_width = @max(inner_width, heading_width);
    inner_width = @max(inner_width, subheading_width);
    self.panel.type.panel.children.items[HEADING].rect.width = inner_width;
    self.panel.type.panel.children.items[HEADING].minimum.width = inner_width;
    self.panel.type.panel.children.items[SUBHEADING].rect.width = inner_width;
    self.panel.type.panel.children.items[SUBHEADING].minimum.width = inner_width;
    self.panel.rect.width = inner_width + self.panel.pad.left + self.panel.pad.right;
    self.panel.type.panel.children.items[SPACE2].rect.width = inner_width;
    self.panel.type.panel.children.items[SPACE3].rect.width = inner_width;
    self.panel.type.panel.children.items[SPACE4].rect.width = inner_width;
    self.panel.type.panel.children.items[SPACE2].maximum.width = inner_width;
    self.panel.type.panel.children.items[SPACE3].maximum.width = inner_width;
    self.panel.type.panel.children.items[SPACE4].maximum.width = inner_width;
    self.divider.maximum.width = inner_width;
    self.panel.minimum.width = inner_width + self.panel.pad.left + self.panel.pad.right;
}

fn clearRow(display: *Display, row: *Entity) error{OutOfMemory}!void {
    row.clearBackgroundImage(display) catch {};
    row.style = .normal;
    row.type.panel.children.items[0].style = .normal;
    row.type.panel.children.items[1].style = .normal;
    row.type.panel.children.items[2].style = .tinted;
    try row.type.panel.children.items[0].setText(display, "");
    try row.type.panel.children.items[1].setText(display, "");
    try row.type.panel.children.items[2].setText(display, "");
    row.visible = .hidden;
}

fn setRowText(
    display: *Display,
    row: *Entity,
    article: []const u8,
    form: ?*praxis.Form,
    label: []const u8,
    highlight: ?*Form,
) error{OutOfMemory}!void {
    const show_article = article.len > 0;
    row.type.panel.children.items[0].minimum.height = engine.TextSize.pixels + 4;
    row.type.panel.children.items[1].minimum.height = engine.TextSize.pixels + 4;
    row.type.panel.children.items[2].minimum.height = engine.TextSize.pixels + 4;

    row.type.panel.children.items[0].visible = if (show_article) .visible else .hidden;
    try row.type.panel.children.items[0].setText(display, article);
    if (form != null) {
        try row.type.panel.children.items[1].setText(display, form.?.word);
    }
    try row.type.panel.children.items[2].setText(display, label);
    row.visible = .visible;

    if (form != null and highlight != null and form.?.parsing == highlight.?.parsing) {
        _ = row.setBackgroundImage(display, &display.resources, "white rounded rect") catch |e| {
            engine.log.err("highlght form chart row failed. {t}", .{e});
            return;
        };
        row.style = .emphasised;
        row.type.panel.children.items[0].style = .emphasised;
        row.type.panel.children.items[1].style = .emphasised;
        row.type.panel.children.items[2].style = .emphasised;
    } else {
        row.type.panel.children.items[0].style = .normal;
        row.type.panel.children.items[1].style = .normal;
        row.type.panel.children.items[2].style = .tinted;
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const warn = std.log.warn;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;

const resources = @import("resources");
const Resources = resources.Resources;

const praxis = @import("praxis");
const Panel = praxis.Panels.Panel;
const Lexeme = praxis.Lexeme;
const Form = praxis.Form;
