pub const PreferencesScreen = @This();

panel: *Entity = undefined,
ring_panel: *Entity = undefined,
uk_panel: *Entity = undefined,
us_panel: *Entity = undefined,

/// Tap the heading 10 times to enable debug mode
tap_counter: usize = 0,

pub fn show(
    self: *PreferencesScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    try display.choosePanel("preferences.screen", event);
    display.relayout();
    _ = self.updateRing(display, self.panel);
    display.need_relayout = true;
    self.tap_counter = 0;
}

pub fn init(self: *PreferencesScreen, context: *AppContext) !void {
    var display = context.display;

    _ = try display.appendPanel(
        \\panel:panel name "preferences.screen" hidden vertical choosable
        \\  layout grows grows align centre centre
        \\  minimum width=280 height=360
        \\  maximum width=360
        \\  pad left=1em right=1em bottom=0.5em
        \\  on_resized updateRing
        \\
    , PreferencesScreen, self);

    self.ring_panel = try self.panel.add(.{
        .name = "ring",
        .background = .{
            .image_name = "white rounded rect",
            .corner_radius = 18,
            .image_corner_radius = 14,
        },
        .rect = .{ .width = 10, .height = 10 },
        .layout = .{ .position = .float, .x = .fixed, .y = .fixed },
        .style = .emphasised,
        .type = .{ .panel = .{} },
    }, display);

    _ = try self.panel.add(.{
        .name = "preferences_heading",
        .focus = .never_focus,
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Preferences",
            .text_size = .heading,
            .on_pressed = .{ .func = @ptrCast(&heading_tap), .ptr = self },
        } },
        .pad = .{ .top = 15 },
    }, display);

    _ = try self.panel.add(.{
        .name = "case_order_info",
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Which noun order you prefer?",
        } },
    }, display);

    const picker_panel = try self.panel.add(.{
        .name = "preferences.screen",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .minimum = .{ .width = 100, .height = 100 },
        .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
    }, display);

    self.us_panel = try create_picker_table(
        context.allocator,
        display,
        picker_panel,
        &[4][]const u8{ "ὁ", "τοῦ", "τῷ", "τόν" },
        &[4][]const u8{ "Θεός", "Θεοῦ", "Θεῷ", "Θεόν" },
    );
    self.us_panel.type.panel.on_pressed = .{
        .func = @ptrCast(&choose_us_order),
        .ptr = self,
    };

    self.uk_panel = try create_picker_table(
        context.allocator,
        display,
        picker_panel,
        &[4][]const u8{ "ὁ", "τόν", "τοῦ", "τῷ" },
        &[4][]const u8{ "Θεός", "Θεόν", "Θεοῦ", "Θεῷ" },
    );
    self.uk_panel.type.panel.on_pressed = .{
        .func = @ptrCast(&choose_uk_order),
        .ptr = self,
    };

    _ = try self.panel.add(.{
        .name = "middle.expander",
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    _ = try self.panel.add(.{
        .name = "choose_language_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "User Interface",
            .text_size = .subheading,
        } },
    }, display);

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

    try self.add_theme_pickr(display, self.panel);

    _ = try self.panel.add(.{
        .name = "bottom.expander",
        .rect = .{ .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    const links = try self.panel.add(.{
        .name = "link_menu",
        .rect = .{ .width = 150, .height = 50 },
        .minimum = .{ .height = 40, .width = 150 },
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .panel = .{ .direction = .left_to_right } },
    }, display);

    _ = try links.add(.{
        .name = "privacy.link",
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .left = 10, .right = 10 },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Privacy",
            .text_size = .small,
            .on_pressed = .{ .func = @ptrCast(&PrivacyScreen.show), .ptr = self },
        } },
    }, display);

    _ = try links.add(.{
        .name = "terms.link",
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .left = 10, .right = 10 },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Terms",
            .text_size = .small,
            .on_pressed = .{ .func = @ptrCast(&TermsScreen.show), .ptr = self },
        } },
    }, display);

    _ = try links.add(.{
        .name = "license.link",
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .left = 10, .right = 10 },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Licences",
            .text_size = .small,
            .on_pressed = .{ .func = @ptrCast(&LicenseScreen.show), .ptr = self },
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "end.expander",
        .rect = .{ .width = 50, .height = 2 },
        .minimum = .{ .width = 50, .height = 2 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    }, display);

    // Don't allow expanders to push under the menu area.
    _ = try context.display.add_spacer(self.panel, 75);
}

pub fn deinit(self: *PreferencesScreen) void {
    self.* = undefined;
}

fn add_theme_pickr(self: *PreferencesScreen, display: *Display, parent: *Entity) !void {
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
            .on_pressed = .{ .func = @ptrCast(&pick_theme), .ptr = self },
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
            .on_pressed = .{ .func = @ptrCast(&pick_theme), .ptr = self },
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
            .on_pressed = .{ .func = @ptrCast(&pick_theme), .ptr = self },
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
            .on_pressed = .{ .func = @ptrCast(&pick_theme), .ptr = self },
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
            .on_pressed = .{ .func = @ptrCast(&pick_theme), .ptr = self },
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
            .on_pressed = .{ .func = @ptrCast(&pick_theme), .ptr = self },
        } },
    }, display);
}

pub fn heading_tap(
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

pub fn pick_theme(
    _: *PreferencesScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    const theme = display.validate_theme(element.name);
    _ = display.setTheme(theme);
    ac.app_context.?.preference.theme = theme;
    ac.app_context.?.save_preferences();
}

pub fn create_picker_table(
    _: Allocator,
    display: *Display,
    parent_panel: *Entity,
    articles: []const []const u8,
    words: []const []const u8,
) !*Entity {
    var parsing_panel = try parent_panel.add(.{
        .name = "present",
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
        const row = try parsing_panel.add(.{
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
    return parsing_panel;
}

pub fn choose_uk_order(self: *PreferencesScreen, display: *Display, element: *Entity) std.mem.Allocator.Error!void {
    debug("Choose UK order.", .{});
    std.debug.assert(element.type == .panel);
    ac.app_context.?.preference.uk_order = true;
    display.need_relayout = self.updateRing(display, element);
    ac.app_context.?.save_preferences();
}

pub fn choose_us_order(self: *PreferencesScreen, display: *Display, element: *Entity) std.mem.Allocator.Error!void {
    debug("Choose US order.", .{});
    std.debug.assert(element.type == .panel);
    ac.app_context.?.preference.uk_order = false;
    display.need_relayout = self.updateRing(display, element);
    ac.app_context.?.save_preferences();
}

pub fn updateRing(self: *PreferencesScreen, _: *Display, _: *Entity) bool {
    var updated = false;
    const ring_border: f32 = 2.5;
    const ring_panel = self.ring_panel;
    const uk_panel = self.uk_panel;
    const us_panel = self.us_panel;
    if (ac.app_context.?.preference.uk_order) {
        if (ring_panel.rect.x != uk_panel.rect.x - ring_border or ring_panel.rect.y != uk_panel.rect.y - ring_border) {
            ring_panel.rect.x = uk_panel.rect.x - ring_border;
            ring_panel.rect.y = uk_panel.rect.y - ring_border;
            ring_panel.rect.width = uk_panel.rect.width + (ring_border * 2);
            ring_panel.rect.height = uk_panel.rect.height + (ring_border * 2);
            updated = true;
        }
    } else {
        if (ring_panel.rect.x != us_panel.rect.x - ring_border or ring_panel.rect.y != us_panel.rect.y - ring_border) {
            ring_panel.rect.x = us_panel.rect.x - ring_border;
            ring_panel.rect.y = us_panel.rect.y - ring_border;
            ring_panel.rect.width = us_panel.rect.width + (ring_border * 2);
            ring_panel.rect.height = us_panel.rect.height + (ring_border * 2);
            updated = true;
        }
    }
    return updated;
}

pub fn changeKoinePreference(
    _: *PreferencesScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) std.mem.Allocator.Error!void {
    const ctx = ac.app_context.?;

    std.debug.assert(element.type == .checkbox);
    ctx.preference.use_koine = element.type.checkbox.checked;
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
    element: *Entity,
    _: *const Event,
) std.mem.Allocator.Error!void {
    std.debug.assert(element.type == .checkbox);
    ac.app_context.?.preference.show_strongs = element.type.checkbox.checked;
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

const praxis = @import("praxis");
const Lang = praxis.Lang;

const ac = @import("App.zig");
const AppContext = ac.AppContext;

const MenuUI = @import("MenuUI.zig");
const best_width = @import("screen_parsing_menu.zig").best_width;
const PrivacyScreen = @import("PrivacyScreen.zig");
const TermsScreen = @import("TermsScreen.zig");
const show_terms_screen = @import("TermsScreen.zig").show;
const LicenseScreen = @import("LicenseScreen.zig");
const under_menu_spacing = @import("MenuUI.zig").under_menu_spacing;
