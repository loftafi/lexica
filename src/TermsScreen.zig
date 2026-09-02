//! Display the terms and conditions as at the date this version was released.
pub const TermsScreen = @This();

app: *AppContext = undefined,
panel: *Entity = undefined,
back_button: *Entity = undefined,
scroller: *Entity = undefined,

pub fn show(
    self: *TermsScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) std.mem.Allocator.Error!void {
    try display.choosePanel(self.panel.name, event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .hidden;
    }
    _ = self.resizeScroller(display, self.scroller);
    display.need_relayout = true;
}

pub fn init(self: *TermsScreen, app: *AppContext) !void {
    self.app = app;
    var display = app.display;

    _ = try display.appendPanel(
        \\panel:panel name "terms.screen" spacing 10 vertical hidden
        \\  choosable avoid_safe_area
        \\  layout grows grows
        \\  align centre start
        \\  minimum 100 100
        \\  pad left=1em right=1em pad top=1.5em
        \\{
        \\  button name "heading_icon" icon_default "document icon" never_focus
        \\    layout grows shrinks
        \\    align centre centre
        \\    icon_size width=2em height=2em
        \\
        \\  label name "heading_text" text "TERMS_OF_USE"
        \\    style tinted accessibility_focus
        \\    layout grows shrinks align centre centre
        \\    text_size heading
        \\    pad top=0.25em bottom=1em
        \\}
    , TermsScreen, self);

    self.back_button = try ac.app_context.?.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows, .y = .shrinks },
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
        .on_resized = .{ .func = @ptrCast(&resizeScroller), .ptr = self },
    }, display);

    const app_name = app.display.config.app_name orelse "This app";
    const app_owner = "the author";

    try display.add_paragraph(self.scroller, .normal, "p1", "By using this app, you consent to these terms of service and the privacy policy.");
    try display.add_paragraph(self.scroller, .normal, "p2", display.bucket.addFields("{app_name} is licensed, not sold, to you. Your license to use {app_name} is subject to prior acceptence of these terms and conditions. You are granted limited, non-exclusive revocable permission to use {app_name} for personal and/or educational and/or as one element of a wider commercial purpose. Permission shall remain in effect unless permission is terminated by you or by {app_owner}.", .{ .app_name = app_name, .app_owner = app_owner }) catch "");
    try display.add_paragraph(self.scroller, .normal, "p3", display.bucket.addFields("{app_name} is provided on an \"AS IS\" basis. No warranty of any kind is given or implied. There is no warranty that this app is free from error, fit for purpose, or will continue to be available in the future.", .{ .app_name = app_name }) catch "");
    try display.add_paragraph(self.scroller, .normal, "p4", display.bucket.addFields("To the maximum extent permitted by law, {app_owner} and its agents shall not be liable for any indirect, incidental, special, consequential or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses, resulting from (a) your access to or use of or inability to access or use this service; (b) any conduct or content of any third party on the service, including without limitation, any defamatory, offensive, or illegal conduct of other useers or third parties; or (c) unauthorised access, use, or alteration of your transmissions or content. In no event shall {app_owner} or its agents aggregate liability for all claims relating to the service exceed the price you paid {app_owner} to use this service.", .{ .app_owner = app_owner }) catch "");
    try display.add_paragraph(self.scroller, .normal, "p5", display.bucket.addFields("{app_name} will continue to improve and evolve over time. We may modify, suspend, or stop providing any or all parts of this service at any time.", .{ .app_name = app_name }) catch "");
    try display.add_paragraph(self.scroller, .normal, "p6", "If it is not possible for a child or their guardian to legally consent to data being used according the privacy policy, or if it is not legal for an entity to use this data according to the privacy policy, you are not authorised to commence or continue to use this application, the license to use this application is revoked.");
    try display.add_paragraph(self.scroller, .normal, "p7", "If you are not sure of your ability to consent, you are not authorised to commence or continue to use this application until you are certain you are able to legally consent.");
}

pub fn deinit(self: *TermsScreen) void {
    self.* = undefined;
}

pub fn tapBack(
    self: *TermsScreen,
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
    _: *TermsScreen,
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
