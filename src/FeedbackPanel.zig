pub const FeedbackPanel = @This();

const feedback_panel_height = 85;
const feedback_panel_pad = 7;
const feedback_button_width = 100;
const feedback_icon_width = 30;

/// Feedback slide in time in milliseconds
const slide_time = 0.15 * seconds;

const messages = [10][]const u8{
    "AFFIRM1",
    "AFFIRM2",
    "AFFIRM3",
    "AFFIRM4",
    "AFFIRM5",
    "AFFIRM6",
    "AFFIRM7",
    "AFFIRM8",
    "AFFIRM9",
    "AFFIRM10",
};

panel: *Entity,
rows: *Entity,
heading: *Entity,
text: *Entity,
button: *Entity,
flag: *Entity,
icon: *Entity,
on_feedback: Entity.Callback = .empty,
on_next: Entity.Callback = .empty,
bucket: *StringBucket,

/// Remember the event that triggered the slide in
event: Event = .{ .type = .unknown },

pub fn init(
    self: *FeedbackPanel,
    min_width: f32,
    max_width: f32,
    bucket: *engine.StringBucket,
    display: *Display,
    box: *Entity,
    style: engine.Theme.Style,
    on_feedback: Entity.Callback,
    on_next: Entity.Callback,
) (engine.Error || Allocator.Error || Resources.Error)!void {
    self.on_next = on_next;
    self.on_feedback = on_feedback;
    self.bucket = bucket;
    self.panel = try box.add(.{
        .name = "feedback.panel",
        .background = .{
            .image_name = "white rounded rect",
            .corner_radius = 14,
            .image_corner_radius = 14,
        },
        .style = style,
        .layout = .{ .x = .fixed, .y = .shrinks, .position = .float },
        .child_align = .{ .x = .centre, .y = .centre },
        .rect = .{ .x = 5, .y = 5, .height = feedback_panel_height, .width = 250 },
        .minimum = .{ .height = feedback_panel_height, .width = 250 },
        .maximum = .{ .height = feedback_panel_height * 3, .width = 500 },
        .pad = .{
            .top = feedback_panel_pad,
            .bottom = feedback_panel_pad,
            .left = feedback_panel_pad,
            .right = feedback_panel_pad,
        },
        .visible = .hidden,
        .type = .{ .panel = .{ .spacing = feedback_panel_pad, .direction = .left_to_right } },
        .on_resized = .{ .func = @ptrCast(&resizeFeedbackBar), .ptr = self },
    }, display);
    self.icon = try self.panel.add(.{
        .name = "icon",
        .layout = .{ .x = .shrinks },
        .child_align = .{ .x = .centre, .y = .centre },
        .pad = .{ .top = 5, .bottom = 5, .left = 5, .right = 5 },
        .rect = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_icon_width },
        .minimum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_icon_width },
        .maximum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_icon_width },
        .texture_name = if (style == .success) "feedback tick" else "feedback cross",
        .type = .{ .sprite = .{ .scale = .fit } },
    }, display);
    self.rows = try self.panel.add(.{
        .name = "rows",
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre, .y = .centre },
        .minimum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = min_width - feedback_button_width },
        .maximum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = max_width - feedback_button_width },
        .type = .{ .panel = .{ .spacing = feedback_panel_pad, .direction = .top_to_bottom } },
    }, display);
    self.heading = try self.rows.add(.{
        .name = "heading",
        .layout = .{ .y = .shrinks, .x = .grows },
        .style = style,
        .child_align = .{ .x = .start },
        .minimum = .{ .width = min_width - feedback_button_width },
        .maximum = .{ .width = max_width - feedback_button_width },
        .pad = .{ .right = 1 },
        .type = .{ .label = .{
            .text = "Well done!",
            .text_size = .subheading,
        } },
    }, display);
    self.text = try self.rows.add(.{
        .name = "text",
        .layout = .{ .y = .shrinks, .x = .grows },
        .style = style,
        .child_align = .{ .x = .start },
        .minimum = .{ .width = min_width - feedback_button_width },
        .maximum = .{ .width = max_width - feedback_button_width },
        .pad = .{ .right = 1 },
        .type = .{ .label = .{
            .text = "This is a sample translation.",
        } },
    }, display);
    self.flag = try self.panel.add(.{
        .name = "flag",
        .layout = .{ .x = .shrinks },
        .child_align = .{ .y = .centre },
        .style = .custom,
        .colour = .{ .r = 255, .g = 255, .b = 255, .a = 128 },
        .pad = .{ .top = 5, .bottom = 5, .left = 5, .right = 5 },
        .rect = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_icon_width },
        .minimum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_icon_width },
        .maximum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_icon_width },
        .texture_name = "feedback flag",
        .type = .{ .sprite = .{
            .scale = .fit,
            .on_pressed = on_feedback,
        } },
    }, display);
    if (on_feedback.func == null) self.flag.visible = .hidden;
    self.button = try self.panel.add(.{
        .name = "next",
        .aria_label = "Show Next Card",
        .layout = .{ .x = .shrinks },
        .child_align = .{ .x = .centre },
        .style = style,
        .pad = .{ .left = 1, .right = 0 },
        .rect = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_button_width },
        .minimum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_button_width },
        .maximum = .{ .height = feedback_panel_height - feedback_panel_pad * 2, .width = feedback_button_width },
        .background = .{
            .corner_radius = 14,
            .image_corner_radius = 50,
        },
        .type = .{ .button = .{
            .text = "Next",
            .button = .{
                .default_name = "default button",
                .hover_name = "hover button",
                .pressed_name = "pressed button",
                .disabled_name = "hover button",
            },
            .on_pressed = .{ .func = @ptrCast(&tapNext), .ptr = self },
        } },
    }, display);
}

fn tapNext(
    self: *FeedbackPanel,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) Allocator.Error!void {
    try self.beginSlideAway(display);
    try self.on_next.call(display, entity, event);
}

pub fn slideIn(
    self: *FeedbackPanel,
    display: *Display,
) Allocator.Error!void {
    try self.panel.setVisibility(display, .visible);
    display.relayout();
    _ = self.resizeFeedbackBar(display, self.panel);
    const to = self.panel.rect;
    const from = self.panel.rect.move(.{ .x = 0, .y = self.panel.rect.height + 20 });
    debug("slide {t} {s} from {d}x{d} to {d}x{d}", .{
        self.panel.style,
        self.panel.name,
        from.x,
        from.y,
        to.x,
        to.y,
    });
    try display.addAnimator(.{
        .mode = .{ .move = .{
            .start = from,
            .end = to,
        } },
        .movement = .ease,
        .duration = slide_time,
        .target = self.panel,
        .on_end = .{ .func = @ptrCast(&endSlideIn), .ptr = self },
    });
}

fn endSlideIn(
    self: *FeedbackPanel,
    display: *Display,
    _: *Entity,
) Allocator.Error!void {
    if (self.event.isKeyboardEvent()) {
        self.button.selected(display, &self.event);
    }
}

pub fn beginSlideAway(
    self: *FeedbackPanel,
    display: *Display,
) Allocator.Error!void {
    if (self.panel.visible != .visible) return;

    const to = self.panel.rect.move(.{
        .x = 0,
        .y = self.panel.rect.height + 20,
    });
    trace("slide {s} from {d}x{d} to {d}x{d}", .{
        self.panel.name,
        self.panel.rect.x,
        self.panel.rect.y,
        to.x,
        to.y,
    });
    try display.addAnimator(.{
        .mode = .{ .move = .{
            .start = self.panel.rect,
            .end = to,
        } },
        .movement = .ease,
        .duration = slide_time,
        .target = self.panel,
        .on_end = .{ .func = @ptrCast(&endSlideAway), .ptr = self },
    });
}

fn endSlideAway(
    _: *FeedbackPanel,
    display: *Display,
    entity: *Entity,
) Allocator.Error!void {
    try entity.setVisibility(display, .hidden);
}

/// Ensure the feedback panels are correctly placed at the bottom middle
/// of the screen.
pub fn resizeFeedbackBar(
    self: *FeedbackPanel,
    display: *Display,
    _: *Entity,
) bool {
    const feedback_width = @min(
        display.root.rect.width - display.root.pad.left - display.root.pad.right - 20,
        500,
    );
    const button_width = feedback_button_width;
    const spacing = feedback_panel_pad;
    var updated = false;

    if (self.panel.rect.width != feedback_width) {
        self.panel.rect.width = feedback_width;
        self.panel.minimum.width = feedback_width;
        self.panel.maximum.width = feedback_width;
        self.rows.rect.width = feedback_width - button_width - feedback_icon_width * 2 - spacing * 5;
        self.rows.minimum.width = self.rows.rect.width;
        self.rows.maximum.width = self.rows.rect.width;
        self.text.rect.width = feedback_width - button_width - feedback_icon_width * 2 - spacing * 5;
        self.text.minimum.width = self.text.rect.width;
        self.text.maximum.width = self.text.rect.width;
        self.heading.rect.width = feedback_width - button_width - feedback_icon_width * 2 - spacing * 5;
        self.heading.minimum.width = self.heading.rect.width;
        self.heading.maximum.width = self.heading.rect.width;
        updated = true;
    }

    const centre = display.root.rect.width / 2 - self.panel.rect.width / 2;
    if (self.panel.rect.x != centre) {
        self.panel.rect.x = display.root.rect.width / 2 - self.panel.rect.width / 2;
    }

    if (!display.isAnimating(self.panel)) {
        const top = display.root.rect.height - display.root.pad.bottom - self.panel.rect.height - 16;
        self.panel.rect.y = top;
    }

    return updated;
}

/// Slide in the correct feedback panel. If no parameters are provided,
/// a simple "correct" response is displayed.
///
/// Options are:
///  - {text} means {value}
///  - The answer is {value}
///  - Incorrect
pub fn showCorrectFeedback(
    self: *FeedbackPanel,
    display: *Display,
    text: ?[]const u8,
    value: ?[]const u8,
    event: *const Event,
) (Allocator.Error || Resources.Error)!void {
    self.event = event.*;
    debug("showCorrectFeedback triggered after {t}", .{event.type});
    const bucket = self.bucket;
    if (text != null and value != null) {
        trace("showCorrectFeedback text={s} value={s}", .{ text.?, value.? });
        const tr = display.translation.translate("WORD_MEANS_WORD");
        const msg = bucket.addFields(tr, .{
            .x = text.?,
            .y = value.?,
        }) catch "";
        try self.heading.setVisibility(display, .hidden);
        try self.text.setVisibility(display, .visible);
        try self.heading.setText(display, "");
        try self.text.setText(display, msg);
    } else if (value != null) {
        trace("showCorrectFeedback value={s}", .{value.?});
        const tr = display.translation.translate("CORRECT_ANSWER_IS");
        const msg = if (value.?.len < 40) bucket.addFields(tr, .{
            .answer = value.?,
        }) catch "" else value.?;
        try self.heading.setVisibility(display, .hidden);
        try self.text.setVisibility(display, .visible);
        try self.heading.setText(display, "");
        try self.text.setText(display, msg);
    } else {
        trace("showCorrectFeedback no text or value", .{});
        const message = messages[random(messages.len)];
        try self.heading.setVisibility(display, .visible);
        try self.text.setVisibility(display, .hidden);
        try self.heading.setText(display, message);
        try self.text.setText(display, "");
    }
    //try self.app.playUISound("correct");
    try self.slideIn(display);
}

/// Slide in the incorrect feedback panel. If no parameters are
/// provided, a simple "incorrect" response is displayed.
///
/// Options are:
///  - {text} means {value}
///  - The answer is {value}
///  - Incorrect
pub fn showIncorrectFeedback(
    self: *FeedbackPanel,
    display: *Display,
    text: ?[]const u8,
    value: ?[]const u8,
    event: *const Event,
) (Allocator.Error || Resources.Error)!void {
    self.event = event.*;
    debug("showIncorrectFeedback triggered after {t}", .{event.type});
    var bucket = self.bucket;
    if (text != null and value != null) {
        const tr = display.translation.translate("WORD_MEANS_WORD");
        const msg = bucket.addFields(tr, .{
            .x = text.?,
            .y = value.?,
        }) catch "";
        try self.heading.setVisibility(display, .hidden);
        try self.text.setVisibility(display, .visible);
        try self.heading.setText(display, "");
        try self.text.setText(display, msg);
    } else if (value != null) {
        const tr = display.translation.translate("CORRECT_ANSWER_IS");
        const msg = if (value.?.len < 40) bucket.addFields(tr, .{
            .answer = value.?,
        }) catch "" else value.?;
        try self.heading.setText(display, "");
        try self.text.setText(display, msg);
        try self.heading.setVisibility(display, .hidden);
        try self.text.setVisibility(display, .visible);
    } else {
        try self.heading.setText(display, "Try again!");
        try self.text.setText(display, "");
        try self.heading.setVisibility(display, .visible);
        try self.text.setVisibility(display, .hidden);
    }
    try self.slideIn(display);
}

const dialogos = @import("dialogos");
const Sentence = dialogos.Sentence;

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const engine = @import("engine");
const trace = engine.log.trace;
const debug = engine.log.debug;
const info = engine.log.info;
const err = engine.log.err;
const warn = engine.log.err;
const Audio = engine.Audio;
const Colour = engine.Colour;
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const TextSize = engine.TextSize;
const Texture = engine.Texture;
const seconds = engine.seconds;
const StringBucket = engine.StringBucket;

const resources = @import("resources");
const Resource = resources.Resource;
const Resources = resources.Resources;
const uid_writer = resources.uid_writer;

const praxis = @import("praxis");
const random = praxis.random.random;
const Lang = praxis.Lang;
