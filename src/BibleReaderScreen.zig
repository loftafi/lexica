/// Scroll through the biblical text
pub const BibleReaderScreen = @This();

app: *App = undefined,
panel: *Entity = undefined,
title: *Entity = undefined,
scroller: *Entity = undefined,

pub fn show(
    self: *BibleReaderScreen,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (display.currentPanel()) |current| if (current == self.panel) return;
    try display.choosePanel(self.panel.name, event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
}

pub fn setup(self: *BibleReaderScreen, book: praxis.Book) Allocator.Error!void {
    _ = self;
    _ = book;
}

pub fn init(self: *BibleReaderScreen, app: *App) !void {
    self.app = app;

    try app.display.requireResourceRecord("dict", .bin);

    _ = try app.display.appendPanel(
        \\panel:panel name "bible.screen" not_choosable
        \\  hidden vertical
        \\  layout grows grows align centre centre
        \\{
        \\  button name "back"
        \\    layout shrinks shrinks
        \\    pad 0.5em 0.5em 1em 1em
        \\    icon_default "icon-back"
        \\    icon_size width=1.5em height=1.5em
        \\    on_pressed tapBack
        \\  label:title text "label"
        \\    layout grows shrinks align centre centre
        \\    pad left=2em right=2em
        \\  panel name "spacer" rect 30 30 layout fixed fixed
        \\  panel:scroller layout grows shrinks  scroll vertical
        \\    vertical align start start
        \\    pad left=1em right=1em minimum height=7em spacing 0.5em
        \\    on_resized resizeScroller
        \\}
    , BibleReaderScreen, self);
}

pub fn deinit(self: *BibleReaderScreen) void {
    _ = self;
}

pub fn tapBack(
    self: *BibleReaderScreen,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    info("bible reader animate out", .{});
    _ = try self.panel.setVisibility(display, .hidden);
    _ = entity;
    _ = event;
}

pub fn resizeScroller(
    _: *BibleReaderScreen,
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

const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const debug = engine.log.debug;
const trace = engine.log.trace;
const warn = engine.log.warn;
const err = engine.log.err;
const info = engine.log.info;

const praxis = @import("praxis");
const Lang = praxis.Lang;
const Form = praxis.Form;

const App = @import("App.zig");
const MenuUI = @import("MenuUI.zig");
