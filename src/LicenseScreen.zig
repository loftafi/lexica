pub const LicenseScreen = @This();

app: *App = undefined,
panel: *Entity = undefined,
back_button: *Entity = undefined,
scroller: *Entity = undefined,

debug_tap_count: u8 = 0,

pub fn show(self: *LicenseScreen, display: *Display, _: *Entity, event: *Event) Allocator.Error!void {
    try display.choosePanel("license.screen", event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .hidden;
    }
    _ = self.resizeScroller(display, self.scroller);
    display.relayout();
    self.debug_tap_count = 0;
}

pub fn init(self: *LicenseScreen, app: *App) !void {
    self.app = app;
    var display = app.display;

    _ = try display.appendPanel(
        \\panel:panel name "license.screen" spacing 10 vertical hidden choosable
        \\  layout grows grows
        \\  align centre start
        \\  minimum 100 100
        \\  pad left=1em right=1em pad top=0.5em
        \\{
        \\  button name "heading_icon" icon_default "archive icon" never_focus
        \\    layout grows shrinks
        \\    align centre centre
        \\    icon_size width=2em height=2em
        \\
        \\  label name "heading_text" text "LICENSES"
        \\    style tinted accessibility_focus
        \\    layout grows shrinks align centre centre
        \\    text_size heading
        \\    pad top=0.25em bottom=1em
        \\    on_pressed enableDebug
        \\}
    , LicenseScreen, self);

    self.back_button = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

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
            .func = @ptrCast(&resizeScroller),
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
        .style = .tinted,
        .layout = .{ .x = .grows },
        .pad = .{ .left = 11, .top = 11 },
        .type = .{ .button = .{
            .text = "Robinson Pierpoint Text",
            .text_size = .small,
            .icon = .{
                .size = .{ .width = 16, .height = 16 },
                .default_name = "small document icon",
            },
            .spacing = 4,
            .on_pressed = .{ .func = @ptrCast(&ByzScreen.show), .ptr = &app.byz },
        } },
    }, display);

    _ = try display.add_spacer(self.scroller, 30);

    try display.add_paragraph(self.scroller, .normal, "p4", "NotoSans, and NotoSansTC font used under the SIL Open font license.");

    _ = try self.scroller.add(.{
        .name = "noto.link",
        .layout = .{ .x = .grows },
        .style = .tinted,
        .pad = .{ .left = 11, .top = 11 },
        .type = .{ .button = .{
            .text = "Noto Sans and Noto Sans TC",
            .text_size = .small,
            .spacing = 4,
            .icon = .{
                .size = .{ .width = 16, .height = 16 },
                .default_name = "small document icon",
            },
            .on_pressed = .{ .func = @ptrCast(&NotoScreen.show), .ptr = &app.noto },
        } },
    }, display);
    _ = try display.add_spacer(self.scroller, 30);

    try display.add_paragraph(self.scroller, .normal, "p5", "The following libaries are also involved in the creation of this app:");

    for (engine.License.licenses) |license| {
        _ = try self.scroller.add(.{
            .name = license.library,
            .layout = .{ .x = .grows },
            .pad = .{ .left = 11, .top = 11 },
            .type = .{ .button = .{
                .text = license.library,
                .text_size = .small,
                .icon = .{
                    .size = .{ .width = 16, .height = 16 },
                    .default_name = "small document icon",
                },
                .spacing = 4,
                .on_pressed = .{ .func = @ptrCast(&LicenseInfoScreen.show), .ptr = &self.app.license_info },
            } },
        }, display);
    }
}

pub fn deinit(self: *LicenseScreen) void {
    self.* = undefined;
}

pub fn tapBack(
    self: *LicenseScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
    try display.choosePanel(self.app.preferences.panel.name, event);
}

pub fn resizeScroller(
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
    const want_scroller_height = display.root.rect.height - scroll.rect.y - menu_area - display.safe_area.bottom; // - display.safe_area.top;
    if (scroll.rect.height != want_scroller_height) {
        scroll.rect.height = want_scroller_height;
        scroll.minimum.height = scroll.rect.height;
        scroll.maximum.height = scroll.rect.height;
        updated = true;
    }
    return updated;
}

pub fn enableDebug(
    self: *LicenseScreen,
    display: *Display,
    _: *Entity,
    _: *const Event,
) Allocator.Error!void {
    _ = display;
    info("enableDebug count={d}", .{self.debug_tap_count});
    self.debug_tap_count += 1;

    if (self.debug_tap_count >= 15) {
        self.debug_tap_count = 0;
        info("enableDebug enable debug mode", .{});
        engine.dev_mode = !engine.dev_mode;
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const debug = engine.log.debug;
const info = engine.log.info;

const ac = @import("App.zig");
const App = ac.App;

const MenuUI = @import("MenuUI.zig");
const ByzScreen = @import("ByzScreen.zig");
const NotoScreen = @import("NotoScreen.zig");
const SDLScreen = @import("SDLScreen.zig");
const LicenseInfoScreen = @import("LicenseInfoScreen.zig");
