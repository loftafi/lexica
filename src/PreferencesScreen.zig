pub const PreferencesScreen = @This();

app: *AppContext,
panel: *Entity = undefined,
picker_panel: *Entity = undefined,
preferences_heading: *Entity = undefined,
uk_panel: *Entity = undefined,
uk_panel_ring: *Entity = undefined,
us_panel: *Entity = undefined,
us_panel_ring: *Entity = undefined,

/// Tap the heading 10 times to enable debug mode
tap_counter: usize = 0,

pub fn show(
    self: *PreferencesScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    try display.choosePanel("preferences.screen", event);
    display.need_relayout = true;
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }

    display.relayout();
    self.updateRing();
    self.tap_counter = 0;
}

pub fn init(self: *PreferencesScreen, app: *AppContext) !void {
    var display = app.display;
    self.app = app;

    _ = try display.appendPanel(
        \\panel:panel name "preferences.screen" hidden vertical choosable
        \\  layout grows grows align centre centre
        \\  minimum width=280 height=360
        \\  maximum width=360
        \\  pad left=1em right=1em bottom=0.5em
        \\  spacing 8
        \\{
        \\  label:preferences_heading never_focus style tinted
        \\    layout grows shrinks align centre start
        \\    text_size heading text "Preferences"
        \\    on_pressed tapHeading pad top=15
        \\
        \\  label name "case_order_info"
        \\    layout grows shrinks align centre start
        \\    text "Which noun order you prefer?"
        \\
        \\  panel:picker_panel name "preferences.screen" horizontal
        \\    layout grows shrinks align centre start
        \\    pad left=0.5em right=0.5em top=0.5em bottom=0.5em
        \\    spacing=10 
        \\
        \\  expander weight 1
        \\
        \\  label name "choose_language_heading" text "User Interface"
        \\    layout grows shrinks align centre start style tinted
        \\    text_size subheading
        \\
        \\}
    , PreferencesScreen, self);

    try initPickerTable(
        display,
        self.picker_panel,
        &[4][]const u8{ "ὁ", "τοῦ", "τῷ", "τόν" },
        &[4][]const u8{ "Θεός", "Θεοῦ", "Θεῷ", "Θεόν" },
        &self.us_panel,
        &self.us_panel_ring,
    );
    self.us_panel.type.panel.on_pressed = .{
        .func = @ptrCast(&chooseUSOrder),
        .ptr = self,
    };

    try initPickerTable(
        display,
        self.picker_panel,
        &[4][]const u8{ "ὁ", "τόν", "τοῦ", "τῷ" },
        &[4][]const u8{ "Θεός", "Θεόν", "Θεοῦ", "Θεῷ" },
        &self.uk_panel,
        &self.uk_panel_ring,
    );
    self.uk_panel.type.panel.on_pressed = .{
        .func = @ptrCast(&chooseUKOrder),
        .ptr = self,
    };

    _ = try self.panel.add(.{
        .name = "pick_language",
        .layout = .{ .x = .grows },
        .type = .{ .checkbox = .{
            .text = "Use Koine Greek UI",
            .checked = ac.app_context.?.preference.use_koine,
            .on_change = .{
                .func = @ptrCast(&changeKoinePreference),
                .ptr = self,
            },
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "show_strongs",
        .layout = .{ .x = .grows },
        .type = .{ .checkbox = .{
            .text = "Show Strongs Numbers",
            .checked = ac.app_context.?.preference.show_strongs,
            .on_change = .{
                .func = @ptrCast(&changeStrongsPreference),
                .ptr = self,
            },
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "middle.expander",
        .rect = .{ .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    _ = try self.panel.add(.{
        .name = "choose_theme_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Theme",
            .text_size = .subheading,
        } },
    }, display);

    try self.initThemeButton(display, self.panel);

    _ = try self.panel.add(.{
        .name = "bottom.expander",
        .rect = .{ .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    const links = try self.panel.add(.{
        .name = "link_menu",
        .minimum = .{ .height = 44, .width = 300 },
        .pad = .{ .top = 5 },
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .type = .{ .panel = .{ .direction = .left_to_right_wrap, .spacing = 0 } },
    }, display);

    _ = try links.add(.{
        .name = "privacy.link",
        .style = .tinted,
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .top = 7, .bottom = 7, .left = 0, .right = 12 },
        .child_align = .{ .x = .start },
        .type = .{ .button = .{
            .text = "PRIVACY_POLICY",
            .text_size = .small,
            .icon = .{
                .size = .{ .width = 17, .height = 17 },
                .default_name = "small shield icon",
            },
            .spacing = 4,
            .on_pressed = .{ .func = @ptrCast(&PrivacyScreen.show), .ptr = &self.app.privacy },
        } },
    }, display);

    _ = try links.add(.{
        .name = "terms.link",
        .style = .tinted,
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .top = 7, .bottom = 7, .left = 12, .right = 12 },
        .child_align = .{ .x = .centre },
        .type = .{ .button = .{
            .text = "TERMS_OF_USE",
            .text_size = .small,
            .icon = .{
                .size = .{ .width = 17, .height = 17 },
                .default_name = "small document icon",
            },
            .spacing = 4,
            .on_pressed = .{ .func = @ptrCast(&TermsScreen.show), .ptr = &self.app.terms },
        } },
    }, display);

    _ = try links.add(.{
        .name = "license.link",
        .style = .tinted,
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .top = 7, .bottom = 7, .left = 12, .right = 0 },
        .child_align = .{ .x = .start },
        .type = .{ .button = .{
            .text = "LICENSES",
            .text_size = .small,
            .icon = .{
                .size = .{ .width = 17, .height = 17 },
                .default_name = "small archive icon",
            },
            .spacing = 6,
            .on_pressed = .{ .func = @ptrCast(&LicenseScreen.show), .ptr = &self.app.license },
        } },
    }, display);

    // Don't allow expanders to push under the menu area.
    _ = try app.display.add_spacer(self.panel, 75);
}

pub fn deinit(self: *PreferencesScreen) void {
    self.* = undefined;
}

fn initThemeButton(self: *PreferencesScreen, display: *Display, parent: *Entity) !void {
    var wrapper = try parent.add(.{
        .name = "theme.picker.align",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 10, .right = 10 },
        .minimum = .{ .width = 250, .height = 10 },
        .maximum = .{ .width = 500 },
        .type = .{ .panel = .{
            .direction = .left_to_right,
        } },
    }, display);

    const picker = try wrapper.add(.{
        .name = "theme_menu",
        .background = .{ .image_name = "white rounded rect" },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 15, .right = 15, .top = 10, .bottom = 10 },
        .minimum = .{ .width = 250, .height = 10 },
        .maximum = .{ .width = 500 },
        .style = .faded,
        .type = .{ .panel = .{
            .direction = .left_to_right,
            .spacing = 20,
        } },
    }, display);

    _ = try picker.add(.{
        .name = "sand",
        .rect = .{ .width = 40, .height = 40 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .style = .custom,
        .type = .{ .button = .{
            .icon = .{
                .default_name = "theme sand",
                .hover_name = "theme sand",
                .pressed_name = "theme sand",
                .size = .{ .width = 40, .height = 40 },
            },
            .on_pressed = .{ .func = @ptrCast(&tapThemeButton), .ptr = self },
        } },
    }, display);

    _ = try picker.add(.{
        .name = "white",
        .rect = .{ .width = 40, .height = 40 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .style = .custom,
        .type = .{ .button = .{
            .icon = .{
                .default_name = "theme white",
                .pressed_name = "theme white",
                .hover_name = "theme white",
                .size = .{ .width = 40, .height = 40 },
            },
            .on_pressed = .{ .func = @ptrCast(&tapThemeButton), .ptr = self },
        } },
    }, display);

    _ = try picker.add(.{
        .name = "default",
        .rect = .{ .width = 40, .height = 40 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .style = .custom,
        .type = .{ .button = .{
            .icon = .{
                .default_name = "theme default",
                .pressed_name = "theme default",
                .hover_name = "theme default",
                .size = .{ .width = 40, .height = 40 },
            },
            .on_pressed = .{ .func = @ptrCast(&tapThemeButton), .ptr = self },
        } },
    }, display);

    _ = try picker.add(.{
        .name = "black",
        .rect = .{ .width = 40, .height = 40 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .style = .custom,
        .type = .{ .button = .{
            .icon = .{
                .default_name = "theme black",
                .pressed_name = "theme black",
                .hover_name = "theme black",
                .size = .{ .width = 40, .height = 40 },
            },
            .on_pressed = .{ .func = @ptrCast(&tapThemeButton), .ptr = self },
        } },
    }, display);

    _ = try picker.add(.{
        .name = "midnight",
        .rect = .{ .width = 40, .height = 40 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .style = .custom,
        .type = .{ .button = .{
            .icon = .{
                .default_name = "theme midnight",
                .pressed_name = "theme midnight",
                .hover_name = "theme midnight",
                .size = .{ .width = 40, .height = 40 },
            },
            .on_pressed = .{ .func = @ptrCast(&tapThemeButton), .ptr = self },
        } },
    }, display);

    _ = try picker.add(.{
        .name = "garden",
        .rect = .{ .width = 40, .height = 40 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .style = .custom,
        .type = .{ .button = .{
            .icon = .{
                .default_name = "theme garden",
                .pressed_name = "theme garden",
                .hover_name = "theme garden",
                .size = .{ .width = 40, .height = 40 },
            },
            .on_pressed = .{ .func = @ptrCast(&tapThemeButton), .ptr = self },
        } },
    }, display);
}

pub fn tapHeading(
    self: *PreferencesScreen,
    _: *Display,
    _: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    self.tap_counter += 1;
    if (self.tap_counter > 10) {
        self.tap_counter = 0;
        engine.dev_mode = !engine.dev_mode;
        info("Dev mode: {any}", .{engine.dev_mode});
    }
}

pub fn tapThemeButton(
    _: *PreferencesScreen,
    display: *Display,
    event: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    const theme = display.validate_theme(event.name);
    _ = try display.setTheme(theme);
    ac.app_context.?.preference.theme = theme;
    ac.app_context.?.save_preferences();
}

pub fn initPickerTable(
    display: *Display,
    parent: *Entity,
    articles: []const []const u8,
    words: []const []const u8,
    panel: **Entity,
    panel_ring: **Entity,
) (engine.Error || Allocator.Error || Resources.Error)!void {
    panel_ring.* = try parent.add(.{
        .name = "ring",
        .background = .{
            .image_name = "white rounded rect",
            .corner_radius = 18,
            .image_corner_radius = 14,
            .colour = .transparent,
        },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .pad = .{ .left = 2, .right = 2, .top = 2, .bottom = 2 },
        .style = .custom,
        .type = .{ .panel = .{ .direction = .top_left } },
    }, display);

    panel.* = try panel_ring.*.add(.{
        .name = "table",
        .background = .{
            .image_name = "white rounded rect",
            .corner_radius = 14,
            .image_corner_radius = 14,
        },
        .focus = .can_focus,
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .start, .y = .start },
        .pad = .{ .left = 14, .right = 14, .top = 10, .bottom = 10 },
        .minimum = .{ .width = 80, .height = 80 },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
        } },
    }, display);

    for (articles, words) |article, word| {
        const row = try panel.*.add(.{
            .name = "row",
            .rect = .{ .width = 75, .height = 5 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .start, .y = .start },
            .minimum = .{ .width = 40, .height = 5 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 7,
            } },
        }, display);

        _ = try row.add(.{
            .name = "col.article",
            .rect = .{ .width = 40, .height = 5 },
            .minimum = .{ .width = 40, .height = 5 },
            .type = .{ .label = .{ .text = article } },
            .child_align = .{ .x = .end, .y = .start },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .pad = .{ .left = 1, .right = 1 },
        }, display);

        _ = try row.add(.{
            .name = "col.form",
            .rect = .{ .width = 75 },
            .minimum = .{ .width = 75 },
            .type = .{ .label = .{ .text = word } },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .pad = .{ .left = 1, .right = 1 },
        }, display);
    }
}

pub fn chooseUKOrder(
    self: *PreferencesScreen,
    _: *Display,
    entity: *Entity,
    _: *const Event,
) std.mem.Allocator.Error!void {
    debug("Choose UK order.", .{});
    std.debug.assert(entity.type == .panel);
    ac.app_context.?.preference.uk_order = true;
    self.updateRing();
    ac.app_context.?.save_preferences();
}

pub fn chooseUSOrder(
    self: *PreferencesScreen,
    _: *Display,
    entity: *Entity,
    _: *const Event,
) std.mem.Allocator.Error!void {
    debug("Choose US order.", .{});
    std.debug.assert(entity.type == .panel);
    ac.app_context.?.preference.uk_order = false;
    self.updateRing();
    ac.app_context.?.save_preferences();
}

pub fn updateRing(self: *PreferencesScreen) void {
    self.us_panel_ring.background.colour = .transparent;
    self.uk_panel_ring.background.colour = .transparent;
    self.uk_panel_ring.style = .custom;
    self.us_panel_ring.style = .custom;
    if (ac.app_context.?.preference.uk_order) {
        self.uk_panel_ring.style = .emphasised;
    } else {
        self.us_panel_ring.style = .emphasised;
    }
}

pub fn changeKoinePreference(
    _: *PreferencesScreen,
    display: *Display,
    entity: *Entity,
    _: *const Event,
) std.mem.Allocator.Error!void {
    const ctx = ac.app_context.?;

    std.debug.assert(entity.type == .checkbox);
    ctx.preference.use_koine = entity.type.checkbox.checked;
    ctx.save_preferences();
    if (ctx.preference.use_koine) {
        try display.setLanguage(Lang.greek);
    } else {
        try display.setLanguage(Lang.english);
    }
}

pub fn changeStrongsPreference(
    _: *PreferencesScreen,
    _: *Display,
    entity: *Entity,
    _: *const Event,
) std.mem.Allocator.Error!void {
    std.debug.assert(entity.type == .checkbox);
    ac.app_context.?.preference.show_strongs = entity.type.checkbox.checked;
    ac.app_context.?.save_preferences();
}

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const debug = engine.log.debug;
const info = engine.log.info;
const err = engine.log.err;
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const Resources = @import("resources").Resources;

const praxis = @import("praxis");
const Lang = praxis.Lang;

const ac = @import("App.zig");
const AppContext = ac.AppContext;

const MenuUI = @import("MenuUI.zig");
const best_width = @import("ParsingMenuScreen.zig").best_width;
const PrivacyScreen = @import("PrivacyScreen.zig");
const TermsScreen = @import("TermsScreen.zig");
const show_terms_screen = @import("TermsScreen.zig").show;
const LicenseScreen = @import("LicenseScreen.zig");
const under_menu_spacing = @import("MenuUI.zig").under_menu_spacing;
