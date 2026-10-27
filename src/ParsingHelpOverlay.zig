pub const ParsingHelpOverlay = @This();

app: *App,
panel: *Entity,
word: *Entity,
form: *Entity,
glosses: *Entity,
gloss_buffer: std.Io.Writer.Allocating = undefined,
scroller: *Entity = undefined,

word_chart: WordChart = undefined,

pub fn init(
    self: *ParsingHelpOverlay,
    app: *App,
) (engine.Error || Allocator.Error || Resources.Error)!void {
    self.app = app;
    self.gloss_buffer = .init(app.display.allocator);
    _ = try app.display.appendPanel(
        \\panel:panel name "parsing.help.overlay" not_choosable
        \\  hidden vertical image_corner_radius 14 corner_radius 1
        \\  style custom background_colour #00000050
        \\  background_image "white rounded rect"
        \\  layout grows grows align centre centre
        \\  on_pressed animateOut
        \\{
        \\  button name "back"
        \\    layout shrinks shrinks
        \\    pad 0.5em 0.5em 1em 1em
        \\    icon_default "icon-back"
        \\    icon_size width=1.5em height=1.5em
        \\    on_pressed animateOut
        \\  expander name "top" weight 1
        \\  label:word text "label"
        \\    layout grows shrinks align centre centre
        \\  label:form text "label" text_size heading style tinted
        \\    layout grows shrinks align centre centre
        \\  label:glosses text "glosses"
        \\    layout grows shrinks align centre centre
        \\    pad left=2em right=2em
        \\  panel name "spacer" rect 30 30 layout fixed fixed
        \\  expander name "middle" weight 1
        \\  panel:scroller layout grows shrinks  scroll horizontal
        \\    horizontal align start start
        \\    pad left=1em right=1em minimum height=7em spacing 0.5em
        \\  expander name "bottom" weight 1
        \\}
    , ParsingHelpOverlay, self);
    try self.word_chart.init(app.display, self.scroller);
}

pub fn setup(
    self: *ParsingHelpOverlay,
    display: *Display,
    form: *Form,
    uk: bool,
) Allocator.Error!void {
    self.panel.background.colour = self.app.display.theme.background_colour;
    self.panel.background.colour.a = 220;
    try self.word.setText(display, form.lexeme.?.word);
    try self.form.setText(display, form.word);
    try self.glosses.setText(display, form.word);
    try self.word_chart.setup(display, uk, form.lexeme.?, form);
    self.gloss_buffer.clearRetainingCapacity();
    if (form.glossesByLang(Lang.english)) |value| {
        value.string(&self.gloss_buffer.writer) catch {};
    }
    try self.glosses.setText(display, self.gloss_buffer.written());
}

pub fn animateIn(
    self: *ParsingHelpOverlay,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    info("help animate in", .{});
    _ = entity;
    _ = event;
    _ = try self.panel.setVisibility(display, .visible);
}

pub fn animateOut(
    self: *ParsingHelpOverlay,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    info("help animate out", .{});
    _ = try self.panel.setVisibility(display, .hidden);
    _ = entity;
    _ = event;
}

pub fn deinit(self: *ParsingHelpOverlay) void {
    self.gloss_buffer = .init(self.app.display.allocator);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const warn = std.log.warn;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;

const info = engine.log.info;

const resources = @import("resources");
const Resources = resources.Resources;

const praxis = @import("praxis");
const Panel = praxis.Panels.Panel;
const Lexeme = praxis.Lexeme;
const Form = praxis.Form;
const Lang = praxis.Lang;

const App = @import("App.zig");
const WordChart = @import("WordInfoScreen.zig").WordChart;
