//! Build the menu item panels. The main menu buttons
//! that float on the bottom of the screen. The progress bar
//! that floats on the top of a quiz.

pub var panel: *Element = undefined;

pub var toolbar: *Element = undefined;
pub var buttons: *Element = undefined;
pub var bg: *Element = undefined;
pub var progress_bar: *Element = undefined;

var search_button: *Element = undefined;
var parsing_button: *Element = undefined;
var preferences_button: *Element = undefined;

pub const ICON_PAD = 20;

pub fn init(context: *AppContext) !void {
    var display = context.display;

    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "menu",
            .visible = .hidden,
            .rect = .{ .x = 0, .y = 0, .width = 150, .height = 100 },
            .minimum = .{ .width = 400, .height = 130 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .type = .{ .panel = .{ .direction = .top_to_bottom } },
            //.on_resized = show_metrics,
        },
    ));

    progress_bar = try panel.add(try engine.create_progress_bar(
        display,
        .{
            .name = "progress_bar",
            .visible = .hidden,
            .rect = .{ .x = 50, .y = 50, .width = 500, .height = 86 },
            .minimum = .{ .height = 20 },
            .pad = .{ .left = 20, .right = 20, .top = 46, .bottom = 20 },
            .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
            .type = .{ .progress_bar = .{ .progress = 0.5 } },
            .on_resized = align_progress_bar,
        },
    ));

    toolbar = try panel.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "toolbar",
            .rect = .{ .x = 0, .y = 100, .width = 150, .height = 100 },
            .minimum = .{ .width = 400, .height = 130 },
            .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
            .child_align = .{ .x = .start, .y = .end },
            .type = .{ .panel = .{ .direction = .centre } },
            .on_resized = fix_toolbar,
        },
    ));

    bg = try toolbar.add(try engine.create_rect(display, .{
        .name = "menu_bg",
        .rect = .{ .x = 0, .y = 0, .width = 550, .height = 100 },
        .minimum = .{ .width = 300, .height = 130 },
        .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
        .background_colour = .{ .r = 99, .g = 150, .b = 50, .a = 255 },
        .type = .{ .rectangle = .{ .style = .background } },
    }));

    buttons = try toolbar.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "buttons",
            .rect = .{ .x = 0, .y = 0, .width = 300, .height = 100 },
            .minimum = .{ .width = 300, .height = 100 },
            //.pad = .{ .left = 20, .right = 20, .top = 30, .bottom = 30 },
            .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
            .child_align = .{ .x = .centre, .y = .end },
            .type = .{ .panel = .{ .direction = .left_to_right, .spacing = 5 } },
        },
    ));

    search_button = try buttons.add(try engine.create_button(
        display,
        "icon-list-search",
        "icon-list-search",
        "icon-list-search",
        .{
            .name = "search.tool",
            .rect = .{ .x = 150, .y = 40, .width = 120, .height = 120 },
            .minimum = .{ .width = 120, .height = 120 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .fixed, .y = .fixed },
            .type = .{ .button = .{
                .text = "",
                .on_click = show_search_screen,
                .icon_size = .{ .x = 80, .y = 80 },
            } },
        },
        "",
        "",
        "",
    ));

    parsing_button = try buttons.add(try engine.create_button(
        display,
        "icon-parsing-check",
        "icon-parsing-check",
        "icon-parsing-check",
        .{
            .name = "parsing.tool",
            .rect = .{ .x = 250, .y = 40, .width = 120, .height = 120 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .fixed, .y = .fixed },
            .type = .{ .button = .{
                .text = "",
                .on_click = show_parsing_menu,
                .icon_size = .{ .x = 80, .y = 80 },
            } },
        },
        "",
        "",
        "",
    ));

    preferences_button = try buttons.add(try engine.create_button(
        display,
        "icon settings",
        "icon settings",
        "icon settings",
        .{
            .name = "preferences.tool",
            .rect = .{ .x = 390, .y = 40, .width = 120, .height = 120 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .fixed, .y = .fixed },
            .type = .{ .button = .{
                .text = "",
                .on_click = pick_preferences_menu,
                .icon_size = .{ .x = 80, .y = 80 },
            } },
        },
        "",
        "",
        "",
    ));
}

/// Handle tap on the preferences menu icon
pub fn pick_preferences_menu(display: *Display, _: *Element) std.mem.Allocator.Error!void {
    PreferencesScreen.show(display);
}

/// Handle tap on the search menu icon
pub fn show_search_screen(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    try SearchScreen.show(display, element);
}

/// Handle tap on the word info menu icon
pub fn pick_word_info_menu(display: *Display, _: *Element) std.mem.Allocator.Error!void {
    display.choose_panel("word.info");
}

/// Custom code to handle positioning of the progress bar while the
/// user is participating in a quiz.
pub fn align_progress_bar(display: *Display, _: *Element) bool {
    var updated = false;

    const progress_centre = display.root.rect.width / 2 - progress_bar.rect.width / 2;
    if (progress_bar.rect.x != progress_centre) {
        progress_bar.rect.x = progress_centre;
        updated = true;
    }
    if (progress_bar.rect.y != display.safe_area.top) {
        progress_bar.rect.y = display.safe_area.top;
        updated = true;
    }
    return updated;
}

fn under_menu_spacing(display: *Display, _: *Element) f32 {
    const menu = menubar_height(display);
    const total = menu;
    //const total = menu + (display.text_height * engine.TextSize.normal.height() * display.scale);
    err("menu = {d} total = {d}", .{ menu, total });
    return total;
}

pub fn update_bottom_spacing(display: *Display, bottom: *Element) bool {
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
pub inline fn menubar_height(display: *Display) f32 {
    const icon_size = display.text_height * display.scale * engine.TextSize.heading.height();
    const button_height = icon_size + (ICON_PAD * 2);
    return button_height + (ICON_PAD / 2);
}

pub fn fix_toolbar(display: *Display, _: *Element) bool {
    var updated = false;

    const menu_height = menubar_height(display) + display.safe_area.bottom;

    if (toolbar.rect.height != menu_height) {
        toolbar.rect.height = menu_height;
        toolbar.minimum.height = menu_height;
        toolbar.maximum.height = menu_height;
        bg.rect.height = menu_height;
        bg.minimum.height = menu_height;
        bg.maximum.height = menu_height;
        buttons.rect.height = menu_height;
        buttons.minimum.height = menu_height;
        buttons.minimum.height = menu_height;

        const icon_size = display.text_height * display.scale * engine.TextSize.heading.height();
        const button_size = icon_size + (ICON_PAD * 2);

        search_button.type.button.icon_size.x = icon_size;
        search_button.type.button.icon_size.y = icon_size;
        search_button.rect.width = button_size;
        search_button.minimum.width = button_size;
        search_button.maximum.width = button_size;
        search_button.rect.height = button_size;
        search_button.minimum.height = button_size;
        search_button.maximum.height = button_size;

        parsing_button.type.button.icon_size.x = icon_size;
        parsing_button.type.button.icon_size.y = icon_size;
        parsing_button.rect.width = button_size;
        parsing_button.rect.height = button_size;
        parsing_button.minimum.width = button_size;
        parsing_button.maximum.width = button_size;
        parsing_button.minimum.height = button_size;
        parsing_button.maximum.height = button_size;

        preferences_button.type.button.icon_size.x = icon_size;
        preferences_button.type.button.icon_size.y = icon_size;
        preferences_button.rect.width = button_size;
        preferences_button.minimum.width = button_size;
        preferences_button.maximum.width = button_size;
        preferences_button.rect.height = button_size;
        preferences_button.minimum.height = button_size;
        preferences_button.maximum.height = button_size;
        updated = true;
    }

    // Determine menu position relative to bottom of the screen
    if (toolbar.rect.width != display.root.rect.width) {
        toolbar.rect.width = display.root.rect.width;
        toolbar.rect.x = 0;
        buttons.rect.width = display.root.rect.width;
        bg.rect.width = display.root.rect.width;
        bg.rect.x = 0;
        updated = true;
    }
    const y_pos = display.root.rect.height - menu_height;
    if (toolbar.rect.y != y_pos) {
        toolbar.rect.y = y_pos;
        buttons.rect.y = y_pos;
        bg.rect.y = y_pos;
        updated = true;
    }
    //_ = show_metrics(display, e);
    return updated;
}

pub fn show_metrics(_: *Display, e: *Element) bool {
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
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const engine = @import("engine");
const Display = engine.Display;
const Element = engine.Element;
const info = engine.info;
const err = engine.err;
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const PreferencesScreen = @import("screen_preferences.zig");
const SearchScreen = @import("screen_search.zig");
const show_parsing_menu = ParsingMenuScreen.show;
