//! A Parsing Quiz allows studying the forms associated with a `lexeme` or
//! a word study `set`.  It collects each form to be studied. Each form
//! is then removed from the study bank as the user completes the quiz.

lexeme: ?*praxis.Lexeme = null,
word_set: ?*WordSet = null,

form_bank: ArrayList(*praxis.Form) = undefined,
all_forms: ArrayList(*praxis.Form) = undefined,
total_cards: usize = 0,

const Self = @This();

const ignores = [_][]const u8{"δώσωσιν"};
const non_endings = [_][]const u8{ "έω", "εω", "άω", "αω", "όω", "οω" };

pub fn init(self: *Self, allocator: Allocator) !void {
    self.form_bank = ArrayList(*praxis.Form).init(allocator);
    self.all_forms = ArrayList(*praxis.Form).init(allocator);
}

pub fn deinit(self: *Self) void {
    self.form_bank.deinit();
    self.all_forms.deinit();
}

pub fn clear(self: *Self) void {
    self.form_bank.clearRetainingCapacity();
    self.all_forms.clearRetainingCapacity();
    self.word_set = null;
    self.lexeme = null;
}

pub fn setup_with_lexeme(self: *Self, lexeme: *praxis.Lexeme) error{OutOfMemory}!void {
    const ac = app.app_context.?;

    self.lexeme = lexeme;
    self.word_set = null;
    self.form_bank.clearRetainingCapacity();
    self.all_forms.clearRetainingCapacity();

    for (lexeme.forms.items) |form| {
        try self.include_form(form);
    }

    info("parsing quiz bank for {s} filtered from {d} to {d} forms.", .{
        lexeme.word,
        lexeme.forms.items.len,
        self.form_bank.items.len,
    });
    if (engine.dev_mode == true) {
        for (self.form_bank.items) |form| {
            var ps: std.ArrayListUnmanaged(u8) = .empty;
            form.parsing.string(ps.writer(ac.allocator)) catch {};
            debug("  {s} {s}", .{ form.word, ps.items });
            ps.deinit(ac.allocator);
        }
    }

    self.total_cards = self.form_bank.items.len;
}

pub fn setup_with_word_set(self: *Self, word_set: *WordSet) error{OutOfMemory}!void {
    const ac = app.app_context.?;

    self.word_set = word_set;
    self.lexeme = null;
    self.form_bank.clearRetainingCapacity();
    self.all_forms.clearRetainingCapacity();

    for (word_set.forms.items) |form| {
        if (form.lexeme) |lexeme| {
            for (lexeme.forms.items) |item| {
                try self.include_form(item);
            }
        }
    }

    info("parsing quiz bank for {s} filtered from {d} to {d} forms.", .{
        word_set.name.items,
        self.all_forms.items.len,
        self.form_bank.items.len,
    });
    if (engine.dev_mode == true) {
        for (self.form_bank.items) |form| {
            var ps: std.ArrayListUnmanaged(u8) = .empty;
            form.parsing.string(ps.writer(ac.allocator)) catch {};
            debug("  {s} {s}", .{ form.word, ps.items });
            ps.deinit(ac.allocator);
        }
    }

    self.total_cards = self.form_bank.items.len;
}

pub fn include_form(self: *Self, form: *praxis.Form) error{OutOfMemory}!void {
    const ac = app.app_context.?;

    for (ignores) |ignore| {
        if (std.mem.eql(u8, ignore, form.word)) {
            return;
        }
    }
    if (form.parsing.part_of_speech == .verb) {
        for (non_endings) |ending| {
            if (std.mem.endsWith(u8, form.word, ending)) {
                return;
            }
        }
        if (ac.preference.indicative != true and ac.preference.infinitive != true and
            ac.preference.imperative != true and ac.preference.subjunctive != true and
            ac.preference.participle != true)
        {
            warn("Verb has non valid mood", .{});
            return;
        }
        try self.all_forms.append(form);
        if (!ac.preference.present_future) {
            if (form.parsing.tense_form == .future or form.parsing.tense_form == .present) {
                return;
            }
        }
        if (!ac.preference.aorist and form.parsing.tense_form == .aorist) {
            return;
        }
        if (!ac.preference.imperfect and form.parsing.tense_form == .imperfect) {
            return;
        }
        if (!ac.preference.perfect_pluperfect) {
            if (form.parsing.tense_form == .perfect or form.parsing.tense_form == .pluperfect) {
                return;
            }
        }
        if (!ac.preference.middle_passive) {
            if (form.parsing.voice == .middle or
                form.parsing.voice == .middle_or_passive or
                form.parsing.voice == .passive or
                form.parsing.voice == .middle_deponent or
                form.parsing.voice == .middle_or_passive_deponent or
                form.parsing.voice == .passive_deponent)
            {
                return;
            }
        }
        if (!ac.preference.indicative and form.parsing.mood == .indicative) {
            return;
        }
        if (!ac.preference.infinitive and form.parsing.mood == .infinitive) {
            return;
        }
        if (!ac.preference.imperative and form.parsing.mood == .imperative) {
            return;
        }
        if (!ac.preference.subjunctive and form.parsing.mood == .subjunctive) {
            return;
        }
        if (!ac.preference.participle and form.parsing.mood == .participle) {
            return;
        }
    } else if (form.parsing.part_of_speech == .noun or form.parsing.part_of_speech == .adjective or form.parsing.part_of_speech == .proper_noun) {
        if (self.lexeme) |lexeme| {
            if (lexeme.pos.part_of_speech == .verb and form.parsing.part_of_speech != .verb)
                return;
            if (lexeme.pos.part_of_speech == .adjective and form.parsing.part_of_speech != .adjective)
                return;
            if (lexeme.pos.part_of_speech == .noun or lexeme.pos.part_of_speech == .proper_noun) {
                if (form.parsing.part_of_speech != .noun and form.parsing.part_of_speech != .proper_noun)
                    return;
                if (lexeme.pos.indeclinable)
                    return;
            }
        }
        if (form.parsing.case == .vocative) {
            return;
        }
        try self.all_forms.append(form);
        if (!ac.preference.nominative_accusative) {
            if (form.parsing.case == .nominative or form.parsing.case == .accusative) {
                //debug("skipping nominative/accusative {any} {s}", .{ ac.preference.nominative_accusative, @tagName(form.parsing.case) });
                return;
            }
        }
        if (!ac.preference.genitive_dative) {
            if (form.parsing.case == .genitive or form.parsing.case == .dative) {
                return;
            }
        }
    } else {
        var ps: std.ArrayListUnmanaged(u8) = .empty;
        form.parsing.string(ps.writer(self.form_bank.allocator)) catch {};
        warn("Skip unsupported form for wordbank. {s} {s}", .{ form.word, ps.items });
        ps.deinit(self.form_bank.allocator);
        return;
    }
    try self.form_bank.append(form);
}

pub fn progress(self: *Self) f32 {
    if (self.form_bank.items.len == 0 or self.total_cards == 0) {
        return 1;
    }
    return @as(f32, @floatFromInt(self.total_cards - self.form_bank.items.len)) / @as(f32, @floatFromInt(self.total_cards));
}

pub fn next_form(self: *Self) *praxis.Form {
    const cards = &self.form_bank.items;
    const choose = random(cards.len);
    const form = cards.*[choose];
    cards.*[choose] = cards.*[0];
    cards.*[0] = form;
    return form;
}

pub fn remove_current_form(self: *Self) usize {
    var cards = &self.form_bank;
    if (cards.items.len == 0) {
        debug("No more cards to remove", .{});
        return 0;
    } else if (cards.items.len == 1) {
        cards.clearRetainingCapacity();
        debug("Removed last card", .{});
        return 0;
    }
    debug("Removing one card. len={}", .{cards.items.len});
    _ = cards.swapRemove(0);
    return cards.items.len;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Lists = @import("lists.zig");
const WordSet = @import("lists.zig").WordSet;
const resources = @import("resources");
const random = resources.random;
const praxis = @import("praxis");
const engine = @import("engine");
const app = @import("app_context.zig");
const err = engine.err;
const warn = engine.warn;
const info = engine.info;
const debug = engine.debug;
