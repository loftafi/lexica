//! Word Sets are user created sets of words. Sets are loaded on app
//! startup, and saved whenever a set is changed.

pub const MAX_FORMS_IN_SET: usize = 100;
pub const MAX_SET_NAME: usize = 40;

pub const Lists = @This();

sets: ArrayListUnmanaged(*WordSet),
dictionary: *Dictionary,

const FILENAME = "sets.txt";

pub fn init(dictionary: *Dictionary) Lists {
    return Lists{
        .sets = .empty,
        .dictionary = dictionary,
    };
}

pub fn deinit(self: *Lists, gpa: Allocator) void {
    for (self.sets.items) |list| {
        list.destroy(gpa);
    }
    self.sets.deinit(gpa);
    self.* = undefined;
}

/// Find the list matching the specified name.
pub fn lookup(self: *Lists, name: []const u8) ?*WordSet {
    for (self.sets.items) |list| {
        if (std.mem.eql(u8, name, list.name.items)) {
            return list;
        }
    }
    return null;
}

/// If no list data file exists at all, create a placeholder list
/// file with some example word sets.
pub fn prefill(self: *Lists, gpa: Allocator) error{OutOfMemory}!void {
    var l = try WordSet.create(gpa);
    try l.name.appendSlice("People");
    try self.sets.append(l);
    var f = ac.app_context.?.dictionary.by_form.lookup("Ἄννα");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("Ἰησοῦς");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("Μαρία");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("Μᾶρκος");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("Παῦλος");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("Πέτρος");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("Χλόη");
    try l.forms.append(f.?.exact_accented.items[0]);

    l = try WordSet.create(self.sets.allocator);
    try l.name.appendSlice("Food and Drink");
    try ac.app_context.?.lists.sets.append(l);
    f = ac.app_context.?.dictionary.by_form.lookup("ἄρτος");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("ὄσπριον");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("οἶνος");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("συκῆ");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("τυρός");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("σταφυλή");
    try l.forms.append(f.?.exact_accented.items[0]);
    f = ac.app_context.?.dictionary.by_form.lookup("ᾠόν");
    try l.forms.append(f.?.exact_accented.items[0]);
    try self.save();
}

/// Load word list data. What is the correct behaviour for when the
/// word list file cannot be read?
pub fn load(self: *Lists, gpa: Allocator, config: *engine.Config) error{ OutOfMemory, InvalidListFile }!void {
    const data = engine.loadPreferenceData(gpa, config, FILENAME) catch |f| switch (f) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| {
            err("load() failed. file={q} error={t}", .{
                FILENAME,
                e,
            });
            return;
        },
    } orelse {
        notice("No list data file exists yet", .{});
        return;
    };
    defer gpa.free(data);

    debug("{s} size = {d}", .{ FILENAME, data.len });
    var iter = std.mem.tokenizeAny(u8, data, "\n\r\t= ");

    while (true) {
        if (iter.next()) |key| {
            // Expet list_name or end of file.
            if (!std.mem.eql(u8, "list_name", key)) {
                warn("Expected token \"list_name\" but found {s}", .{key});
                return error.InvalidListFile;
            }
        } else {
            // No more content
            break;
        }

        var list = try WordSet.create(gpa);
        try self.sets.append(gpa, list);

        // Read the title
        while (iter.next()) |title| {
            if (std.mem.eql(u8, "end", title)) {
                break;
            }
            if (list.name.items.len > 0) {
                try list.name.append(gpa, ' ');
            }
            try list.name.appendSlice(gpa, title);
        }
        if (list.name.items.len == 0) {
            warn("List name is empty", .{});
            return error.InvalidListFile;
        }

        // Read the word entries
        if (iter.next()) |key| {
            // Expet list_entries or end of file.
            if (!std.mem.eql(u8, "list_entries", key)) {
                warn("Expected token \"list_entries\" but found {s}", .{key});
                return error.InvalidListFile;
            }
        } else {
            // No more content
            break;
        }
        while (iter.next()) |word| {
            if (std.mem.eql(u8, "end", word)) {
                break;
            }
            if (iter.next()) |uid| {
                if (std.mem.eql(u8, "list_entries", uid)) {
                    return error.InvalidListFile;
                }
                if (std.mem.eql(u8, "list_name", uid)) {
                    return error.InvalidListFile;
                }
                const id = std.fmt.parseInt(u24, uid, 10) catch {
                    return error.InvalidListFile;
                };
                const result = self.dictionary.by_form.lookup(word) catch |e| {
                    err("word list {s} item lookup failed. {t}", .{ word, e });
                    continue;
                };
                if (result) |sr| {
                    trace("list \"{s}\" add word {s}={s}", .{ list.name.items, word, uid });
                    var i = sr.iterator();
                    while (i.next()) |form| {
                        if (form.uid == id) {
                            try list.forms.append(gpa, form);
                            break;
                        }
                    }
                } else {
                    err("word list {s} item not found: {s}={s}", .{ list.name.items, word, uid });
                }
            }
        }
    }
}

/// Delete a word list and save the change to the data store.
pub fn remove_list(
    self: *Lists,
    display: *Display,
    list: *WordSet,
) error{OutOfMemory}!void {
    for (self.sets.items, 0..) |item, i| {
        if (item == list) {
            const found = self.sets.orderedRemove(i);
            found.destroy(display.allocator);
            try self.save(display.allocator, display.io, &display.config);
            return;
        }
    }
    return;
}

/// Save the complete set of word sets to the data store.
pub fn save(self: *Lists, gpa: Allocator, io: std.Io, config: *engine.Config) error{OutOfMemory}!void {
    const data = writeListData(gpa, self.sets.items) catch |e| {
        err("generate list file data failed. {t}", .{e});
        return;
    };
    defer gpa.free(data);

    engine.savePreferenceData(gpa, io, config, FILENAME, data) catch |e| {
        err("save list file data to '{s}' failed. {t}", .{ FILENAME, e });
    };
}

fn writeListData(
    gpa: Allocator,
    sets: []*WordSet,
) error{ OutOfMemory, WriteFailed }![]const u8 {
    var data = std.Io.Writer.Allocating.init(gpa);
    errdefer data.deinit();

    for (sets) |list| {
        try data.writer.writeAll("list_name ");
        try data.writer.writeAll(list.name.items);
        try data.writer.writeAll(" end\nlist_entries ");
        for (list.forms.items) |form| {
            try data.writer.writeAll(form.word);
            try data.writer.writeByte(' ');
            try data.writer.print("{d} ", .{form.uid});
        }
        try data.writer.writeAll("end\n");
    }

    return data.toOwnedSlice();
}

pub const WordSet = struct {
    name: ArrayListUnmanaged(u8),
    forms: ArrayListUnmanaged(*Form),

    study_items: ArrayListUnmanaged(*Form),

    pub fn create(allocator: Allocator) error{OutOfMemory}!*WordSet {
        var list = try allocator.create(WordSet);
        list.name = .empty;
        list.forms = .empty;
        list.study_items = .empty;
        return list;
    }

    pub fn destroy(self: *WordSet, gpa: Allocator) void {
        self.name.deinit(gpa);
        self.forms.deinit(gpa);
        self.study_items.deinit(gpa);
        self.* = undefined;
        gpa.destroy(self);
    }

    pub fn hasNounOrAdjective(self: *WordSet) bool {
        for (self.forms.items) |form| {
            if (form.parsing.part_of_speech == .noun) return true;
            if (form.parsing.part_of_speech == .adjective) return true;
            if (form.parsing.part_of_speech == .proper_noun and
                form.lexeme != null and !form.lexeme.?.pos.indeclinable) return true;
        }
        return false;
    }

    pub fn hasVerb(self: *WordSet) bool {
        for (self.forms.items) |form| {
            if (form.parsing.part_of_speech == .verb) {
                return true;
            }
        }
        return false;
    }

    pub fn hasActive(self: *WordSet) bool {
        for (self.forms.items) |form| {
            if (form.lexeme) |lexeme|
                if (lexeme.hasActiveForm()) return true;
        }
        return false;
    }

    pub fn hasMiddlePassive(self: *WordSet) bool {
        for (self.forms.items) |form| {
            if (form.lexeme) |lexeme|
                if (lexeme.hasMiddlePassiveForm()) return true;
        }
        return false;
    }

    pub fn add(self: *WordSet, gpa: Allocator, item: *Form) !bool {
        var insert_at: ?usize = null;

        for (self.forms.items, 0..) |form, i| {
            if (item.uid == form.uid) {
                return false;
            }
            if (item.lexeme != null and form.lexeme != null) {
                if (item.lexeme.?.uid == form.lexeme.?.uid) {
                    return false;
                }
            }
            if (praxis.stringLessThan({}, item.lexeme.?.word, form.lexeme.?.word)) {
                insert_at = i;
                break;
            }
        }

        if (insert_at) |i| {
            try self.forms.insert(gpa, i, item);
        } else {
            try self.forms.append(gpa, item);
        }

        return false;
    }

    pub fn remove(self: *WordSet, item: *Form) bool {
        for (self.forms.items, 0..) |form, i| {
            if (form == item) {
                _ = self.forms.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// List all forms belonging to all lexemes in this word set.
    pub fn study_forms(self: *WordSet, gpa: Allocator) error{OutOfMemory}![]*praxis.Form {
        self.study_items.clearRetainingCapacity();
        for (self.forms.items) |form| {
            if (form.lexeme) |lexeme| {
                for (lexeme.forms.items) |candidate| {
                    if (candidate.parsing.part_of_speech == .noun) {
                        try self.study_items.append(gpa, candidate);
                    } else if (candidate.parsing.part_of_speech == .adjective) {
                        try self.study_items.append(gpa, candidate);
                    } else if (candidate.parsing.part_of_speech == .verb) {
                        try self.study_items.append(gpa, candidate);
                    }
                }
            }
        }
        return self.study_items.items;
    }
};

const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const Display = engine.Display;
const err = engine.log.err;
const warn = engine.log.warn;
const notice = engine.log.notice;
const info = engine.log.info;
const trace = engine.log.trace;
const debug = engine.log.debug;
const sdl = engine.sdl;

const ac = @import("App.zig");

const praxis = @import("praxis");
const Form = praxis.Form;
const Dictionary = praxis.Dictionary;

test "list file" {
    const dict = try praxis.test_dictionary(std.testing.allocator);
    defer dict.destroy(std.testing.allocator);
    const list = try Lists.create(std.testing.allocator, dict);
    defer list.*.destroy(std.testing.allocator);
    //var sets = Lists.create(std.testing.allocator, dictionary);
    //defer sets.destroy();
}
