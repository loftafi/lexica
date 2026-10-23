pub const FormPanel = @This();

panel: *Entity,

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
        .pad = .{ .left = 14, .right = 14, .top = 10, .bottom = 10 },
        .minimum = .{ .width = 145, .height = 90 },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "panel.heading",
        .rect = .{ .width = 135, .height = 5 },
        .minimum = .{ .width = 135, .height = engine.TextSize.pixels },
        .layout = .{ .x = .grows, .y = .shrinks },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Present",
        } },
        .pad = .{ .left = 1, .right = 1 },
    }, display);

    _ = try self.panel.add(.{
        .name = "panel.subheading",
        .rect = .{ .width = 135, .height = 7 },
        .minimum = .{ .width = 135, .height = engine.TextSize.pixels },
        .layout = .{ .x = .grows, .y = .shrinks },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Active",
        } },
        .pad = .{ .left = 1, .right = 1 },
    }, display);

    _ = try self.panel.append(
        \\panel layout grows fixed rect height=8 pad top=2 {
        \\panel background_image "white rounded rect"
        \\  layout grows fixed rect height=6
        \\  style faded image_corner_radius 14 corner_radius 3
        \\}
    , FormPanel, self, display);

    for (0..8) |i| {
        if (i == 2 or i == 3 or i == 4) {
            //_ = try display.add_spacer(parsing_panel, 7);
            _ = try self.panel.append(
                \\panel layout grows fixed rect height=8 pad top=2 {
                \\panel background_image "white rounded rect"
                \\  layout grows fixed rect height=6
                \\  style faded image_corner_radius 14 corner_radius 3
                \\ }
            , FormPanel, self, display);
        }

        const row = try self.panel.add(.{
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
    return;
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
        //std.log.info("mood={t} count={d}", .{ lexeme.pos.mood, table.count });
        current.type.panel.children.items[SUBHEADING].visible = .visible;
        if (table.count <= 2) {
            try setRowText(display, items[ROW1], "", table.top[0]);
            try setRowText(display, items[ROW2], "", table.top[1]);
            try setRowText(display, items[ROW3], "", table.bottom[0]);
            try setRowText(display, items[ROW4], "", table.bottom[1]);
            current.type.panel.children.items[SPACE2].visible = .visible;
        } else if (table.count == 3) {
            current.type.panel.children.items[SPACE3].visible = .visible;
            try setRowText(display, items[ROW1], "", table.top[0]);
            try setRowText(display, items[ROW2], "", table.top[1]);
            try setRowText(display, items[ROW3], "", table.top[2]);
            try setRowText(display, items[ROW4], "", table.bottom[0]);
            try setRowText(display, items[ROW5], "", table.bottom[1]);
            try setRowText(display, items[ROW6], "", table.bottom[2]);
        }
    } else if (lexeme.pos.part_of_speech == .noun or lexeme.pos.part_of_speech == .adjective or lexeme.uid == 17770 or (lexeme.pos.part_of_speech == .proper_noun and !lexeme.pos.indeclinable)) {
        items[SUBHEADING].visible = .hidden;
        items[SPACE4].visible = .visible;
        if (table.*.gender == .masculine) {
            try setRowText(display, items[ROW1], "ὁ", table.top[0]);
            if (uk) {
                try setRowText(display, items[ROW2], "τὸν", table.top[3]);
                try setRowText(display, items[ROW3], "τοῦ", table.top[1]);
                try setRowText(display, items[ROW4], "τῷ", table.top[2]);
            } else {
                try setRowText(display, items[ROW2], "τοῦ", table.top[1]);
                try setRowText(display, items[ROW3], "τῷ", table.top[2]);
                try setRowText(display, items[ROW4], "τὸν", table.top[3]);
            }

            try setRowText(display, items[ROW5], "οἱ", table.bottom[0]);
            if (uk) {
                try setRowText(display, items[ROW6], "τούς", table.bottom[3]);
                try setRowText(display, items[ROW7], "τῶν", table.bottom[1]);
                try setRowText(display, items[ROW8], "τοῖς", table.bottom[2]);
            } else {
                try setRowText(display, items[ROW6], "τῶν", table.bottom[1]);
                try setRowText(display, items[ROW7], "τοῖς", table.bottom[2]);
                try setRowText(display, items[ROW8], "τούς", table.bottom[3]);
            }
        } else if (table.gender == .feminine) {
            try setRowText(display, items[ROW1], "ἡ", table.top[0]);
            if (uk) {
                try setRowText(display, items[ROW2], "τὴν", table.top[3]);
                try setRowText(display, items[ROW3], "τῆς", table.top[1]);
                try setRowText(display, items[ROW4], "τῇ", table.top[2]);
            } else {
                try setRowText(display, items[ROW2], "τῆς", table.top[1]);
                try setRowText(display, items[ROW3], "τῇ", table.top[2]);
                try setRowText(display, items[ROW4], "τὴν", table.top[3]);
            }

            try setRowText(display, items[ROW5], "αἱ", table.bottom[0]);
            if (uk) {
                try setRowText(display, items[ROW6], "τάς", table.bottom[3]);
                try setRowText(display, items[ROW7], "τῶν", table.bottom[1]);
                try setRowText(display, items[ROW8], "ταῖς", table.bottom[2]);
            } else {
                try setRowText(display, items[ROW6], "τῶν", table.bottom[1]);
                try setRowText(display, items[ROW7], "ταῖς", table.bottom[2]);
                try setRowText(display, items[ROW8], "τάς", table.bottom[3]);
            }
        } else if (table.gender == .neuter) {
            try setRowText(display, items[ROW1], "τὸ", table.top[0]);
            if (uk) {
                try setRowText(display, items[ROW2], "τὸ", table.top[3]);
                try setRowText(display, items[ROW3], "τοῦ", table.top[1]);
                try setRowText(display, items[ROW4], "τῷ", table.top[2]);
            } else {
                try setRowText(display, items[ROW2], "τοῦ", table.top[1]);
                try setRowText(display, items[ROW3], "τῷ", table.top[2]);
                try setRowText(display, items[ROW4], "τὸ", table.top[3]);
            }

            try setRowText(display, items[ROW5], "τὰ", table.bottom[0]);
            if (uk) {
                try setRowText(display, items[ROW6], "τὰ", table.bottom[3]);
                try setRowText(display, items[ROW7], "τῶν", table.bottom[1]);
                try setRowText(display, items[ROW8], "τοῖς", table.bottom[2]);
            } else {
                try setRowText(display, items[ROW6], "τῶν", table.bottom[1]);
                try setRowText(display, items[ROW7], "τοῖς", table.bottom[2]);
                try setRowText(display, items[ROW8], "τὰ", table.bottom[3]);
            }
        } else {
            warn("Unhandled gender. {s}", .{@tagName(table.gender)});
        }
    } else if (lexeme.pos.part_of_speech == .personal_pronoun or lexeme.pos.part_of_speech == .demonstrative_pronoun) {
        items[SUBHEADING].visible = .hidden;
        try setRowText(display, items[ROW1], "", table.top[0]);
        if (uk) {
            try setRowText(display, items[ROW2], "", table.top[3]);
            try setRowText(display, items[ROW3], "", table.top[1]);
            try setRowText(display, items[ROW4], "", table.top[2]);
        } else {
            try setRowText(display, items[ROW2], "", table.top[1]);
            try setRowText(display, items[ROW3], "", table.top[2]);
            try setRowText(display, items[ROW4], "", table.top[3]);
        }
    }
}

fn clearRow(display: *Display, row: *Entity) error{OutOfMemory}!void {
    try row.type.panel.children.items[0].setText(display, "");
    try row.type.panel.children.items[1].setText(display, "");
    row.visible = .hidden;
}

fn setRowText(
    display: *Display,
    row: *Entity,
    article: []const u8,
    form: ?*praxis.Form,
) error{OutOfMemory}!void {
    const show_article = article.len > 0;
    row.type.panel.children.items[0].minimum.height = engine.TextSize.pixels + 4;
    row.type.panel.children.items[1].minimum.height = engine.TextSize.pixels + 4;

    row.type.panel.children.items[0].visible = if (show_article) .visible else .hidden;
    try row.type.panel.children.items[0].setText(display, article);
    if (form != null) {
        try row.type.panel.children.items[1].setText(display, form.?.word);
    }
    row.visible = .visible;
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
