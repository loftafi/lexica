pub const Preferences = @This();

pub const settings_file = "settings.txt";

gpa: Allocator,
io: std.Io,
config: *const engine.Config,

accessibility: bool,
theme: []const u8,
size: Scale,
use_koine: bool,
show_strongs: bool,
uk_order: bool,
present_future: bool,
imperfect: bool,
perfect_pluperfect: bool,
aorist: bool,
mi: bool,
indicative: bool,
imperative: bool,
participle: bool,
subjunctive: bool,
optative: bool,
infinitive: bool,
third_declension: bool,
middle_passive: bool,
nominative_accusative: bool,
genitive_dative: bool,

pub const empty = Preferences{
    .gpa = undefined,
    .io = undefined,
    .config = undefined,
    .accessibility = false,
    .theme = "default",
    .size = .normal,
    .use_koine = false,
    .show_strongs = false,
    .uk_order = true,
    .present_future = true,
    .imperfect = false,
    .perfect_pluperfect = false,
    .aorist = false,
    .mi = false,
    .indicative = true,
    .imperative = false,
    .infinitive = false,
    .participle = false,
    .subjunctive = false,
    .optative = false,
    .third_declension = false,
    .middle_passive = false,
    .nominative_accusative = true,
    .genitive_dative = false,
};

pub fn load(
    self: *Preferences,
    gpa: Allocator,
    display: *Display,
    config: *const Config,
    io: std.Io,
) error{OutOfMemory}!void {
    self.* = .empty;
    self.gpa = gpa;
    self.io = io;
    self.config = config;

    const data = engine.loadPreferenceData(
        gpa,
        config,
        settings_file,
    ) catch |f| switch (f) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| {
            warn("loadPreferences() failed. file={q} error={t}", .{
                settings_file,
                e,
            });
            return;
        },
    } orelse {
        notice("loadPreferences() no preferences file exists yet.", .{});
        return;
    };
    defer gpa.free(data);

    var iter = std.mem.tokenizeAny(u8, data, "\n\r\t= ");

    while (true) {
        if (iter.next()) |field| {
            if (iter.next()) |value| {
                debug("preference {s}={s}", .{ field, value });
                if (std.mem.eql(u8, "use_koine", field)) {
                    self.use_koine = is_true(field, value);
                } else if (std.mem.eql(u8, "show_strongs", field)) {
                    self.show_strongs = is_true(field, value);
                } else if (std.mem.eql(u8, "accessibility", field)) {
                    self.accessibility = is_true(field, value);
                } else if (std.mem.eql(u8, "theme", field)) {
                    self.theme = display.validate_theme(value);
                } else if (std.mem.eql(u8, "scale", field)) {
                    self.size = Scale.parse(value);
                } else if (std.mem.eql(u8, "uk_order", field)) {
                    self.uk_order = is_true(field, value);
                } else {
                    warn("Unrecognised preference {s}={s}", .{ field, value });
                }
                continue;
            }
        }
        break;
    }

    debug("Apply preferences", .{});
    try display.setLanguage(if (self.use_koine) Lang.greek else Lang.english);
    display.setUserScale(self.size);
    display.blind_accessibility = self.accessibility;
    _ = try display.setTheme(self.theme);
    debug("Loaded preferences. Scale={d}/{s}", .{
        display.user_scale,
        @tagName(self.size),
    });
}

pub fn save(self: *const Preferences) error{OutOfMemory}!void {
    var data = std.ArrayList(u8).initCapacity(self.gpa, 5000) catch {
        warn("Save preferences out of memory.", .{});
        return error.OutOfMemory;
    };
    defer data.deinit(self.gpa);

    data.appendSliceAssumeCapacity("show_strongs=");
    if (self.show_strongs) {
        data.appendSliceAssumeCapacity("true\n");
    } else {
        data.appendSliceAssumeCapacity("false\n");
    }

    data.appendSliceAssumeCapacity("use_koine=");
    if (self.use_koine) {
        data.appendSliceAssumeCapacity("true\n");
    } else {
        data.appendSliceAssumeCapacity("false\n");
    }

    data.appendSliceAssumeCapacity("uk_order=");
    if (self.uk_order) {
        data.appendSliceAssumeCapacity("true\n");
    } else {
        data.appendSliceAssumeCapacity("false\n");
    }

    data.appendSliceAssumeCapacity("theme=");
    data.appendSliceAssumeCapacity(self.theme);
    data.appendSliceAssumeCapacity("\nscale=");
    data.appendSliceAssumeCapacity(@tagName(self.size));
    data.appendSliceAssumeCapacity("\naccessibility=");
    if (self.accessibility) {
        data.appendSliceAssumeCapacity("true");
    } else {
        data.appendSliceAssumeCapacity("false");
    }

    engine.savePreferenceData(
        self.gpa,
        self.io,
        self.config,
        settings_file,
        data.items,
    ) catch |e| {
        err("Failed to save preference data. {t}", .{e});
    };
}

pub fn is_true(field: []const u8, value: []const u8) bool {
    if (std.ascii.eqlIgnoreCase("true", value)) return true;
    if (std.ascii.eqlIgnoreCase("false", value)) return false;
    if (std.ascii.eqlIgnoreCase("t", value)) return true;
    if (std.ascii.eqlIgnoreCase("yes", value)) return true;
    if (std.ascii.eqlIgnoreCase("y", value)) return true;
    if (std.ascii.eqlIgnoreCase("f", value)) return false;
    if (std.ascii.eqlIgnoreCase("no", value)) return false;
    if (std.ascii.eqlIgnoreCase("n", value)) return false;
    warn("Expecting true or false, found {s}={s}", .{ field, value });
    return false;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const Config = engine.Config;
const Display = engine.Display;
const Scale = engine.Scale;
const debug = engine.log.debug;
const info = engine.log.info;
const notice = engine.log.notice;
const warn = engine.log.warn;
const err = engine.log.err;

const praxis = @import("praxis");
const Lang = praxis.Lang;
