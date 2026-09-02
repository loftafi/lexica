//! Build the menu item panels. The main menu buttons
//! that float on the bottom of the screen. The progress bar
//! that floats on the top of a quiz.
pub const MenuUI = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,
toolbar: *Entity = undefined,
buttons: *Entity = undefined,
bg: *Entity = undefined,
progress_bar: *Entity = undefined,

search_button: *Entity = undefined,
parsing_button: *Entity = undefined,
preferences_button: *Entity = undefined,

pub const ICON_PAD = 10;

pub fn init(self: *MenuUI, app: *AppContext) !void {
    self.app = app;
    var display = app.display;

    self.panel = try display.appendPanel(
        \\panel:panel name "menu" hidden not_choosable avoid_safe_area vertical
        \\  layout grows grows align centre start
        \\{
        \\  panel:progress_bar hidden
        \\    pad top=1.0em bottom=0em left=2.2em right=2.2em
        \\    layout grows shrinks float
        \\      minimum height=20
        \\      maximum width=500
        \\  {
        \\
        \\    progress_bar never_focus name "progress_bar"
        \\      layout grows grows
        \\      minimum width=100 height=12
        \\      maximum width=800 height=20
        \\      on_resized resizeProgressBar
        \\      image "white rounded rect"
        \\      corner_radius 6 image_corner_radius 14
        \\  }
        \\}
    , MenuUI, self);

    self.toolbar = try self.panel.add(.{
        .name = "toolbar",
        .rect = .{ .x = 0, .y = 100, .width = 150, .height = 100 },
        .minimum = .{ .width = 400, .height = 130 },
        .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
        .child_align = .{ .x = .start, .y = .end },
        .type = .{ .panel = .{ .direction = .centre } },
        .on_resized = .{ .func = @ptrCast(&fix_toolbar), .ptr = self },
    }, display);

    self.bg = try self.toolbar.add(.{
        .name = "menu_bg",
        .rect = .{ .x = 0, .y = 0, .width = 550, .height = 100 },
        .minimum = .{ .width = 300, .height = 130 },
        .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
        .background = .{ .colour = .{ .r = 99, .g = 150, .b = 50, .a = 255 } },
        .style = .background,
        .type = .{ .rectangle = .{} },
    }, display);

    self.buttons = try self.toolbar.add(.{
        .name = "buttons",
        .rect = .{ .x = 0, .y = 0, .width = 300, .height = 100 },
        .minimum = .{ .width = 300, .height = 100 },
        .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
        .child_align = .{ .x = .centre, .y = .end },
        .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 5 } },
    }, display);

    self.search_button = try self.buttons.add(.{
        .name = "search.tool",
        .rect = .{ .x = 150, .y = 40, .width = 120, .height = 120 },
        .minimum = .{ .width = 120, .height = 120 },
        .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon = .{
                .default_name = "icon-list-search",
                .hover_name = "icon-list-search",
                .pressed_name = "icon-list-search",
                .size = .{ .width = 80, .height = 80 },
            },
            .on_pressed = .{
                .func = @ptrCast(&SearchScreen.show),
                .ptr = &self.app.search_screen,
            },
        } },
    }, display);

    self.parsing_button = try self.buttons.add(.{
        .name = "parsing.tool",
        .rect = .{ .x = 250, .y = 40, .width = 120, .height = 120 },
        .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon = .{
                .default_name = "icon-parsing-check",
                .hover_name = "icon-parsing-check",
                .pressed_name = "icon-parsing-check",
                .size = .{ .width = 80, .height = 80 },
            },
            .on_pressed = .{ .func = @ptrCast(&ParsingMenuScreen.show), .ptr = &self.app.parsing_menu },
        } },
    }, display);

    self.preferences_button = try self.buttons.add(.{
        .name = "preferences.tool",
        .rect = .{ .x = 390, .y = 40, .width = 120, .height = 120 },
        .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon = .{
                .default_name = "icon settings",
                .hover_name = "icon settings",
                .pressed_name = "icon settings",
                .size = .{ .width = 80, .height = 80 },
            },
            .on_pressed = .{ .func = @ptrCast(&PreferencesScreen.show), .ptr = &self.app.preferences },
        } },
    }, display);
}

pub fn deinit(self: *MenuUI) void {
    self.* = undefined;
}

/// Handle tap on the word info menu icon
pub fn pick_word_info_menu(display: *Display, _: *Entity, event: *Event) std.mem.Allocator.Error!void {
    try display.choosePanel("word.info", event);
}

/// Custom code to handle positioning of the progress bar while the
/// user is participating in a quiz.
pub fn resizeProgressBar(self: *MenuUI, display: *Display, _: *Entity) bool {
    var updated = false;

    if (self.progress_bar.visible != .visible) return false;

    const progress_centre = display.root.rect.width / 2 - self.progress_bar.rect.width / 2;
    if (self.progress_bar.rect.x != progress_centre) {
        self.progress_bar.rect.x = progress_centre;
        updated = false;
    }
    //if (self.progress_bar.rect.y != display.safe_area.top) {
    //    self.progress_bar.rect.y = display.safe_area.top;
    //    updated = true;
    //}
    return updated;
}

fn under_menu_spacing(_: *Display, _: *Entity) f32 {
    const menu = menubar_height();
    const total = menu;
    //const total = menu + (display.text_height * engine.TextSize.normal.height() * display.scale);
    err("menu = {d} total = {d}", .{ menu, total });
    return total;
}

pub fn update_bottom_spacing(_: *MenuUI, display: *Display, bottom: *Entity) bool {
    var updated = false;
    const bottom_height = under_menu_spacing(display, bottom);
    err("bottom_height = {d} safe_area.bottom = {d}", .{ bottom_height, display.safe_area.bottom });
    if (bottom.minimum.height != bottom_height) {
        updated = true;
        bottom.rect.height = bottom_height;
        bottom.minimum.height = bottom_height;
        bottom.maximum.height = bottom_height;
    }
    return updated;
}

/// menubar_height provides a standard way for screens to find
/// where the menubar starts
pub inline fn menubar_height() f32 {
    const icon_size = engine.TextSize.heading.size();
    const button_height = icon_size + (ICON_PAD * 2);
    return button_height + (ICON_PAD / 2);
}

pub fn fix_toolbar(self: *MenuUI, display: *Display, _: *Entity) bool {
    var updated = false;

    const menu_height = menubar_height() + display.safe_area.bottom;

    if (self.toolbar.rect.height != menu_height) {
        self.toolbar.rect.height = menu_height;
        self.toolbar.minimum.height = menu_height;
        self.toolbar.maximum.height = menu_height;
        self.bg.rect.height = menu_height;
        self.bg.minimum.height = menu_height;
        self.bg.maximum.height = menu_height;
        self.buttons.rect.height = menu_height;
        self.buttons.minimum.height = menu_height;
        self.buttons.minimum.height = menu_height;

        const icon_size = engine.TextSize.heading.size();
        const button_size = icon_size + (ICON_PAD * 2);

        self.search_button.type.button.icon.size.width = icon_size;
        self.search_button.type.button.icon.size.height = icon_size;
        self.search_button.rect.width = button_size;
        self.search_button.minimum.width = button_size;
        self.search_button.maximum.width = button_size;
        self.search_button.rect.height = button_size;
        self.search_button.minimum.height = button_size;
        self.search_button.maximum.height = button_size;

        self.parsing_button.type.button.icon.size.width = icon_size;
        self.parsing_button.type.button.icon.size.height = icon_size;
        self.parsing_button.rect.width = button_size;
        self.parsing_button.rect.height = button_size;
        self.parsing_button.minimum.width = button_size;
        self.parsing_button.maximum.width = button_size;
        self.parsing_button.minimum.height = button_size;
        self.parsing_button.maximum.height = button_size;

        self.preferences_button.type.button.icon.size.width = icon_size;
        self.preferences_button.type.button.icon.size.height = icon_size;
        self.preferences_button.rect.width = button_size;
        self.preferences_button.minimum.width = button_size;
        self.preferences_button.maximum.width = button_size;
        self.preferences_button.rect.height = button_size;
        self.preferences_button.minimum.height = button_size;
        self.preferences_button.maximum.height = button_size;
        updated = true;
    }

    // Determine menu position relative to bottom of the screen
    if (self.toolbar.rect.width != display.root.rect.width) {
        self.toolbar.rect.width = display.root.rect.width;
        self.toolbar.rect.x = 0;
        self.buttons.rect.width = display.root.rect.width;
        self.bg.rect.width = display.root.rect.width;
        self.bg.rect.x = 0;
        updated = true;
    }
    const y_pos = display.root.rect.height - menu_height;
    if (self.toolbar.rect.y != y_pos) {
        self.toolbar.rect.y = y_pos;
        self.buttons.rect.y = y_pos;
        self.bg.rect.y = y_pos;
        updated = true;
    }
    //_ = show_metrics(display, e);
    return updated;
}

pub fn show_metrics(_: *Display, e: *Entity) bool {
    info("{s} {s} size: {d}x{d} pos {d}x{d}", .{
        e.name,
        @tagName(e.type),
        e.rect.width,
        e.rect.height,
        e.rect.x,
        e.rect.y,
    });
    return false;
}

const builtin = @import("builtin");
const std = @import("std");

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const info = engine.log.info;
const err = engine.log.err;

const ac = @import("App.zig");
const AppContext = ac.AppContext;

const ParsingMenuScreen = @import("ParsingMenuScreen.zig");
const PreferencesScreen = @import("PreferencesScreen.zig");
const SearchScreen = @import("SearchScreen.zig");
