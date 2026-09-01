//! Main entry point for the dictionary application.
//!
//! This is used to setup all of the screens/scenes, then enter
//! the main loop once all data is loaded.

pub const APP_PAD = 25;
pub const APP_MINIMUM_WIDTH = 390;
pub const APP_MINIMUM_HEIGHT = 600;
pub const APP_MAXIMUM_WIDTH = 1000;
pub const MAX_SEARCH_HISTORY = @import("SearchScreen.zig").MAX_SEARCH_RESULTS;
pub const MAX_PANEL_TABLES: usize = 20;

pub const study_optative = false;

pub var app_context: ?*AppContext = null;
pub var writing_enabled = true;

pub const AppContext = struct {

    // Global app variables
    allocator: Allocator,
    io: std.Io,
    display: *Display = undefined,
    theme: []const u8 = "",

    dictionary: *Dictionary = undefined,
    dictionary_arena: std.heap.ArenaAllocator = undefined,

    byz: ByzScreen = undefined,
    license: LicenseScren = undefined,
    list_delete: ListDeleteScreen = undefined,
    list_edit: ListEditScreen = undefined,
    list_new: ListNewScreen = undefined,
    menu_ui: MenuUI = undefined,
    noto: NotoScreen = undefined,
    parsing_card: ParsingCardScreen = undefined,
    parsing_menu: ParsingMenuScreen = undefined,
    parsing_setup: ParsingSetupScreen = undefined,
    preferences: PreferencesScreen = undefined,
    privacy: PrivacyScreen = undefined,
    terms: TermsScreen = undefined,
    sdl: SDLScreen = undefined,
    search_screen: SearchScreen = undefined,
    word_info: WordInfoScreen = undefined,

    // Word info screen data
    word_lexeme: ?*praxis.Lexeme = null,
    panels: *Panels = undefined,
    panel_tables: [MAX_PANEL_TABLES]*Entity = undefined,

    parsing_quiz: ParsingQuiz = undefined,

    bucket: StringBucket,
    lists: Lists,

    preference: struct {
        uk_order: bool = true,
        use_koine: bool = false,
        show_strongs: bool = false,
        accessibility: bool = false,
        size: Scale = .normal,
        theme: []const u8 = "",

        present_future: bool = true,
        imperfect: bool = false,
        perfect_pluperfect: bool = false,
        aorist: bool = false,
        nominative_accusative: bool = true,
        genitive_dative: bool = false,
        mi: bool = false,
        third_declension: bool = false,
        middle_passive: bool = false,
        indicative: bool = true,
        imperative: bool = false,
        participle: bool = false,
        subjunctive: bool = false,
        optative: bool = false,
        infinitive: bool = false,
    },

    /// Words that were tapped to be viewed
    view_history: std.ArrayListUnmanaged(*praxis.Form),

    data_loaded_event: u32,

    // Complete all setup needed to get to the blank startup screen.
    // Setup continues on in a background thread so that initial startup
    // screen drawing may occur.
    pub fn create(
        gpa: Allocator,
        io: std.Io,
        config: *engine.Config,
    ) (engine.Error || Allocator.Error || error{
        ThreadCreationFailed,
        Utf8ExpectedContinuation,
        Utf8OverlongEncoding,
        Utf8EncodesSurrogateHalf,
        Utf8CodepointTooLarge,
        Utf8InvalidStartByte,
        FailedReadingTimezone,
        ObjCFailure,
        AndroidFailure,
    } || Resources.Error || std.Io.File.OpenError || std.Io.File.StatError)!*AppContext {
        info("Starting app {s} {s}", .{ config.app_name orelse "", config.app_build orelse "" });
        var ac = try gpa.create(AppContext);
        errdefer gpa.destroy(ac);
        ac.allocator = gpa;
        ac.io = io;
        ac.word_lexeme = null;
        ac.view_history = .empty;
        ac.bucket = .init(gpa);
        try ac.parsing_quiz.init(gpa);
        errdefer ac.view_history.deinit(gpa);
        ac.panels = try Panels.create(gpa);
        errdefer ac.panels.destroy(gpa);

        ac.display = try Display.create(
            gpa,
            io,
            config.*,
        );
        errdefer ac.display.destroy();

        debug("Loading preferences", .{});
        try ac.load_preferences();
        debug("Apply preferences", .{});
        if (ac.preference.use_koine) {
            try ac.display.setLanguage(Lang.greek);
        } else {
            try ac.display.setLanguage(Lang.english);
        }
        ac.display.setUserScale(ac.preference.size);
        _ = try ac.display.setTheme(ac.preference.theme);
        debug("Loaded preferences. Scale={d}/{s}", .{ ac.display.user_scale, @tagName(ac.preference.size) });

        app_context = ac;
        errdefer app_context = null;

        // Placeholder for the dictionary in case this object is destroyed later
        ac.dictionary_arena = std.heap.ArenaAllocator.init(gpa);
        errdefer ac.dictionary_arena.deinit();
        ac.dictionary = try Dictionary.create(ac.dictionary_arena.allocator());
        errdefer ac.dictionary.destroy();
        ac.lists = Lists.init(ac.dictionary);

        debug("Setup resource loading thread", .{});
        ac.display.setEventHook(ac, @ptrCast(&eventHook));
        ac.data_loaded_event = ac.display.registerEventHook();

        var a = io.async(loadDictionary, .{ gpa, io, ac });
        defer _ = a.cancel(io);

        try ac.setup_screens();

        // Display window can now be created and drawn with the initial
        // `background_screen`
        ac.display.initial_draw() catch |f| {
            err("initial draw failed {any}", .{f});
            return f;
        };

        return ac;
    }

    pub fn destroy(ac: *AppContext) void {
        if (ac.dictionary.lexemes.count() > 0) {
            debug("cleanup screens, dictionary was loaded with {d} records", .{ac.dictionary.lexemes.count()});
            ac.parsing_setup.deinit();
            ac.search_screen.deinit(ac.allocator);
            ac.list_edit.deinit(ac.allocator);
            ac.word_info.deinit();
        }
        ac.view_history.deinit(ac.allocator);
        ac.display.destroy();
        ac.panels.destroy(ac.allocator);
        ac.parsing_quiz.deinit(ac.allocator);
        ac.privacy.deinit();
        ac.license.deinit();
        ac.terms.deinit();
        ac.byz.deinit();
        ac.noto.deinit();
        ac.sdl.deinit();
        ac.lists.deinit(ac.allocator);

        ac.dictionary.destroy();
        ac.dictionary_arena.deinit();

        const allocator = ac.allocator;
        ac.* = undefined;
        allocator.destroy(ac);
    }

    fn eventHook(self: *AppContext, _: Allocator, e: u32) Allocator.Error!void {

        // Is the event the 'data loaded' event?
        if (e == self.data_loaded_event) {
            trace("SDL event hook called {any}", .{e});
            sdl.SDL_PumpEvents();
            self.enableScreens() catch |er| {
                err("Enable main screens failed. {any}", .{er});
            };
        } else {
            trace("SDL event hook ignoring {any}", .{e});
        }
    }

    pub fn setup_screens(ac: *AppContext) !void {

        // Load fonts after screen initialisation so that the
        // screen pixel density can be accounted for.
        var start = std.Io.Timestamp.now(ac.io, .real).toMilliseconds();
        _ = try ac.display.setDefaultFont("NotoSans-Regular", .unknown, .{});
        _ = try ac.display.setDefaultFont("NotoSans-Regular", .english, .{});
        _ = try ac.display.setDefaultFont("NotoSansKR-VF", .korean, .{});
        _ = try ac.display.setDefaultFont("NotoSans-Regular", .greek, .{});
        var end = std.Io.Timestamp.now(ac.io, .real).toMilliseconds();
        info("Font load time {d}ms.", .{end - start});

        start = std.Io.Timestamp.now(ac.io, .real).toMilliseconds();
        try ac.menu_ui.init(ac);
        errdefer ac.menu_ui.deinit();

        try ac.search_screen.init(ac);
        errdefer ac.search_screen.deinit(ac.allocator);

        try ac.preferences.init(ac);
        errdefer ac.preferences.deinit();

        try ac.parsing_menu.init(ac);
        errdefer ac.parsing_menu.deinit();

        try ac.privacy.init(ac);
        errdefer ac.privacy.deinit();

        try ac.parsing_setup.init(ac);
        errdefer ac.parsing_setup.deinit();

        try ac.parsing_card.init(ac);
        errdefer ac.parsing_card.deinit();

        try ac.word_info.init(ac);
        errdefer ac.word_info.deinit();

        try ac.license.init(ac);
        errdefer ac.license.deinit();

        try ac.terms.init(ac);
        errdefer ac.terms.deinit();

        try ac.list_new.init(ac);
        errdefer ac.list_new.deinit();

        try ac.list_delete.init(ac);
        errdefer ac.list_delete.deinit();

        try ac.list_edit.init(ac);
        errdefer ac.list_edit.deinit(ac.display.allocator);

        try ac.byz.init(ac);
        errdefer ac.byz.deinit();

        try ac.noto.init(ac);
        errdefer ac.noto.deinit();

        try ac.sdl.init(ac);
        errdefer ac.sdl.deinit();

        end = std.Io.Timestamp.now(ac.io, .real).toMilliseconds();
        info("Screens initialised in {d}ms.", .{end - start});
    }

    pub fn enableScreens(ac: *AppContext) !void {
        info("Enabling screens", .{});
        debug("Loading view history", .{});
        app_context.?.loadViewHistory(app_context.?.dictionary) catch |e| {
            err("Error reading view history file. {any}", .{e});
            return;
        };
        debug("loaded view history.", .{});
        try ac.search_screen.show_search_history(ac.display);

        debug("Loading word lists", .{});
        app_context.?.lists.load(ac.display.allocator, &ac.display.config) catch |e| {
            err("Error reading word lists. {any}", .{e});
            return;
        };

        debug("Loaded word lists.", .{});
        try ac.search_screen.show_search_history(ac.display);

        debug("Adding keybindings.", .{});
        try ac.display.setKeybinding(.space, .{ .func = @ptrCast(&pick_search_screen), .ptr = ac });
        try ac.display.setKeybinding(.s, .{ .func = @ptrCast(&pick_search_screen), .ptr = ac });
        try ac.display.setKeybinding(.p, .{ .func = @ptrCast(&pick_preferences_screen), .ptr = ac });
        try ac.display.setKeybinding(.q, .{ .func = @ptrCast(&pick_parsing_screen), .ptr = ac });

        if (engine.dev_build) {
            try ac.display.setKeybinding(.m, .{ .func = @ptrCast(&toggle_menu), .ptr = ac });
        }

        if (builtin.target.os.tag != .ios and
            !builtin.target.abi.isAndroid())
        {
            try ac.display.setKeybinding(.escape, .{ .func = @ptrCast(&escape_quit), .ptr = ac });
        }
        try ac.display.setKeybinding(.ac_back, .{ .func = @ptrCast(&android_back), .ptr = ac });

        if (ac.display.getPanel("menu")) |menu| {
            menu.visible = .visible;
        }
        try ac.display.choosePanel("search.screen", &.{});
        ac.display.relayout();
    }

    pub fn save_preferences(self: *AppContext) void {
        var data = std.ArrayList(u8).initCapacity(self.allocator, 5000) catch {
            warn("Save preferences out of memory.", .{});
            return;
        };
        defer data.deinit(self.allocator);

        data.appendSliceAssumeCapacity("show_strongs=");
        if (self.preference.show_strongs) {
            data.appendSliceAssumeCapacity("true\n");
        } else {
            data.appendSliceAssumeCapacity("false\n");
        }

        data.appendSliceAssumeCapacity("use_koine=");
        if (self.preference.use_koine) {
            data.appendSliceAssumeCapacity("true\n");
        } else {
            data.appendSliceAssumeCapacity("false\n");
        }

        data.appendSliceAssumeCapacity("uk_order=");
        if (self.preference.uk_order) {
            data.appendSliceAssumeCapacity("true\n");
        } else {
            data.appendSliceAssumeCapacity("false\n");
        }

        data.appendSliceAssumeCapacity("theme=");
        data.appendSliceAssumeCapacity(self.preference.theme);
        data.appendSliceAssumeCapacity("\nscale=");
        data.appendSliceAssumeCapacity(@tagName(self.preference.size));
        data.appendSliceAssumeCapacity("\naccessibility=");
        if (self.preference.accessibility) {
            data.appendSliceAssumeCapacity("true");
        } else {
            data.appendSliceAssumeCapacity("false");
        }

        engine.savePreferenceData(
            self.allocator,
            self.io,
            &self.display.config,
            settings_file,
            data.items,
        ) catch |e| {
            err("Failed to save preference data. {t}", .{e});
        };
    }

    pub const view_history_file = "view_history.txt";
    pub const settings_file = "settings.txt";

    pub fn loadViewHistory(self: *AppContext, dictionary: *Dictionary) !void {
        const data = engine.loadPreferenceData(self.allocator, &self.display.config, view_history_file) catch |f| switch (f) {
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| {
                err("loadActivityHistory() failed. file={q} error={t}", .{
                    view_history_file,
                    e,
                });
                return;
            },
        } orelse {
            notice("View history file not yet created.", .{});
            return;
        };
        defer self.allocator.free(data);

        var iter = std.mem.tokenizeAny(u8, data, "\n\r\t= ");
        while (iter.next()) |item| {
            const form = dictionary.by_form.lookup(item) catch |e| {
                warn("View history has invalid utf8 {t}", .{e});
                continue;
            };
            if (form) |result| {
                if (result.exact_accented.items.len > 0) {
                    try self.view_history.append(self.allocator, result.exact_accented.items[0]);
                } else {
                    warn("Read view history cant find exact word {s}", .{item});
                }
            } else {
                warn("Read view history cant find word {s}", .{item});
            }
            if (self.view_history.items.len == MAX_SEARCH_HISTORY) {
                break;
            }
        }
    }

    pub fn save_view_history(self: *AppContext) error{WriteFailed}!void {
        var data: std.Io.Writer.Allocating = .init(self.allocator);
        defer data.deinit();

        for (self.view_history.items, 0..) |item, i| {
            if (i > 0)
                data.writer.writeByte(' ') catch return error.WriteFailed;

            data.writer.writeAll(item.word) catch return error.WriteFailed;
            if (i == MAX_SEARCH_HISTORY) break;
        }

        engine.savePreferenceData(
            self.allocator,
            self.io,
            &self.display.config,
            view_history_file,
            data.written(),
        ) catch |e| {
            err("Save view history file faled. {t}", .{e});
            return error.WriteFailed;
        };
    }

    /// Provides a standardised way to place a back button in the top left
    /// corner of the screen.
    pub fn add_back_button(
        self: *AppContext,
        parent: *Entity,
        close_fn: Entity.Callback,
    ) (engine.Error || Allocator.Error || Resources.Error)!*Entity {
        return try parent.add(.{
            .name = "back",
            .focus = .can_focus,
            .rect = .{ .x = 10, .y = 10, .width = 60, .height = 60 },
            .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
            .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
            .type = .{ .button = .{
                .icon = .{
                    .default_name = "icon-back",
                    .pressed_name = "icon-back",
                    .hover_name = "icon-back",
                    .size = .{ .width = 35, .height = 35 },
                },
                .on_pressed = close_fn,
            } },
            .on_resized = .{ .func = @ptrCast(&back_button_resize), .ptr = self },
        }, self.display);
    }

    pub fn load_preferences(self: *AppContext) error{OutOfMemory}!void {
        // Start with basic defaults
        self.preference.use_koine = false;
        self.preference.show_strongs = false;
        self.preference.accessibility = false;
        self.preference.theme = "default";
        self.preference.size = .normal;
        self.preference.uk_order = true;

        self.preference.present_future = true;
        self.preference.imperfect = false;
        self.preference.aorist = false;
        self.preference.mi = false;
        self.preference.imperative = false;
        self.preference.infinitive = false;
        self.preference.subjunctive = false;
        self.preference.optative = false;
        self.preference.indicative = true;
        self.preference.participle = false;
        self.preference.middle_passive = false;
        self.preference.third_declension = false;
        self.preference.perfect_pluperfect = false;
        self.preference.middle_passive = false;
        self.preference.nominative_accusative = true;
        self.preference.genitive_dative = false;

        const data = engine.loadPreferenceData(
            self.allocator,
            &self.display.config,
            settings_file,
        ) catch |f| switch (f) {
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| {
                err("load_preferences() failed. file={q} error={t}", .{
                    settings_file,
                    e,
                });
                return;
            },
        } orelse {
            notice("load_preferences() no preferences file exists yet.", .{});
            return;
        };
        defer self.allocator.free(data);

        var iter = std.mem.tokenizeAny(u8, data, "\n\r\t= ");

        while (true) {
            if (iter.next()) |field| {
                if (iter.next()) |value| {
                    debug("preference {s}={s}", .{ field, value });
                    if (std.mem.eql(u8, "use_koine", field)) {
                        self.preference.use_koine = is_true(field, value);
                    } else if (std.mem.eql(u8, "show_strongs", field)) {
                        self.preference.show_strongs = is_true(field, value);
                    } else if (std.mem.eql(u8, "accessibility", field)) {
                        self.preference.accessibility = is_true(field, value);
                    } else if (std.mem.eql(u8, "theme", field)) {
                        self.preference.theme = self.display.validate_theme(value);
                    } else if (std.mem.eql(u8, "scale", field)) {
                        self.preference.size = Scale.parse(value);
                    } else if (std.mem.eql(u8, "uk_order", field)) {
                        self.preference.uk_order = is_true(field, value);
                    } else {
                        warn("Unrecognised preference {s}={s}", .{ field, value });
                    }
                    continue;
                }
            }
            break;
        }
    }
};

fn is_true(field: []const u8, value: []const u8) bool {
    if (std.ascii.eqlIgnoreCase("true", value)) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase("t", value)) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase("yes", value)) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase("y", value)) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase("false", value)) {
        return false;
    }
    if (std.ascii.eqlIgnoreCase("f", value)) {
        return false;
    }
    if (std.ascii.eqlIgnoreCase("no", value)) {
        return false;
    }
    if (std.ascii.eqlIgnoreCase("n", value)) {
        return false;
    }

    warn("Expecting true or false, found {s}={s}", .{ field, value });

    return false;
}

fn pick_search_screen(
    self: *AppContext,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    if (display.getPanel("search.screen")) |screen| {
        try self.search_screen.show(display, screen, event);
    }
}

pub fn pick_preferences_screen(
    _: *AppContext,
    display: *Display,
    _: *Entity,
    event: *const Event,
) Allocator.Error!void {
    try display.choosePanel("preferences.screen", event);
}

fn pick_parsing_screen(
    _: *AppContext,
    display: *Display,
    _: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    try display.choosePanel("parsing.menu", event);
}

fn toggle_menu(
    self: *AppContext,
    display: *Display,
    _: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (self.menu_ui.panel.visible == .hidden) {
        try self.menu_ui.panel.setVisibility(display, .visible);
        info("menu show", .{});
    } else {
        try self.menu_ui.panel.setVisibility(display, .hidden);
        info("menu hide", .{});
    }
}

fn escape_quit(
    _: *AppContext,
    display: *Display,
    _: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    info("Escape key for quit.", .{});
    display.endMainLoop();
}

fn android_back(
    self: *AppContext,
    display: *Display,
    _: *Entity,
    event: *const Event,
) std.mem.Allocator.Error!void {
    info("Android back button pressed", .{});
    if (display.currentPanel()) |screen| {
        if (std.mem.eql(u8, screen.name, "word.info")) {
            try self.search_screen.show(display, screen, event);
        }
        if (std.mem.eql(u8, screen.name, "parsing.setup")) {
            try self.parsing_menu.show(display, screen, event);
        }
        if (std.mem.eql(u8, screen.name, "parsing.quiz")) {
            try self.parsing_menu.show(display, screen, event);
        }
    }
}

/// This event handler repositions a back button into the top left corner
/// when the screen is resized or rotated.
pub fn back_button_resize(
    _: *AppContext,
    display: *Display,
    entity: *Entity,
    _: *Event,
) bool {
    var updated = false;
    if (entity.rect.x != display.safe_area.left) {
        entity.rect.x = display.safe_area.left;
        updated = true;
    }
    if (entity.rect.y != display.safe_area.top) {
        entity.rect.y = display.safe_area.top;
        updated = true;
    }
    return updated;
}

/// Moves dictionary loading to a background thread to speed
/// up app opening time.
pub fn loadDictionary(
    gpa: Allocator,
    io: std.Io,
    app: *AppContext,
) bool {
    const dict_name = "dict";

    info("Load Dictionary task initiated", .{});

    debug("Lookup dictionary data file", .{});
    // Load dictionary from resource bundle
    const resource = app.display.resources.lookupNewest(dict_name, .bin) catch |e| {
        err("Error reading 'dict.bin' from resource bundle: {t}", .{e});
        return false;
    } orelse {
        err("No '{s}' bin file in resource bundle.", .{dict_name});
        return false;
    };

    const data = loadResourceSdl(gpa, io, &app.display.resources, resource) catch |e| {
        err("Error while reading dictionary data file. {t}", .{e});
        return false;
    };
    defer gpa.free(data);
    info("Dictionary: Beginning load. '{s}' data.len={d}", .{ dict_name, data.len });

    const start = std.Io.Timestamp.now(io, .real).toMilliseconds();
    app.dictionary.loadBinaryData(data) catch |e| {
        err("Dictionary: Error reading data: {t}", .{e});
        return false;
    };
    const end = std.Io.Timestamp.now(io, .real).toMilliseconds();
    info("Dictionary: loaded in {d}ms.", .{end - start});
    if (!app.display.triggerEventHook(app.data_loaded_event))
        err("Dictionary load event callback failed.", .{});
    return true;
}

pub const Screen = enum(u3) {
    unknown = 0,
    search,
    word_info,
    preferences,
    parsing_menu,
    parsing_setup,
    parsing_card,
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const builtin = @import("builtin");
const praxis = @import("praxis");
const Lang = praxis.Lang;
const Resources = @import("resources").Resources;
const ResourcesError = @import("resources").Resources.Error;
const Dictionary = praxis.Dictionary;
const Panels = praxis.Panels;

const engine = @import("engine");
const Display = engine.Display;
const StringBucket = engine.StringBucket;
const Entity = engine.Entity;
const Event = engine.Event;
const err = engine.log.err;
const warn = engine.log.warn;
const info = engine.log.info;
const debug = engine.log.debug;
const notice = engine.log.notice;
const trace = engine.log.trace;
const Scale = engine.Scale;
const loadResourceSdl = engine.loadResourceSdl;
const sdl = engine.sdl;

const Lists = @import("Lists.zig");
const WordSet = Lists.WordSet;
const ParsingQuiz = @import("ParsingQuiz.zig");

const ByzScreen = @import("ByzScreen.zig");
const LicenseScren = @import("LicenseScreen.zig");
const ListNewScreen = @import("ListNewScreen.zig");
const ListEditScreen = @import("ListEditScreen.zig");
const ListDeleteScreen = @import("ListDeleteScreen.zig");
const MenuUI = @import("MenuUI.zig");
const NotoScreen = @import("NotoScreen.zig");
const PrivacyScreen = @import("PrivacyScreen.zig");
const PreferencesScreen = @import("PreferencesScreen.zig");
const ParsingMenuScreen = @import("ParsingMenuScreen.zig");
const ParsingSetupScreen = @import("ParsingSetupScreen.zig");
const ParsingCardScreen = @import("ParsingCardScreen.zig");
const SearchScreen = @import("SearchScreen.zig");
const TermsScreen = @import("TermsScreen.zig");
const WordInfoScreen = @import("WordInfoScreen.zig");
const SDLScreen = @import("SDLScreen.zig");

test "scale enum" {
    try std.testing.expectEqual(Scale.extra_large, Scale.parse("extra_large"));
    try std.testing.expectEqual(Scale.small, Scale.parse("sMaLL"));
    try std.testing.expectEqual(Scale.unknown, Scale.parse("owief08h"));
    try std.testing.expectEqual(Scale.unknown, Scale.parse(""));
}
