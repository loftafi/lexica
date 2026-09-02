/// Display required information about the specific license.
pub const LicenseInfoScreen = @This();

pub var panel_name = "license.info";

app: *App = undefined,
panel: *Entity = undefined,
back_button: *Entity = undefined,
scroller: *Entity = undefined,
heading: *Entity = undefined,
subheading: *Entity = undefined,

license: *const engine.License = undefined,

/// Initialise any required panels with `display.addPanel()`, and/or
/// report a future need for a specific image or audio resource with
/// `display.requireResourceRecord()`
///
/// `init()` should return quickly to avoid delay of application startup.
pub fn init(
    self: *LicenseInfoScreen,
    app: *App,
    display: *Display,
) (Allocator.Error || Resources.Error || engine.Error)!void {
    // Lazy initialisation. Don'actually init on startup. Only init if needed
    self.app = app;

    _ = try display.appendPanel(
        \\panel:panel name "license.info" spacing 11 vertical hidden choosable
        \\  layout grows grows align centre start
        \\  minimum 100 100
        \\  pad left=1em right=1em pad top=0.5em
        \\{
        \\  label:heading name "heading" text "Heading"
        \\    style tinted
        \\    layout grows shrinks align centre centre
        \\    text_size heading
        \\    pad top=0.25em bottom=0.25em
        \\
        \\  label:subheading name "subheading" text "Subheading"
        \\    style tinted
        \\    layout grows shrinks align centre centre
        \\    text_size subheading
        \\    pad top=0.25em bottom=1em
        \\}
    , LicenseInfoScreen, self);

    self.back_button = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&LicenseScreen.show),
        .ptr = &app.license,
    });

    self.scroller = try self.panel.add(.{
        .name = "scroll.panel",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .minimum = .{ .width = 100, .height = 100 },
        .type = .{
            .panel = .{
                .scrollable = .{
                    .scroll = .{ .x = false, .y = true },
                    .size = .{ .width = 600, .height = 600 },
                },
                .direction = .top_to_bottom,
                .spacing = 22,
            },
        },
        .on_resized = .{ .func = @ptrCast(&scroller_resize), .ptr = self },
    }, display);
}

pub fn deinit(self: *LicenseInfoScreen) void {
    self.* = undefined;
}

fn setup(self: *LicenseInfoScreen, display: *Display, license: *const engine.License) (Allocator.Error || Resources.Error || engine.Error)!void {
    try self.heading.setText(display, self.license.library);
    try self.subheading.setText(display, self.license.contents);

    self.scroller.removeEntities(display);

    var i = std.mem.tokenizeSequence(u8, license.license, "\n\n");
    while (i.next()) |paragraph| {
        try display.add_paragraph(self.scroller, .normal, "p1", paragraph);
    }
}

/// Show can be triggered by a keypress or mouse interaction. It is a `Callback`
/// event handler that expects `display`, `element`, and `allocator` parameters.
pub fn show(
    self: *LicenseInfoScreen,
    display: *Display,
    entity: *Entity,
    event: *const Event,
) Allocator.Error!void {
    var found: ?*const engine.License = null;

    for (engine.License.licenses) |*license| {
        if (std.mem.eql(u8, entity.name, license.library))
            found = license;
    }

    if (found == null) {
        err("License {s} not found.", .{entity.name});
        return;
    }
    self.license = found.?;

    self.setup(display, self.license) catch return;

    try display.choosePanel(panel_name, event);
    //try self.app.show_reader_menu();

    _ = self.scroller_resize(display, self.scroller);
}

pub fn scroller_resize(self: *LicenseInfoScreen, display: *Display, _: *Entity) bool {
    var scroll = self.scroller;
    const shrink = -40;
    var updated = false;

    const menu_area = MenuUI.menubar_height();
    debug("handle resize. menu_height={d} root.height={d} scroller.top={d}, safe.top={d}, safe.bottom={d}", .{
        menu_area,
        display.root.rect.height,
        scroll.rect.y,
        display.safe_area.top,
        display.safe_area.bottom,
    });
    const want_scroller_height = display.root.rect.height -
        scroll.rect.y -
        menu_area -
        //display.safe_area.bottom -
        //display.safe_area.top -
        shrink;
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
const TextSize = engine.TextSize;
const err = engine.log.err;
const debug = engine.log.debug;
const License = engine.License;
const Resources = @import("resources").Resources;
const MenuUI = @import("MenuUI.zig");

const ac = @import("App.zig");
const App = ac.AppContext;

const LicenseScreen = @import("LicenseScreen.zig");
