//! Display required information about the noto font.
pub const NotoScreen = @This();

app: *App = undefined,
panel: *Entity = undefined,

pub var back_button: *Entity = undefined;
pub var scroller: *Entity = undefined;

pub fn show(
    self: *NotoScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) std.mem.Allocator.Error!void {
    try display.choosePanel(self.panel.name, event);
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .hidden;
    }
    _ = self.vertical_scroller_resize(display, scroller);
    display.need_relayout = true;
}

pub fn init(self: *NotoScreen, app: *App) !void {
    self.app = app;
    var display = app.display;

    self.panel = try display.addPanel(.{
        .name = "noto.info",
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

    back_button = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    _ = try self.panel.add(.{
        .name = "noto_heading",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "Noto Sans and Noto Sans TC",
            .text_size = .heading,
        } },
        .pad = .{ .top = 10 },
    }, display);

    _ = try display.add_spacer(self.panel, 60);

    scroller = try self.panel.add(.{
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
        .on_resized = .{ .func = @ptrCast(&vertical_scroller_resize), .ptr = self },
    }, display);

    try display.add_paragraph(scroller, .normal, "p1", "Noto Sans and Noto Sans TC are licensed under SIL Open Font License version 1.1:");
    try display.add_paragraph(scroller, .normal, "p2", "Copyright 2022 The Noto Project Authors https://github.com/notofonts/latin-greek-cyrillic");
    try display.add_paragraph(scroller, .normal, "p3", "This Font Software is licensed under the SIL Open Font License, Version 1.1.");
    try display.add_paragraph(scroller, .normal, "p4", "This license is copied below, and is also available with a FAQ at: http://scripts.sil.org/OFL");
    try display.add_paragraph(scroller, .normal, "p5", "SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007");
    try display.add_paragraph(scroller, .subheading, "p6", "PREAMBLE");
    try display.add_paragraph(scroller, .normal, "p7", "The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.");
    try display.add_paragraph(scroller, .normal, "p8", "The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software provided that any reserved names are not used by derivative works. The fonts and derivatives, however, cannot be released under any other type of license. The requirement for fonts to remain under this license does not apply to any document created using the fonts or their derivatives.");
    try display.add_paragraph(scroller, .subheading, "p9", "DEFINITIONS");
    try display.add_paragraph(scroller, .normal, "p10", "\"Font Software\" refers to the set of files released by the Copyright Holder(s) under this license and clearly marked as such. This may include source files, build scripts and documentation.");
    try display.add_paragraph(scroller, .normal, "p11", "\"Reserved Font Name\" refers to any names specified as such after the copyright statement(s).");
    try display.add_paragraph(scroller, .normal, "p12", "\"Original Version\" refers to the collection of Font Software components as distributed by the Copyright Holder(s).");
    try display.add_paragraph(scroller, .normal, "p13", "\"Modified Version\" refers to any derivative made by adding to, deleting, or substituting -- in part or in whole -- any of the components of the Original Version, by changing formats or by porting the Font Software to a new environment.");
    try display.add_paragraph(scroller, .normal, "p14", "\"Author\" refers to any designer, engineer, programmer, technical writer or other person who contributed to the Font Software.");
    try display.add_paragraph(scroller, .subheading, "p15", "PERMISSION & CONDITIONS");
    try display.add_paragraph(scroller, .normal, "p16", "Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font Software, subject to the following conditions:");
    try display.add_paragraph(scroller, .normal, "p17", "1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be sold by itself.");
    try display.add_paragraph(scroller, .normal, "p18", "2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license. These can be included either as stand-alone text files, human-readable headers or in the appropriate machine-readable metadata fields within text or binary files as long as those fields can be easily viewed by the user.");
    try display.add_paragraph(scroller, .normal, "p19", "3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written permission is granted by the corresponding Copyright Holder. This restriction only applies to the primary font name as presented to the users.");
    try display.add_paragraph(scroller, .normal, "p20", "4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font Software shall not be used to promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with their explicit written permission.");
    try display.add_paragraph(scroller, .normal, "p21", "5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this license, and must not be distributed under any other license. The requirement for fonts to remain under this license does not apply to any document created using the Font Software.");
    try display.add_paragraph(scroller, .subheading, "p22", "TERMINATION");
    try display.add_paragraph(scroller, .normal, "p23", "This license becomes null and void if any of the above conditions are not met.");
    try display.add_paragraph(scroller, .subheading, "p24", "DISCLAIMER");
    try display.add_paragraph(scroller, .normal, "p25", "THE FONT SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.");
}

pub fn deinit(self: *NotoScreen) void {
    self.* = undefined;
}

pub fn tapBack(
    _: *NotoScreen,
    display: *Display,
    _: *Entity,
    event: *Event,
) Allocator.Error!void {
    if (display.root.getChildByName("menu")) |child| {
        child.visible = .visible;
    }
    try display.choosePanel("license.screen", event);
}

pub fn vertical_scroller_resize(
    _: *NotoScreen,
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

const std = @import("std");
const Allocator = std.mem.Allocator;

const praxis = @import("praxis");
const Lang = praxis.Lang;

const engine = @import("engine");
const debug = engine.log.debug;
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;
const TextSize = engine.TextSize;

const ac = @import("App.zig");
const App = ac.App;
const APP_NAME = ac.APP_NAME;
const APP_OWNER = "the author";
const Theme = ac.Theme;
const add_spacer = @import("LicenseScreen.zig").add_spacer;

const MenuUI = @import("MenuUI.zig");
