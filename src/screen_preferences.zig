var panel: *Element = undefined;
var ring_panel: *Element = undefined;
var uk_panel: *Element = undefined;
var us_panel: *Element = undefined;

/// Tap the heading 10 times to enable debug mode
var tap_counter: usize = 0;

pub fn show(display: *Display) void {
    display.choose_panel("preferences.screen");
    display.relayout();
    _ = update_ring(display, panel);
    display.need_relayout = true;
    tap_counter = 0;
}

pub fn init(context: *AppContext) !void {
    var display = context.display;

    panel = try display.root.add_alloc(context.allocator, display, .{
        .name = "preferences.screen",
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre },
        .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .visible = .hidden,
        .type = .{ .panel = .{ .spacing = 1, .direction = .top_to_bottom } },
        .on_resized = update_ring,
    });

    ring_panel = try panel.add_alloc(context.allocator, display, .{
        .name = "ring",
        .background_texture_name = "white rounded rect",
        .rect = .{ .width = 20, .height = 20 },
        .layout = .{ .position = .float, .x = .fixed, .y = .fixed },
        .type = .{ .panel = .{ .style = .emphasised } },
    });

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "preferences_heading",
        .focus = .never_focus,
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Preferences",
            .text_size = .heading,
            .text_colour = .tinted,
            .on_click = heading_tap,
        } },
        .pad = .{ .top = 30 },
    });

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "case_order_info",
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Which noun order you prefer?",
            .text_size = .normal,
            .text_colour = .normal,
        } },
    });

    const picker_panel = try panel.add_alloc(context.allocator, display, .{
        .name = "preferences.screen",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 20, .right = 20, .top = 20, .bottom = 20 },
        .minimum = .{ .width = 200, .height = 200 },
        .type = .{ .panel = .{ .spacing = 20, .direction = .left_to_right } },
    });

    us_panel = try create_picker_table(
        context.allocator,
        display,
        picker_panel,
        &[4][]const u8{ "ὁ", "τοῦ", "τῷ", "τόν" },
        &[4][]const u8{ "Θεός", "Θεοῦ", "Θεῷ", "Θεόν" },
    );
    us_panel.type.panel.on_click = choose_us_order;

    uk_panel = try create_picker_table(
        context.allocator,
        display,
        picker_panel,
        &[4][]const u8{ "ὁ", "τόν", "τοῦ", "τῷ" },
        &[4][]const u8{ "Θεός", "Θεόν", "Θεοῦ", "Θεῷ" },
    );
    uk_panel.type.panel.on_click = choose_uk_order;

    try panel.add_element(context.allocator, try engine.create_expander(
        context.allocator,
        display,
        .{
            .name = "middle.expander",
            .minimum = .{ .width = 100, .height = 5 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 1 } },
        },
    ));

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "choose_language_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "User Interface",
            .text_size = .subheading,
            .text_colour = .tinted,
        } },
    });

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "pick_language",
        .layout = .{ .x = .grows },
        .type = .{ .checkbox = .{
            .text = "Use Koine Greek UI",
            .text_size = .normal,
            .text_colour = .normal,
            .checked = ac.app_context.?.preference.use_koine,
            .on_change = change_koine_preference,
        } },
    });

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "show_strongs",
        .layout = .{ .x = .grows },
        .type = .{ .checkbox = .{
            .text = "Show Strongs Numbers",
            .text_size = .normal,
            .text_colour = .normal,
            .checked = ac.app_context.?.preference.show_strongs,
            .on_change = change_strongs_preference,
        } },
    });

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "middle.expander",
        .rect = .{ .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    });

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "choose_theme_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Theme",
            .text_size = .subheading,
            .text_colour = .tinted,
        } },
    });

    try add_theme_pickr(context.allocator, display, panel);

    _ = try panel.add_alloc(context.allocator, display, .{
        .name = "bottom.expander",
        .rect = .{ .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1 } },
    });

    const links = try panel.add_alloc(context.allocator, display, .{
        .name = "link_menu",
        .rect = .{ .width = 300, .height = 100 },
        .minimum = .{ .height = 80, .width = 300 },
        .pad = .{ .left = 20, .right = 20, .top = 20, .bottom = 20 },
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .panel = .{ .direction = .left_to_right } },
    });

    _ = try links.add_alloc(context.allocator, display, .{
        .name = "privacy.link",
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .left = 20, .right = 20 },
        .type = .{ .label = .{
            .text = "Privacy",
            .text_size = .small,
            .text_colour = .tinted,
            .on_click = show_privacy_screen,
        } },
    });

    _ = try links.add_alloc(context.allocator, display, .{
        .name = "terms.link",
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .left = 20, .right = 20 },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Terms",
            .text_size = .small,
            .text_colour = .tinted,
            .on_click = show_terms_screen,
        } },
    });

    _ = try links.add_alloc(context.allocator, display, .{
        .name = "license.link",
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .pad = .{ .left = 20, .right = 20 },
        .type = .{ .label = .{
            .text = "Licences",
            .text_size = .small,
            .text_colour = .tinted,
            .on_click = show_license_screen,
        } },
    });

    try panel.add_element(context.allocator, try engine.create_expander(
        context.allocator,
        display,
        .{
            .name = "end.expander",
            .rect = .{ .width = 100, .height = 5 },
            .minimum = .{ .width = 100, .height = 5 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 1 } },
        },
    ));

    // Don't allow expanders to push under the menu area.
    var spacer = try context.display.add_spacer(context.allocator, panel, 130);
    spacer.on_resized = MenuUI.update_bottom_spacing;
}

pub fn deinit() void {
    // No resources to deinit
}

fn add_theme_pickr(allocator: Allocator, display: *Display, parent: *Element) !void {
    var wrapper = try parent.add(allocator, try engine.create_panel(
        allocator,
        display,
        .{
            .name = "theme.picker.align",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 20, .right = 20 },
            .minimum = .{ .width = 500, .height = 20 },
            .maximum = .{ .width = 1000 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
            } },
        },
    ));

    const picker = try wrapper.add_alloc(allocator, display, .{
        .name = "theme_menu",
        .background_texture_name = "white rounded rect",
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .pad = .{ .left = 30, .right = 30, .top = 20, .bottom = 20 },
        .minimum = .{ .width = 500, .height = 20 },
        .maximum = .{ .width = 1000 },
        .type = .{ .panel = .{
            .style = .faded,
            .direction = .left_to_right,
            .spacing = 40,
        } },
    });

    _ = try picker.add_alloc(allocator, display, .{
        .name = "sand",
        .rect = .{ .width = 80, .height = 80 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon_default_name = "theme sand",
            .icon_hover_name = "theme sand",
            .icon_pressed_name = "theme sand",
            .text = "",
            .on_click = pick_theme,
            .style = .custom,
            .icon_size = .{ .x = 80, .y = 80 },
        } },
    });

    _ = try picker.add_alloc(allocator, display, .{
        .name = "white",
        .rect = .{ .width = 80, .height = 80 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon_default_name = "theme white",
            .icon_pressed_name = "theme white",
            .icon_hover_name = "theme white",
            .text = "",
            .on_click = pick_theme,
            .style = .custom,
            .icon_size = .{ .x = 80, .y = 80 },
        } },
    });

    _ = try picker.add_alloc(allocator, display, .{
        .name = "default",
        .rect = .{ .width = 80, .height = 80 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon_default_name = "theme default",
            .icon_pressed_name = "theme default",
            .icon_hover_name = "theme default",
            .text = "",
            .on_click = pick_theme,
            .style = .custom,
            .icon_size = .{ .x = 80, .y = 80 },
        } },
    });

    _ = try picker.add_alloc(allocator, display, .{
        .name = "black",
        .rect = .{ .width = 80, .height = 80 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon_default_name = "theme black",
            .icon_pressed_name = "theme black",
            .icon_hover_name = "theme black",
            .text = "",
            .on_click = pick_theme,
            .style = .custom,
            .icon_size = .{ .x = 80, .y = 80 },
        } },
    });

    _ = try picker.add_alloc(allocator, display, .{
        .name = "midnight",
        .rect = .{ .width = 80, .height = 80 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon_default_name = "theme midnight",
            .icon_pressed_name = "theme midnight",
            .icon_hover_name = "theme midnight",
            .text = "",
            .on_click = pick_theme,
            .style = .custom,
            .icon_size = .{ .x = 80, .y = 80 },
        } },
    });

    _ = try picker.add_alloc(allocator, display, .{
        .name = "garden",
        .rect = .{ .width = 80, .height = 80 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .button = .{
            .icon_default_name = "theme garden",
            .icon_pressed_name = "theme garden",
            .icon_hover_name = "theme garden",
            .text = "",
            .on_click = pick_theme,
            .style = .custom,
            .icon_size = .{ .x = 80, .y = 80 },
        } },
    });
}

pub fn heading_tap(_: *Display, _: *Element) std.mem.Allocator.Error!void {
    tap_counter += 1;
    if (tap_counter > 10) {
        tap_counter = 0;
        engine.dev_mode = !engine.dev_mode;
        info("Dev mode: {any}", .{engine.dev_mode});
    }
}

pub fn pick_theme(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    const theme = display.validate_theme(element.name);
    _ = display.set_theme(theme);
    ac.app_context.?.preference.theme = theme;
    ac.app_context.?.save_preferences();
}

pub fn create_picker_table(
    allocator: Allocator,
    display: *Display,
    parent_panel: *Element,
    articles: []const []const u8,
    words: []const []const u8,
) !*Element {
    var parsing_panel = try engine.create_panel(allocator, display, .{
        .name = "present",
        .background_texture_name = "white rounded rect",
        .focus = .can_focus,
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .child_align = .{ .x = .start, .y = .start },
        .pad = .{ .left = 28, .right = 28, .top = 20, .bottom = 20 },
        .minimum = .{ .width = 160, .height = 160 },
        .type = .{ .panel = .{
            .direction = .top_to_bottom,
        } },
    });
    try parent_panel.add_element(allocator, parsing_panel);

    for (articles, words) |article, word| {
        const row = try parsing_panel.add_alloc(allocator, display, .{
            .name = "row",
            .rect = .{ .width = 150, .height = 10 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .start, .y = .start },
            .minimum = .{ .width = 80, .height = 10 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 15,
            } },
        });

        _ = try row.add_alloc(allocator, display, .{
            .name = "col.article",
            .rect = .{ .width = 80, .height = 10 },
            .minimum = .{ .width = 80, .height = 10 },
            .type = .{ .label = .{ .text = article } },
            .child_align = .{ .x = .end, .y = .start },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .pad = .{ .left = 2, .right = 2 },
        });

        _ = try row.add_alloc(allocator, display, .{
            .name = "col.form",
            .rect = .{ .width = 150 },
            .minimum = .{ .width = 150 },
            .type = .{ .label = .{ .text = word } },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .pad = .{ .left = 2, .right = 2 },
        });
    }
    return parsing_panel;
}

pub fn choose_uk_order(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    debug("Choose UK order.", .{});
    std.debug.assert(element.type == .panel);
    ac.app_context.?.preference.uk_order = true;
    display.need_relayout = update_ring(display, element);
    ac.app_context.?.save_preferences();
}

pub fn choose_us_order(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    debug("Choose US order.", .{});
    std.debug.assert(element.type == .panel);
    ac.app_context.?.preference.uk_order = false;
    display.need_relayout = update_ring(display, element);
    ac.app_context.?.save_preferences();
}

fn update_ring(_: *Display, _: *Element) bool {
    var updated = false;
    const RING_SIZE: f32 = 5.0;
    if (ac.app_context.?.preference.uk_order) {
        if (ring_panel.rect.x != uk_panel.rect.x - RING_SIZE or ring_panel.rect.y != uk_panel.rect.y - RING_SIZE) {
            ring_panel.rect.x = uk_panel.rect.x - RING_SIZE;
            ring_panel.rect.y = uk_panel.rect.y - RING_SIZE;
            ring_panel.rect.width = uk_panel.rect.width + (RING_SIZE * 2);
            ring_panel.rect.height = uk_panel.rect.height + (RING_SIZE * 2);
            updated = true;
        }
    } else {
        if (ring_panel.rect.x != us_panel.rect.x - RING_SIZE or ring_panel.rect.y != us_panel.rect.y - RING_SIZE) {
            ring_panel.rect.x = us_panel.rect.x - RING_SIZE;
            ring_panel.rect.y = us_panel.rect.y - RING_SIZE;
            ring_panel.rect.width = us_panel.rect.width + (RING_SIZE * 2);
            ring_panel.rect.height = us_panel.rect.height + (RING_SIZE * 2);
            updated = true;
        }
    }
    return updated;
}

pub fn change_koine_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    const ctx = ac.app_context.?;
    const allocator = ctx.allocator;

    std.debug.assert(element.type == .checkbox);
    ctx.preference.use_koine = element.type.checkbox.checked;
    ctx.save_preferences();
    if (ctx.preference.use_koine) {
        try display.set_language(allocator, Lang.greek);
    } else {
        try display.set_language(allocator, Lang.english);
    }
}

pub fn change_strongs_preference(_: *Display, element: *Element) std.mem.Allocator.Error!void {
    std.debug.assert(element.type == .checkbox);
    ac.app_context.?.preference.show_strongs = element.type.checkbox.checked;
    ac.app_context.?.save_preferences();
}

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const debug = engine.debug;
const info = engine.info;
const err = engine.err;
const praxis = @import("praxis");
const Lang = praxis.Lang;
const Display = engine.Display;
const Element = engine.Element;
const MenuUI = @import("menu_ui.zig");
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const best_width = @import("screen_parsing_menu.zig").best_width;
const show_privacy_screen = @import("screen_privacy.zig").show;
const show_terms_screen = @import("screen_terms.zig").show;
const show_license_screen = @import("screen_license.zig").show;
const under_menu_spacing = @import("menu_ui.zig").under_menu_spacing;
