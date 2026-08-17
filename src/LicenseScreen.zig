pub const LicenseScreen = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,
back_button: *Entity = undefined,
scroller: *Entity = undefined,

pub fn show(self: *LicenseScreen, display: *Display, _: *Entity, event: *Event) Allocator.Error!void {
    try display.choosePanel("license.screen", event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .hidden;
    }
    _ = self.vertical_scroller_resize(display, self.scroller);
    display.relayout();
}

pub fn init(self: *LicenseScreen, app: *AppContext) !void {
    self.app = app;
    var display = app.display;

    self.panel = try display.addPanel(.{
        .name = "license.screen",
        .rect = .{ .x = 0, .y = 0 },
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .visible = .hidden,
        .type = .{ .panel = .{
            .spacing = 10,
            .direction = .top_to_bottom,
            .choosable = .choosable,
        } },
    });

    self.back_button = try ac.app_context.?.add_back_button(self.panel, .{
        .func = @ptrCast(&close_me),
        .ptr = self,
    });

    _ = try self.panel.add(.{
        .name = "licenses_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Resources",
            .text_size = .heading,
        } },
        .pad = .{ .top = 30 },
    }, display);

    _ = try display.add_spacer(self.panel, 60);

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .minimum = .{ .height = 500 },
        .type = .{
            .panel = .{
                .scrollable = .{
                    .scroll = .{ .x = false, .y = true },
                    .size = .{ .width = 600, .height = 600 },
                },
                .direction = .top_to_bottom,
                .spacing = 2,
            },
        },
        .on_resized = .{
            .func = @ptrCast(&vertical_scroller_resize),
            .ptr = self,
        },
    }, display);

    try display.add_paragraph(self.scroller, .normal, "p1", "To support the goal that these resources should be available free of charge and restriction. This app only uses or supports components and resources that are available under a public domain or comparable license (i.e. MIT, CC0, ZLIB).");
    _ = try display.add_spacer(self.scroller, 60);

    try display.add_paragraph(self.scroller, .normal, "p2", "Koine Greek glosses are public domain. They are a combination of public domain sources and original work of the author.");
    _ = try display.add_spacer(self.scroller, 30);

    try display.add_paragraph(self.scroller, .normal, "p3", "Hand and computer generated parsing data is combined with the public domain Robinson and Pierpoint Byzantine text.");

    _ = try self.scroller.add(.{
        .name = "byz.link",
        .layout = .{ .x = .grows },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Robinson Pierpoint Text",
            .text_size = .small,
            .on_pressed = .{ .func = @ptrCast(&ByzScreen.show), .ptr = &app.byz },
        } },
    }, display);

    _ = try display.add_spacer(self.scroller, 30);

    try display.add_paragraph(self.scroller, .normal, "p4", "NotoSans, and NotoSansTC font used under the SIL Open font license.");

    _ = try self.scroller.add(.{
        .name = "noto.link",
        .layout = .{ .x = .grows },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Noto Sans and Noto Sans TC",
            .text_size = .small,
            .on_pressed = .{ .func = @ptrCast(&NotoScreen.show), .ptr = &app.noto },
        } },
    }, display);
    _ = try display.add_spacer(self.scroller, 30);

    try display.add_paragraph(self.scroller, .normal, "p5", "SDL3 is used under the zlib license.");
    _ = try self.scroller.add(.{
        .name = "sdl.link",
        .layout = .{ .x = .grows },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "SDL 3.0 License",
            .text_size = .small,
            .on_pressed = .{ .func = @ptrCast(&SDLScreen.show), .ptr = &app.sdl },
        } },
    }, display);
}

pub fn deinit(self: *LicenseScreen) void {
    self.* = undefined;
}

pub fn close_me(_: *LicenseScreen, display: *Display, _: *Entity, event: *Event) Allocator.Error!void {
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
    try display.choosePanel("preferences.screen", event);
}

pub fn vertical_scroller_resize(
    _: *LicenseScreen,
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

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const debug = engine.log.debug;

const ac = @import("App.zig");
const AppContext = ac.AppContext;

const MenuUI = @import("MenuUI.zig");
const best_width = @import("screen_parsing_menu.zig").best_width;
const ByzScreen = @import("ByzScreen.zig");
const NotoScreen = @import("NotoScreen.zig");
const SDLScreen = @import("SDLScreen.zig");
