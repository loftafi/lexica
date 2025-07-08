//! Word Sets are user created sets of words. Sets are loaded on app
//! startup, and saved whenever a set is changed.

pub const MAX_FORMS_IN_SET: usize = 100;
pub const MAX_SET_NAME: usize = 40;

pub const Self = @This();

sets: ArrayList(*WordSet),
dictionary: *Dictionary,

const FILENAME = "sets.txt";

pub fn create(allocator: Allocator, dictionary: *Dictionary) *Self {
    var sets = allocator.create(Self);
    sets.dictionary = dictionary;
    sets.sets = ArrayList(*WordSet).init(allocator);
    return sets;
}

pub fn destroy(self: *Self) void {
    const allocator = self.sets.allocator;
    for (self.sets.items) |*list| {
        list.destroy();
        allocator.destroy(list);
    }
    self.sets.deinit();
    allocator.destroy(self);
}

pub fn init(allocator: Allocator, dictionary: *Dictionary) Self {
    return Self{
        .sets = ArrayList(*WordSet).init(allocator),
        .dictionary = dictionary,
    };
}

pub fn deinit(self: *Self) void {
    //const allocator = self.sets.allocator;
    for (self.sets.items) |list| {
        list.destroy();
    }
    self.sets.deinit();
}

/// Find the list matching the specified name.
pub fn lookup(self: *Self, name: []const u8) ?*WordSet {
    for (self.sets.items) |list| {
        if (std.mem.eql(u8, name, list.name.items)) {
            return list;
        }
    }
    return null;
}

/// If no list data file exists at all, create a placeholder list
/// file with some example word sets.
pub fn prefill(self: *Self) error{OutOfMemory}!void {
    var l = try WordSet.create(self.sets.allocator);
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
pub fn load(self: *Self) error{ OutOfMemory, InvalidListFile }!void {
    // TODO: Need improved file open and file content fail handling
    const path = sdl.SDL_GetPrefPath(ac.app_org_z(), ac.app_name_z());
    const zpath = std.mem.sliceTo(path, 0);
    var folder = std.fs.openDirAbsolute(zpath, .{}) catch |e| {
        warn("Open preferences path failed. {s} {any}", .{ path, e });
        return;
    };
    info("Preferences path: {s}", .{zpath});
    var file = folder.openFile(FILENAME, .{}) catch |e| {
        if (e == error.FileNotFound) {
            info("sets file file not yet created.", .{});
            try self.prefill();
            return;
        }
        warn("Open sets file failed. {s} {any}", .{ path, e });
        return;
    };
    defer file.close();
    debug("start reading sets file {s}", .{FILENAME});
    const data = file.readToEndAlloc(self.sets.allocator, 1024 * 1024 * 20) catch |e| {
        warn("Read preferences file failed. {s} {any}", .{ path, e });
        return;
    };
    debug("{s} size = {d}", .{ FILENAME, data.len });
    defer self.sets.allocator.free(data);
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

        var list = try WordSet.create(self.sets.allocator);
        try self.sets.append(list);

        // Read the title
        while (iter.next()) |title| {
            if (std.mem.eql(u8, "end", title)) {
                break;
            }
            if (list.name.items.len > 0) {
                try list.name.append(' ');
            }
            try list.name.appendSlice(title);
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
                if (self.dictionary.by_form.lookup(word)) |sr| {
                    trace("list \"{s}\" add word {s}={s}", .{ list.name.items, word, uid });
                    var i = sr.iterator();
                    while (i.next()) |form| {
                        if (form.uid == id) {
                            try list.forms.append(form);
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
pub fn remove_list(self: *Self, list: *WordSet) error{OutOfMemory}!void {
    for (self.sets.items, 0..) |item, i| {
        if (item == list) {
            const found = self.sets.orderedRemove(i);
            found.destroy();
            try self.save();
            return;
        }
    }
    return;
}

/// Save the complete set of word sets to the data store.
pub fn save(self: *Self) error{OutOfMemory}!void {
    // TODO: Return file save error.
    // TODO: Write to temp file before saving.

    var data = try std.ArrayList(u8).initCapacity(self.sets.allocator, 5000);
    defer data.deinit();

    for (self.sets.items) |list| {
        data.appendSliceAssumeCapacity("list_name ");
        data.appendSliceAssumeCapacity(list.name.items);
        data.appendSliceAssumeCapacity(" end\nlist_entries ");
        for (list.forms.items) |form| {
            data.appendSliceAssumeCapacity(form.word);
            data.appendAssumeCapacity(' ');
            try data.writer().print("{d} ", .{form.uid});
        }
        data.appendSliceAssumeCapacity("end\n");
    }

    const path = sdl.SDL_GetPrefPath(ac.app_org_z(), ac.app_name_z());
    const zpath = std.mem.sliceTo(path, 0);
    var folder = std.fs.openDirAbsolute(zpath, .{}) catch |e| {
        warn("Open preferences path failed. {s} {any}", .{ path, e });
        return;
    };
    var file = folder.createFile(FILENAME, .{}) catch |e| {
        warn("Open word list file failed. {s} {any}", .{ path, e });
        return;
    };
    defer file.close();
    file.writeAll(data.items) catch |e| {
        warn("Write word list file failed. {s} {any}", .{ path, e });
        return;
    };
}

pub const WordSet = struct {
    name: ArrayList(u8),
    forms: ArrayList(*Form),

    study_items: ArrayList(*Form),

    pub fn create(allocator: Allocator) error{OutOfMemory}!*WordSet {
        var list = try allocator.create(WordSet);
        list.name = ArrayList(u8).init(allocator);
        list.forms = ArrayList(*praxis.Form).init(allocator);
        list.study_items = ArrayList(*praxis.Form).init(allocator);
        return list;
    }

    pub fn destroy(self: *WordSet) void {
        const allocator = self.forms.allocator;
        self.name.deinit();
        self.forms.deinit();
        self.study_items.deinit();
        allocator.destroy(self);
    }

    pub fn has_noun_or_adjective(self: *WordSet) bool {
        for (self.forms.items) |form| {
            if (form.parsing.part_of_speech == .noun) return true;
            if (form.parsing.part_of_speech == .adjective) return true;
            if (form.parsing.part_of_speech == .proper_noun and
                form.lexeme != null and !form.lexeme.?.pos.indeclinable) return true;
        }
        return false;
    }

    pub fn has_verb(self: *WordSet) bool {
        for (self.forms.items) |form| {
            if (form.parsing.part_of_speech == .verb) {
                return true;
            }
        }
        return false;
    }

    pub fn add(self: *WordSet, item: *Form) !bool {
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
            try self.forms.insert(i, item);
        } else {
            try self.forms.append(item);
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
    pub fn study_forms(self: *WordSet) error{OutOfMemory}![]*praxis.Form {
        self.study_items.clearRetainingCapacity();
        for (self.forms.items) |form| {
            if (form.lexeme) |lexeme| {
                for (lexeme.forms.items) |candidate| {
                    if (candidate.parsing.part_of_speech == .noun) {
                        try self.study_items.append(candidate);
                    } else if (candidate.parsing.part_of_speech == .adjective) {
                        try self.study_items.append(candidate);
                    } else if (candidate.parsing.part_of_speech == .verb) {
                        try self.study_items.append(candidate);
                    }
                }
            }
        }
        return self.study_items.items;
    }
};

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const err = engine.err;
const warn = engine.warn;
const info = engine.info;
const trace = engine.trace;
const debug = engine.debug;
const sdl = @import("dep_sdl_module");
const ac = @import("app_context.zig");
const praxis = @import("praxis");
const Form = praxis.Form;
const Dictionary = praxis.Dictionary;

test "list file" {
    var list = Self.create(std.testing.allocator);
    defer list.destroy();
    //var sets = Self.create(std.testing.allocator, dictionary);
    //defer sets.destroy();
}
