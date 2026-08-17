//! Display the privacy policy for this version of the app.
pub const PrivacyScreen = @This();

panel: *Entity = undefined,
back_button: *Entity = undefined,
scroller: *Entity = undefined,
app: *AppContext = undefined,

pub fn show(
    self: *PrivacyScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    try display.choosePanel("privacy.screen", event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .hidden;
    }
    _ = self.vertical_scroller_resize(display, self.scroller);
    display.relayout();
}

pub fn init(self: *PrivacyScreen, context: *AppContext) !void {
    self.app = context;

    var display = context.display;

    self.panel = try display.addPanel(
        .{
            .name = "privacy.screen",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .visible = .hidden,
            .type = .{ .panel = .{
                .spacing = 10,
                .direction = .top_to_bottom,
                .choosable = .choosable,
            } },
        },
    );

    self.back_button = try self.app.add_back_button(self.panel, .{
        .func = @ptrCast(&close_me),
        .ptr = self,
    });

    var heading = try self.panel.add(.{
        .name = "privacy_heading",
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Privacy",
            .text_size = .heading,
        } },
    }, display);
    heading.pad.top = 30;

    _ = try display.add_spacer(self.panel, 60);

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre, .y = .start },
        .minimum = .{ .height = 600 },
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
        .on_resized = .{ .func = @ptrCast(&vertical_scroller_resize), .ptr = self },
    }, display);

    try display.add_paragraph(self.scroller, .normal, "p1", "By using this app, you consent to this privacy policy and the terms of service.");
    try display.add_paragraph(self.scroller, .normal, "p2", "This app does not collect any personal identifying information or usage information.");
    try display.add_paragraph(self.scroller, .normal, "p3", "This app does not share any personal or usage information off your device.");
    try display.add_paragraph(self.scroller, .normal, "p4", "If new features are added that collect feedback or other types of information, it will be optional, and only be done after requesting your consent.");
    try display.add_paragraph(self.scroller, .normal, "p5", "Basic information about downloads or purchases through app stores are recorded by the app store provider and is used for accounting purposes.");
    try display.add_paragraph(self.scroller, .normal, "p6", "Questions about this privacy policy may be directed to the official social media accounts for this app.");
}

pub fn deinit(self: *PrivacyScreen) void {
    self.* = undefined;
}

pub fn close_me(
    _: *PrivacyScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
    try display.choosePanel("preferences.screen", event);
}

pub fn vertical_scroller_resize(
    _: *PrivacyScreen,
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

const praxis = @import("praxis");

const ac = @import("App.zig");
const AppContext = ac.AppContext;
const MenuUI = @import("MenuUI.zig");
