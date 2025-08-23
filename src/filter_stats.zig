//! In quiz mode, users can choose which verb and noun forms to practice.
//! It only makes sense to show grammatical form pickers for forms that
//! exist in the underlying data.

/// Hold a counter of each grammatical tags found in a data set.
pub const Stats = struct {
    present: Counter = .{},
    future: Counter = .{},
    present_future: Counter = .{},
    imperfect: Counter = .{},
    perfect: Counter = .{},
    pluperfect: Counter = .{},
    perfect_pluperfect: Counter = .{},
    aorist: Counter = .{},
    nominative: Counter = .{},
    accusative: Counter = .{},
    nominative_accusative: Counter = .{},
    genitive: Counter = .{},
    dative: Counter = .{},
    genitive_dative: Counter = .{},
    active: Counter = .{},
    middle: Counter = .{},
    passive: Counter = .{},
    middle_passive: Counter = .{},
    indicative: Counter = .{},
    imperative: Counter = .{},
    participle: Counter = .{},
    subjunctive: Counter = .{},
    optative: Counter = .{},
    infinitive: Counter = .{},
    mi: Counter = .{},
    third_declension: Counter = .{},

    pub fn count(self: *Stats, forms: []*Form) void {
        for (forms) |form| {
            const part_of_speech = form.parsing.part_of_speech;
            switch (part_of_speech) {
                .verb => {
                    self.present.update(form.parsing.tense_form == .present);
                    self.future.update(form.parsing.tense_form == .future);
                    self.imperfect.update(form.parsing.tense_form == .imperfect);
                    self.perfect.update(form.parsing.tense_form == .perfect);
                    self.pluperfect.update(form.parsing.tense_form == .pluperfect);
                    self.aorist.update(form.parsing.tense_form == .aorist);
                    self.indicative.update(form.parsing.mood == .indicative);
                    self.imperative.update(form.parsing.mood == .imperative);
                    self.subjunctive.update(form.parsing.mood == .participle);
                    self.optative.update(form.parsing.mood == .optative);
                    self.participle.update(form.parsing.mood == .participle);
                    self.infinitive.update(form.parsing.mood == .infinitive);
                    self.active.update(form.parsing.voice == .active);
                    self.middle.update(form.parsing.voice == .middle or
                        form.parsing.voice == .middle_deponent or
                        form.parsing.voice == .middle_or_passive or
                        form.parsing.voice == .middle_or_passive_deponent);
                    self.passive.update(form.parsing.voice == .passive or
                        form.parsing.voice == .passive_deponent or
                        form.parsing.voice == .middle_or_passive or
                        form.parsing.voice == .middle_or_passive_deponent);
                    if (form.lexeme) |lexeme| {
                        self.mi.update(std.mem.endsWith(u8, lexeme.word, "μι"));
                    }
                },
                .noun, .adjective, .proper_noun => {
                    if (part_of_speech == .proper_noun and (form.lexeme == null or form.lexeme.?.pos.indeclinable))
                        continue;
                    self.third_declension.update(form.parsing.tense_form == .imperfect);
                    self.nominative.update(form.parsing.case == .nominative);
                    self.accusative.update(form.parsing.case == .accusative);
                    self.genitive.update(form.parsing.case == .genitive);
                    self.dative.update(form.parsing.case == .dative);
                },
                else => {
                    err("Stats.count() called with unsupported form: {s}", .{@tagName(part_of_speech)});
                    std.debug.assert(part_of_speech == .noun or
                        part_of_speech == .adjective or
                        part_of_speech == .verb);
                },
            }
            self.present_future.match = self.present.match + self.future.match;
            self.present_future.unmatch = self.present.unmatch + self.future.unmatch;
            self.nominative_accusative.match = self.nominative.match + self.accusative.match;
            self.nominative_accusative.unmatch = self.nominative.unmatch + self.accusative.unmatch;
            self.genitive_dative.match = self.genitive.match + self.dative.match;
            self.genitive_dative.unmatch = self.genitive.unmatch + self.dative.unmatch;
            self.perfect_pluperfect.match = self.perfect.match + self.pluperfect.match;
            self.perfect_pluperfect.unmatch = self.perfect.unmatch + self.pluperfect.unmatch;
            self.middle_passive.match = self.middle.match + self.passive.match;
            self.middle_passive.unmatch = self.middle.unmatch + self.passive.unmatch;
            trace("filter has {d} nominative, {d} not.", .{
                self.nominative.match,
                self.nominative.unmatch,
            });
            trace("filter has {d} accusative, {d} not.", .{
                self.accusative.match,
                self.accusative.unmatch,
            });
            trace("filter has {d} nominative_accusative, {d} not.", .{
                self.nominative_accusative.match,
                self.nominative_accusative.unmatch,
            });
            trace("filter has {d} genitive_dative, {d} not.", .{
                self.genitive_dative.match,
                self.genitive_dative.unmatch,
            });
        }
    }
};

pub const Counter = struct {
    match: usize = 0,
    unmatch: usize = 0,

    pub fn update(self: *Counter, match: bool) void {
        if (match) {
            self.match += 1;
        } else {
            self.unmatch += 1;
        }
    }
};

/// Check if a form belongs to a lexeme with enough data to study
/// and that data is supported by the quiz card code.
pub inline fn can_practice_form(form: *Form) bool {
    if (form.lexeme == null)
        return false;
    if (form.lexeme.?.forms.items.len < 2)
        return false;
    const pos = form.parsing.part_of_speech;
    if (pos == .noun or pos == .adjective or pos == .verb) {
        return true;
    }
    if (pos == .proper_noun and form.lexeme.?.pos.indeclinable == false)
        return true;
    return false;
}

/// Check if a lexeme has enough data to study
/// and that data is supported by the quiz card code.
pub inline fn can_practice_lexeme(lexeme: *Lexeme) bool {
    if (lexeme.forms.items.len < 2)
        return false;
    const pos = lexeme.pos.part_of_speech;
    if (pos == .noun or pos == .adjective or pos == .verb) {
        return true;
    }
    if (pos == .proper_noun and lexeme.pos.indeclinable == false)
        return true;
    return false;
}

const std = @import("std");
const praxis = @import("praxis");
const engine = @import("engine");
const trace = engine.trace;
const err = engine.err;
const Form = praxis.Form;
const Lexeme = praxis.Lexeme;
