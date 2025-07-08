//! Display the terms and conditions as at the date this version was released.

var panel: *Element = undefined;
pub var back_button: *Element = undefined;
pub var scroller: *Element = undefined;

pub fn show(display: *Display, _: *Element) std.mem.Allocator.Error!void {
    init(ac.app_context.?) catch {
        return;
    };
    display.choose_panel("terms.screen");
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .hidden;
    }
    _ = vertical_scroller_resize(display, scroller);
    display.need_relayout = true;
}

pub fn init(context: *AppContext) !void {
    var display = context.display;
    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "terms.screen",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .visible = .hidden,
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        },
    ));

    back_button = try display.add_back_button(panel, close_me);

    var heading = try panel.add(try engine.create_label(
        display,
        "",
        .{
            .name = "terms_heading",
            .layout = .{ .y = .shrinks, .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Terms",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    ));
    heading.pad.top = 30;
    heading.pad.bottom = 5;

    _ = try display.add_spacer(panel, 60);

    scroller = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 600, .height = 500 },
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
            .on_resized = vertical_scroller_resize,
        },
    );
    try panel.add_element(scroller);

    try display.add_paragraph(scroller, .normal, "p1", "By using this app, you consent to these terms of service and the privacy policy.");
    try display.add_paragraph(scroller, .normal, "p2", APP_NAME ++ " is licensed, not sold, to you. Your license to use " ++ APP_NAME ++ " is subject to prior acceptence of these terms and conditions. You are granted limited, non-exclusive revocable permission to use " ++ APP_NAME ++ " for personal and/or educational and/or as one element of a wider commercial purpose. Permission shall remain in effect unless permission is terminated by you or by " ++ APP_OWNER ++ ".");
    try display.add_paragraph(scroller, .normal, "p3", APP_NAME ++ " is provided on an \"AS IS\" basis. No warranty of any kind is given or implied. There is no warranty that this app is free from error, fit for purpose, or will continue to be available in the future.");
    try display.add_paragraph(scroller, .normal, "p4", "To the maximum extent permitted by law, " ++ APP_OWNER ++ " and its agents shall not be liable for any indirect, incidental, special, consequential or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses, resulting from (a) your access to or use of or inability to access or use this service; (b) any conduct or content of any third party on the service, including without limitation, any defamatory, offensive, or illegal conduct of other useers or third parties; or (c) unauthorised access, use, or alteration of your transmissions or content. In no event shall " ++ APP_OWNER ++ " or its agents aggregate liability for all claims relating to the service exceed the price you paid " ++ APP_OWNER ++ " to use this service.");
    try display.add_paragraph(scroller, .normal, "p5", APP_NAME ++ " will continue to improve and evolve over time. We may modify, suspend, or stop providing any or all parts of this service at any time.");
    try display.add_paragraph(scroller, .normal, "p6", "If it is not possible for a child or their guardian to legally consent to data being used according the privacy policy, or if it is not legal for an entity to use this data according to the privacy policy, you are not authorised to commence or continue to use this application, the license to use this application is revoked.");
    try display.add_paragraph(scroller, .normal, "p7", "If you are not sure of your ability to consent, you are not authorised to commence or continue to use this application until you are certain you are able to legally consent.");
}

pub fn deinit() void {
    const display = ac.app_context.?.display;
    _ = display.root.remove_element(display, panel);
    panel.destroy(display, display.allocator);
    panel = undefined;
}

pub fn close_me(display: *Display, _: *Element) Allocator.Error!void {
    deinit();
    if (display.root.get_child_by_name("menu")) |child| {
        child.visible = .visible;
    }
    display.choose_panel("preferences.screen");
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const praxis = @import("praxis");
const Display = engine.Display;
const Element = engine.Element;
const ac = @import("app_context.zig");
const APP_NAME = ac.APP_NAME;
const APP_OWNER = "the author";
const AppContext = ac.AppContext;
const vertical_scroller_resize = @import("screen_search.zig").vertical_scroller_resize;
