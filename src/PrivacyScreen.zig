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
    _ = self.resizeScroller(display, self.scroller);
}

pub fn init(self: *PrivacyScreen, context: *AppContext) !void {
    self.app = context;

    var display = context.display;

    _ = try display.appendPanel(
        \\panel:panel name "privacy.screen" spacing 10 vertical hidden
        \\  choosable avoid_safe_area
        \\  layout grows grows
        \\  align centre start
        \\  minimum 100 100
        \\  pad left=1em right=1em pad top=0.5em
        \\{
        \\  button name "heading_icon" icon_default "icon shield" never_focus
        \\    layout grows shrinks
        \\    align centre centre
        \\    icon_size width=2em height=2em
        \\
        \\  label name "heading_text" text "PRIVACY_POLICY"
        \\    style tinted accessibility_focus
        \\    layout grows shrinks align centre centre
        \\    text_size heading
        \\    pad top=0.25em bottom=1em
        \\}
    , PrivacyScreen, self);

    self.back_button = try self.app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

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
        .on_resized = .{ .func = @ptrCast(&resizeScroller), .ptr = self },
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

pub fn tapBack(
    self: *PrivacyScreen,
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
