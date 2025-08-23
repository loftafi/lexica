//! Main entry point for the dictionary application.
//!
//! This is used to setup all of the screens/scenes, then enter
//! the main loop once all data is loaded.

pub const APP_NAME: []const u8 = @import("app_info").app_full_name;
pub const APP_VERSION: []const u8 = @import("app_info").app_version;
pub const APP_ID: []const u8 = @import("app_info").app_id;
pub const APP_ORG: []const u8 = @import("app_info").org;
pub const APP_BUILD: []const u8 = @import("app_info").app_build;
pub const APP_PAD = 25;
pub const APP_MINIMUM_WIDTH = 500;
pub const APP_MINIMUM_HEIGHT = 600;
pub const APP_MAXIMUM_WIDTH = 1000;
pub const RESOURCE_TRANSLATION_FILE = "lexica translation";
pub const MAX_SEARCH_HISTORY = @import("screen_search.zig").MAX_SEARCH_RESULTS;
pub const MAX_PANEL_TABLES: usize = 20;

pub var app_context: ?*AppContext = null;
pub var writing_enabled = true;

var dictionary_thread: std.Thread = undefined;
pub var DATA_LOADED_EVENT: u32 = 0;
pub var data_loaded_event: sdl.SDL_Event = undefined;

/// Moves dictionary loading to a background thread to speed
/// up app opening time.
pub fn dictionary_loader_in_thread(data: []const u8) void {
    defer app_context.?.allocator.free(data);
    const start = std.time.milliTimestamp();
    app_context.?.dictionary.loadBinaryData(app_context.?.dictionary_arena.allocator(), app_context.?.allocator, data) catch |e| {
        err("Error reading dictionary data content. load_binary_data() returned: {any}", .{e});
        _ = sdl.SDL_PushEvent(&data_loaded_event);
        return;
    };
    const end = std.time.milliTimestamp();
    info("Dictionary loaded in {d}ms.", .{end - start});

    _ = sdl.SDL_PushEvent(&data_loaded_event);
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

pub const AppContext = struct {

    // Global app variables
    allocator: Allocator,
    display: *Display = undefined,
    theme: []const u8 = "",

    dictionary: *Dictionary = undefined,
    dictionary_arena: std.heap.ArenaAllocator = undefined,

    // Word info screen data
    word_lexeme: ?*praxis.Lexeme = null,
    panels: *Panels = undefined,
    panel_tables: [MAX_PANEL_TABLES]*Element = undefined,

    parsing_quiz: ParsingQuiz = undefined,

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
    view_history: std.ArrayList(*praxis.Form),

    // Complete all setup needed to get to the blank startup screen.
    // Setup continues on in a background thread so that initial startup
    // screen drawing may occur.
    pub fn create(allocator: Allocator, dev_resource_folder: []const u8, gui_flags: usize) error{
        OutOfMemory,
        NoResources,
        ResourceReadError,
        graphics_init_failed,
        font_init_failed,
        window_creation_failed,
        graphics_renderer_failed,
        ResourceNotFound,
        ThreadCreationFailed,
        MetadataMissing,
        InvalidResourceUID,
        ReadMetadataFailed,
        ReadRepoFileFailed,
        Utf8ExpectedContinuation,
        Utf8OverlongEncoding,
        Utf8EncodesSurrogateHalf,
        Utf8CodepointTooLarge,
        Utf8InvalidStartByte,
    }!*AppContext {
        info("Starting app {s} {d}", .{ APP_NAME, APP_BUILD });
        var ac = try allocator.create(AppContext);
        errdefer allocator.destroy(ac);
        ac.allocator = allocator;
        ac.word_lexeme = null;
        ac.view_history = std.ArrayList(*praxis.Form).init(allocator);
        try ac.parsing_quiz.init(allocator);
        errdefer ac.view_history.deinit();
        ac.panels = try Panels.create(allocator);
        errdefer ac.panels.destroy();

        ac.display = try Display.create(
            allocator,
            app_name_z(),
            app_version_z(),
            app_id_z(),
            dev_resource_folder,
            RESOURCE_TRANSLATION_FILE,
            gui_flags,
        );
        errdefer ac.display.destroy();

        debug("Loading preferences", .{});
        ac.load_preferences();
        debug("Apply preferences", .{});
        if (ac.preference.use_koine) {
            try ac.display.set_language(Lang.greek);
        } else {
            try ac.display.set_language(Lang.english);
        }
        ac.display.set_scale(ac.preference.size);
        ac.display.event_hook = event_hook;
        _ = ac.display.set_theme(ac.preference.theme);
        debug("Loaded preferences. Scale={d}/{s}", .{ ac.display.user_scale, @tagName(ac.preference.size) });

        app_context = ac;
        errdefer app_context = null;

        // Placeholder for the dictionary in case this object is destroyed later
        ac.dictionary_arena = std.heap.ArenaAllocator.init(allocator);
        errdefer ac.dictionary_arena.deinit();
        ac.dictionary = try Dictionary.create(ac.dictionary_arena.allocator());
        errdefer ac.dictionary.destroy(ac.dictionary_arena.allocator());
        ac.lists = Lists.init(allocator, ac.dictionary);
        try ac.start_dictionary_load();

        return ac;
    }

    pub fn destroy(ac: *AppContext) void {
        if (ac.dictionary.lexemes.items.len > 0) {
            @import("screen_parsing_setup.zig").destroy(ac.display);
            SearchScreen.deinit();
            ListEditScreen.deinit();
            WordInfoScreen.deinit();
        }
        ac.view_history.deinit();
        ac.display.destroy();
        ac.panels.destroy();
        ac.parsing_quiz.deinit();
        ac.lists.deinit();

        ac.dictionary.destroy(ac.dictionary_arena.allocator());
        ac.dictionary_arena.deinit();

        ac.allocator.destroy(ac);
    }

    fn event_hook(_: *Display, e: u32) error{OutOfMemory}!void {
        if (e == DATA_LOADED_EVENT) {
            sdl.SDL_PumpEvents();
            app_context.?.enable_screens() catch |er| {
                err("Enable main screens failed. {any}", .{er});
            };
        }
    }

    pub fn start_dictionary_load(ac: *AppContext) error{ OutOfMemory, ThreadCreationFailed }!void {
        debug("Lookup dictionary data file", .{});
        // Load dictionary from resource bundle
        if (ac.display.resources.lookupOne("dict", .bin)) |resource| {
            if (sdl_load_resource(ac.display.resources, resource, ac.allocator)) |data| {
                // Data freed in loader
                DATA_LOADED_EVENT = sdl.SDL_RegisterEvents(1);
                data_loaded_event.type = DATA_LOADED_EVENT;
                dictionary_thread = std.Thread.spawn(.{}, dictionary_loader_in_thread, .{data}) catch |te| {
                    err("Thread Creation for data load failed {any}", .{te});
                    return error.ThreadCreationFailed;
                };
            } else |e| {
                err("Error while reading dictionary data file. {any}", .{e});
            }
        } else {
            err("No 'dict.bin' file in bundle.", .{});
        }
    }

    pub fn setup_screens(ac: *AppContext) !void {

        // Load fonts after screen initialisation so that the
        // screen pixel density can be accounted for.
        var start = std.time.milliTimestamp();
        _ = try ac.display.load_font("NotoSans-Regular");
        _ = try ac.display.load_font("NotoSansTC-Regular");
        var end = std.time.milliTimestamp();
        info("Font load time {d}ms.", .{end - start});

        start = std.time.milliTimestamp();
        try SearchScreen.init(ac);
        errdefer SearchScreen.deinit();

        try PreferencesScreen.init(ac);
        errdefer PreferencesScreen.deinit();

        try ParsingMenuScreen.init(ac);
        errdefer ParsingMenuScreen.deinit();

        try ParsingSetupScreen.init(ac);
        errdefer ParsingSetupScreen.deinit();

        try ParsingCardScreen.init(ac);
        errdefer ParsingCardScreen.deinit();

        try WordInfoScreen.init(ac);
        errdefer WordInfoScreen.deinit();

        try ListNewScreen.init(ac);
        errdefer ListNewScreen.deinit();

        try ListDeleteScreen.init(ac);
        errdefer ListDeleteScreen.deinit();

        try ListEditScreen.init(ac);
        errdefer ListEditScreen.deinit();

        try MenuUI.init(ac);
        end = std.time.milliTimestamp();
        info("Screens loaded in {d}ms.", .{end - start});
    }

    pub fn enable_screens(ac: *AppContext) !void {
        debug("Loading view history", .{});
        app_context.?.load_view_history(app_context.?.dictionary) catch |e| {
            err("Error reading view history file. {any}", .{e});
            return;
        };
        debug("loaded view history.", .{});
        try SearchScreen.show_search_history(ac.display);

        debug("Loading word lists", .{});
        app_context.?.lists.load() catch |e| {
            err("Error reading word lists. {any}", .{e});
            return;
        };

        debug("Loaded word lists.", .{});
        try SearchScreen.show_search_history(ac.display);
        try ParsingMenuScreen.update_sets();

        debug("Adding keybindings.", .{});
        try ac.display.keybindings.put(sdl.SDLK_SPACE, pick_search_screen);
        try ac.display.keybindings.put(sdl.SDLK_S, pick_search_screen);
        try ac.display.keybindings.put(sdl.SDLK_P, pick_preferences_screen);
        try ac.display.keybindings.put(sdl.SDLK_Q, pick_parsing_screen);

        if (engine.dev_build) {
            try ac.display.keybindings.put(sdl.SDLK_M, toggle_menu);
        }

        if (builtin.target.os.tag != .ios and
            !builtin.target.abi.isAndroid())
        {
            try ac.display.keybindings.put(sdl.SDLK_ESCAPE, escape_quit);
        }
        try ac.display.keybindings.put(sdl.SDLK_AC_BACK, android_back);

        // override keybindings for screen size preference saving
        try ac.display.keybindings.put(sdl.SDLK_X, increase_size);
        try ac.display.keybindings.put(sdl.SDLK_PLUS, increase_size);
        try ac.display.keybindings.put(sdl.SDLK_EQUALS, increase_size);
        try ac.display.keybindings.put(sdl.SDLK_MINUS, decrease_size);
        try ac.display.keybindings.put(sdl.SDLK_KP_PLUS, increase_size);
        try ac.display.keybindings.put(sdl.SDLK_KP_MINUS, decrease_size);

        if (ac.display.get_panel("menu")) |menu| {
            menu.visible = .visible;
        }
        ac.display.choose_panel("search.screen");
        ac.display.relayout();
        ac.display.relayout();
    }

    pub fn save_preferences(self: *AppContext) void {
        var data = std.ArrayList(u8).initCapacity(self.allocator, 5000) catch {
            warn("Save preferences out of memory.", .{});
            return;
        };
        defer data.deinit();

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

        const path = sdl.SDL_GetPrefPath(app_org_z(), app_name_z());
        const zpath = std.mem.sliceTo(path, 0);
        var folder = std.fs.openDirAbsolute(zpath, .{}) catch |e| {
            warn("Open preferences path failed. {s} {any}", .{ path, e });
            return;
        };
        var file = folder.createFile("settings.txt", .{}) catch |e| {
            warn("Open preferences file failed. {s} {any}", .{ path, e });
            return;
        };
        defer file.close();
        file.writeAll(data.items) catch |e| {
            warn("Write preferences file failed. {s} {any}", .{ path, e });
            return;
        };
    }

    pub fn load_view_history(self: *AppContext, dictionary: *Dictionary) !void {
        const path = sdl.SDL_GetPrefPath(app_org_z(), app_name_z());
        const zpath = std.mem.sliceTo(path, 0);
        var folder = std.fs.openDirAbsolute(zpath, .{}) catch |e| {
            warn("Open preferences path failed. {s} {any}", .{ path, e });
            return;
        };
        info("Preferences path: {s}", .{zpath});
        var file = folder.openFile("view_history.txt", .{}) catch |e| {
            if (e == error.FileNotFound) {
                info("View history file not yet created.", .{});
                return;
            }
            warn("Open view history file failed. {s} {any}", .{ path, e });
            return;
        };
        defer file.close();
        debug("start reading view_history.txt", .{});
        const data = file.readToEndAlloc(self.allocator, 10000) catch |e| {
            warn("Read view history file failed. {s} {any}", .{ path, e });
            return;
        };
        debug("view_history.txt size = {d}", .{data.len});
        defer self.allocator.free(data);
        var iter = std.mem.tokenizeAny(u8, data, "\n\r\t= ");
        while (iter.next()) |item| {
            if (dictionary.by_form.lookup(item)) |result| {
                if (result.exact_accented.items.len > 0) {
                    try self.view_history.append(result.exact_accented.items[0]);
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

    pub fn save_view_history(self: *AppContext) void {
        var data = std.ArrayList(u8).initCapacity(self.allocator, 5000) catch {
            warn("Save preferences out of memory.", .{});
            return;
        };
        defer data.deinit();

        for (self.view_history.items, 0..) |item, i| {
            if (i > 0) {
                data.appendSliceAssumeCapacity(" ");
            }
            data.appendSliceAssumeCapacity(item.word);
            if (i == MAX_SEARCH_HISTORY) {
                break;
            }
        }

        const path = sdl.SDL_GetPrefPath(app_org_z(), app_name_z());
        const zpath = std.mem.sliceTo(path, 0);
        var folder = std.fs.openDirAbsolute(zpath, .{}) catch |e| {
            warn("Open preferences path failed. {s} {any}", .{ path, e });
            return;
        };
        var file = folder.createFile("view_history.txt", .{}) catch |e| {
            warn("Open view history file failed. {s} {any}", .{ path, e });
            return;
        };
        defer file.close();
        file.writeAll(data.items) catch |e| {
            warn("Write view history file failed. {s} {any}", .{ path, e });
            return;
        };
    }

    pub fn load_preferences(self: *AppContext) void {
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

        const path = sdl.SDL_GetPrefPath(app_org_z(), app_name_z());
        const zpath = std.mem.sliceTo(path, 0);
        var folder = std.fs.openDirAbsolute(zpath, .{}) catch |e| {
            warn("Open preferences path failed. {s} {any}", .{ path, e });
            return;
        };
        info("Preferences path: {s}", .{zpath});
        var file = folder.openFile("settings.txt", .{}) catch |e| {
            if (e == error.FileNotFound) {
                info("Preferences file not yet created.", .{});
                return;
            }
            warn("Open preferences file failed. {s} {any}", .{ path, e });
            return;
        };
        defer file.close();
        debug("start reading settings.txt", .{});
        const data = file.readToEndAlloc(self.allocator, 10000) catch |e| {
            warn("Read preferences file failed. {s} {any}", .{ path, e });
            return;
        };
        debug("settings.txt size = {d}", .{data.len});
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

fn pick_search_screen(display: *Display) error{OutOfMemory}!void {
    if (display.get_panel("search.screen")) |screen| {
        try SearchScreen.show(display, screen);
    }
}

fn pick_preferences_screen(display: *Display) error{OutOfMemory}!void {
    display.choose_panel("preferences.screen");
}

fn pick_parsing_screen(display: *Display) error{OutOfMemory}!void {
    display.choose_panel("parsing.menu");
}

fn toggle_menu(_: *Display) error{OutOfMemory}!void {
    if (MenuUI.panel.visible == .hidden) {
        MenuUI.panel.visible = .visible;
        info("menu show", .{});
    } else {
        MenuUI.panel.visible = .hidden;
        info("menu hide", .{});
    }
}

fn increase_size(display: *Display) error{OutOfMemory}!void {
    display.increase_size();
    app_context.?.preference.size = Scale.from_float(display.user_scale);
    app_context.?.save_preferences();
}

fn decrease_size(display: *Display) error{OutOfMemory}!void {
    display.decrease_size();
    app_context.?.preference.size = Scale.from_float(display.user_scale);
    app_context.?.save_preferences();
}

fn escape_quit(display: *Display) error{OutOfMemory}!void {
    info("Escape key for quit.", .{});
    display.end_main_loop();
}

fn android_back(display: *Display) std.mem.Allocator.Error!void {
    info("Android back button pressed", .{});
    if (display.current_panel()) |screen| {
        if (std.mem.eql(u8, screen.name, "word.info")) {
            try SearchScreen.show(display, screen);
        }
        if (std.mem.eql(u8, screen.name, "parsing.setup")) {
            try ParsingMenuScreen.show(display, screen);
        }
        if (std.mem.eql(u8, screen.name, "parsing.quiz")) {
            try ParsingMenuScreen.show(display, screen);
        }
    }
}

fn rotate_theme_selection(display: *Display) std.mem.Allocator.Error!void {
    display.rotate_theme();
}

var APP_ORG_Z: [1000]u8 = undefined;
pub fn app_org_z() [:0]const u8 {
    return std.fmt.bufPrintZ(&APP_ORG_Z, "{s}", .{APP_ORG}) catch @panic("APP_ORG too long");
}

var APP_NAME_Z: [1000]u8 = undefined;
pub fn app_name_z() [:0]const u8 {
    return std.fmt.bufPrintZ(&APP_NAME_Z, "{s}", .{APP_NAME}) catch @panic("APP_NAME too long");
}

var APP_ID_Z: [1000]u8 = undefined;
pub fn app_id_z() [:0]const u8 {
    return std.fmt.bufPrintZ(&APP_ID_Z, "{s}", .{APP_ID}) catch @panic("APP_ID too long");
}

var APP_VERSION_Z: [1000]u8 = undefined;
pub fn app_version_z() [:0]const u8 {
    return std.fmt.bufPrintZ(&APP_VERSION_Z, "{s}", .{APP_VERSION}) catch @panic("APP_VERSION too long");
}

const builtin = @import("builtin");
const praxis = @import("praxis");
const Lang = praxis.Lang;
const Resources = praxis.Resources;
const Dictionary = praxis.Dictionary;
const Panels = praxis.Panels;
const engine = @import("engine");
const Display = engine.Display;
const Element = engine.Element;
const err = engine.err;
const warn = engine.warn;
const info = engine.info;
const debug = engine.debug;
const trace = engine.trace;
const Scale = engine.Scale;
const std = @import("std");
const Allocator = std.mem.Allocator;
const sdl = @import("dep_sdl_module");
const Lists = @import("lists.zig");
const WordSet = Lists.WordSet;
const ParsingQuiz = @import("parsing_quiz.zig");

const SearchScreen = @import("screen_search.zig");
const PreferencesScreen = @import("screen_preferences.zig");
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const ParsingSetupScreen = @import("screen_parsing_setup.zig");
const ParsingCardScreen = @import("screen_parsing_card.zig");
const WordInfoScreen = @import("screen_word_info.zig");
const MenuUI = @import("menu_ui.zig");
const ListNewScreen = @import("screen_list_new.zig");
const ListEditScreen = @import("screen_list_edit.zig");
const ListDeleteScreen = @import("screen_list_delete.zig");

const sdl_load_resource = @import("engine").sdl_load_resource;

test "scale enum" {
    try std.testing.expectEqual(Scale.extra_large, Scale.parse("extra_large"));
    try std.testing.expectEqual(Scale.small, Scale.parse("sMaLL"));
    try std.testing.expectEqual(Scale.unknown, Scale.parse("owief08h"));
    try std.testing.expectEqual(Scale.unknown, Scale.parse(""));
}
