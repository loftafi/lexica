/// A simple flashcard deck of word forms. The word forms may be from an
/// individual lexeme, or a set of lexemes.
const ParsingQuiz = @This();

lexeme: ?*praxis.Lexeme = null,
word_set: ?*WordSet = null,

form_bank: ArrayListUnmanaged(*praxis.Form) = undefined,
all_forms: ArrayListUnmanaged(*praxis.Form) = undefined,
total_cards: usize = 0,

const ignores = [_][]const u8{"δώσωσιν"};
const non_endings = [_][]const u8{ "έω", "εω", "άω", "αω", "όω", "οω" };

pub fn init(self: *ParsingQuiz, _: Allocator) !void {
    self.form_bank = .empty;
    self.all_forms = .empty;
}

pub fn deinit(self: *ParsingQuiz, gpa: Allocator) void {
    self.form_bank.deinit(gpa);
    self.all_forms.deinit(gpa);
}

pub fn clear(self: *ParsingQuiz, _: Allocator) void {
    self.form_bank.clearRetainingCapacity();
    self.all_forms.clearRetainingCapacity();
    self.word_set = null;
    self.lexeme = null;
}

/// Rebuild this deck with the forms from a specific `lexeme`.
pub fn setupWithLexeme(
    self: *ParsingQuiz,
    gpa: Allocator,
    lexeme: *praxis.Lexeme,
    app: *App,
) error{OutOfMemory}!void {
    self.lexeme = lexeme;
    self.word_set = null;
    self.form_bank.clearRetainingCapacity();
    self.all_forms.clearRetainingCapacity();

    for (lexeme.forms.items) |form| {
        try self.includeForm(form, app);
    }

    notice("setup_with_lexeme: parsing quiz bank for {s} filtered from {d} to {d} forms.", .{
        lexeme.word,
        lexeme.forms.items.len,
        self.form_bank.items.len,
    });
    if (engine.dev_mode == true) {
        for (self.form_bank.items) |form| {
            var ps: std.Io.Writer.Allocating = .init(gpa);
            defer ps.deinit();
            form.parsing.string(&ps.writer) catch {};
            debug("  {s} {s}", .{ form.word, ps.written() });
        }
    }

    self.total_cards = self.form_bank.items.len;
}

/// Rebuild this deck with the forms from a `lexeme` list.
pub fn setupWithWordSet(
    self: *ParsingQuiz,
    gpa: Allocator,
    word_set: *WordSet,
    app: *App,
) error{OutOfMemory}!void {
    self.word_set = word_set;
    self.lexeme = null;
    self.form_bank.clearRetainingCapacity();
    self.all_forms.clearRetainingCapacity();

    for (word_set.forms.items) |form| {
        if (form.lexeme) |lexeme| {
            for (lexeme.forms.items) |item| {
                try self.includeForm(item, app);
            }
        }
    }

    notice("setup_with_word_set: parsing quiz bank for {s} filtered from {d} to {d} forms.", .{
        word_set.name.items,
        self.all_forms.items.len,
        self.form_bank.items.len,
    });
    if (engine.dev_mode == true) {
        for (self.form_bank.items) |form| {
            var ps: std.Io.Writer.Allocating = .init(gpa);
            defer ps.deinit();
            form.parsing.string(&ps.writer) catch {};
            debug("  {s} {s}", .{ form.word, ps.written() });
        }
    }

    self.total_cards = self.form_bank.items.len;
}

fn includeForm(
    self: *ParsingQuiz,
    form: *praxis.Form,
    app: *App,
) error{OutOfMemory}!void {
    for (ignores) |ignore| {
        if (std.mem.eql(u8, ignore, form.word)) {
            return;
        }
    }
    if (form.parsing.part_of_speech == .verb) {
        if (App.study_optative == false and form.parsing.mood == .optative) {
            return;
        }
        for (non_endings) |ending| {
            if (std.mem.endsWith(u8, form.word, ending)) {
                return;
            }
        }
        if (app.preference.indicative != true and app.preference.infinitive != true and
            app.preference.imperative != true and app.preference.subjunctive != true and
            app.preference.participle != true)
        {
            warn("Verb has non valid mood", .{});
            return;
        }
        try self.all_forms.append(app.allocator, form);
        if (!app.preference.present_future) {
            if (form.parsing.tense_form == .future or form.parsing.tense_form == .present) {
                return;
            }
        }
        if (!app.preference.aorist and form.parsing.tense_form == .aorist) {
            return;
        }
        if (!app.preference.imperfect and form.parsing.tense_form == .imperfect) {
            return;
        }
        if (!app.preference.perfect_pluperfect) {
            if (form.parsing.tense_form == .perfect or form.parsing.tense_form == .pluperfect) {
                return;
            }
        }
        if (!app.preference.middle_passive) {
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
        if (!app.preference.indicative and form.parsing.mood == .indicative) {
            return;
        }
        if (!app.preference.infinitive and form.parsing.mood == .infinitive) {
            return;
        }
        if (!app.preference.imperative and form.parsing.mood == .imperative) {
            return;
        }
        if (!app.preference.subjunctive and form.parsing.mood == .subjunctive) {
            return;
        }
        if (!app.preference.participle and form.parsing.mood == .participle) {
            return;
        }
    } else if (form.parsing.part_of_speech == .noun or form.parsing.part_of_speech == .adjective or form.parsing.part_of_speech == .proper_noun or form.parsing.part_of_speech == .personal_pronoun) {
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
        try self.all_forms.append(app.allocator, form);
        if (!app.preference.nominative_accusative) {
            if (form.parsing.case == .nominative or form.parsing.case == .accusative) {
                return;
            }
        }
        if (!app.preference.genitive_dative) {
            if (form.parsing.case == .genitive or form.parsing.case == .dative) {
                return;
            }
        }
    } else {
        var ps: std.Io.Writer.Allocating = .init(app.allocator);
        defer ps.deinit();
        form.parsing.string(&ps.writer) catch {};
        warn("Skip unsupported form {s} for wordbank. {s} {s}", .{
            @tagName(form.parsing.part_of_speech),
            form.word,
            ps.written(),
        });
        return;
    }
    try self.form_bank.append(app.allocator, form);
}

pub fn progress(self: *ParsingQuiz) f32 {
    if (self.form_bank.items.len == 0 or self.total_cards == 0) {
        return 1;
    }
    return @as(f32, @floatFromInt(self.total_cards - self.form_bank.items.len)) / @as(f32, @floatFromInt(self.total_cards));
}

pub fn next_form(self: *ParsingQuiz) *praxis.Form {
    const cards = &self.form_bank.items;
    const choose = random.random(cards.len);
    const form = cards.*[choose];
    cards.*[choose] = cards.*[0];
    cards.*[0] = form;
    return form;
}

pub fn remove_current_form(self: *ParsingQuiz) usize {
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
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const engine = @import("engine");
const err = engine.log.err;
const warn = engine.log.warn;
const info = engine.log.info;
const debug = engine.log.debug;
const notice = engine.log.notice;

const resources = @import("resources");
const random = praxis.random;
const praxis = @import("praxis");

const App = @import("App.zig");
const Lists = @import("Lists.zig");
const WordSet = Lists.WordSet;
