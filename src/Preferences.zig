pub const Preferences = @This();

pub const settings_file = "settings.txt";

gpa: Allocator = undefined,
io: std.Io = undefined,
config: ?*const engine.Config = undefined,

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

pub const empty = Preferences{
    .accessibility = false,
    .theme = "default",
    .size = .normal,
    .use_koine = false,

    .show_strongs = false,
    .uk_order = true,
    .present_future = true,
    .imperfect = false,
    .aorist = false,
    .mi = false,
    .imperative = false,
    .infinitive = false,
    .subjunctive = false,
    .optative = false,
    .indicative = true,
    .participle = false,
    .third_declension = false,
    .perfect_pluperfect = false,
    .middle_passive = false,
    .nominative_accusative = true,
    .genitive_dative = false,
};

pub fn load(
    self: *Preferences,
    gpa: Allocator,
    config: *const Config,
    display: *Display,
    io: std.Io,
) void {
    self.gpa = gpa;
    self.io = io;
    self.config = config;

    const data = engine.loadPreferenceData(gpa, config, settings_file) catch |e| {
        warn("Read preferences file {s} failed. {any}", .{ settings_file, e });
        return;
    };
    if (data == null) return;
    defer gpa.free(data.?);
    debug("Read preference file. name={s} size={d}", .{ settings_file, data.?.len });

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

    //display.blind_accessibility = self.blind_accessibility;
    //if (self.lang) |lang| {
    //    try display.setLanguage(lang);
    //}
    //display.setUserScale(self.size);
}

pub fn save(self: *Preferences) void {
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

    engine.savePreferenceData(
        self.gpa,
        self.io,
        self.config.?,
        settings_file,
        data.written(),
    ) catch |e| {
        warn("Write preferences file {s} failed. {any}", .{ settings_file, e });
        return;
    };
}

fn is_true(field: []const u8, value: []const u8) bool {
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
const warn = engine.log.warn;

const app = @import("App.zig");
