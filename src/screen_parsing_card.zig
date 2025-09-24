const PARSING_BUTTON_X_PADDING: f32 = 16.0;
const PARSING_BUTTON_Y_PADDING: f32 = 10.0 + 4;

var panel: *Element = undefined;
var quiz_word: *Element = undefined;
var help_line: *Element = undefined;
var correct_panel: *Element = undefined;
var incorrect_panel: *Element = undefined;
var back_button: *Element = undefined;

pub fn show(display: *Display, element: *Element) error{OutOfMemory}!void {
    const ctx = ac.app_context.?;
    const allocator = ctx.allocator;

    if (ctx.parsing_quiz.form_bank.items.len == 0) {
        warn("Not starting quiz. Form bank has no words.", .{});
        return;
    }
    info("Starting quiz. Form bank has {d} words.", .{
        ctx.parsing_quiz.form_bank.items.len,
    });

    display.choose_panel("parsing.quiz");
    if (!try show_next_quiz_card(display)) {
        try ParsingMenuScreen.show(display, element);
    }

    try slide_panel_out(display);
    MenuUI.progress_bar.type.progress_bar.progress = 0;
    MenuUI.progress_bar.visible = .visible;
    MenuUI.toolbar.visible = .hidden;
    _ = MenuUI.align_progress_bar(display, MenuUI.progress_bar);

    // Adjust order of case buttons depending on user preference
    if (ac.app_context.?.preference.uk_order) {
        trace("Case buttons in UK order", .{});
        pickers.case.type.panel.children.clearRetainingCapacity();
        try pickers.case.type.panel.children.append(allocator, buttons.nominative);
        try pickers.case.type.panel.children.append(allocator, buttons.accusative);
        try pickers.case.type.panel.children.append(allocator, buttons.genitive);
        try pickers.case.type.panel.children.append(allocator, buttons.dative);
        display.need_relayout = true;
    } else {
        trace("Case buttons in US order", .{});
        pickers.case.type.panel.children.clearRetainingCapacity();
        try pickers.case.type.panel.children.append(allocator, buttons.nominative);
        try pickers.case.type.panel.children.append(allocator, buttons.genitive);
        try pickers.case.type.panel.children.append(allocator, buttons.dative);
        try pickers.case.type.panel.children.append(allocator, buttons.accusative);
        display.need_relayout = true;
    }
}

pub fn deinit() void {
    //
}

pub fn cancel_quiz(display: *Display, element: *Element) error{OutOfMemory}!void {
    MenuUI.progress_bar.visible = .hidden;
    MenuUI.toolbar.visible = .visible;
    correct_panel.visible = .hidden;
    incorrect_panel.visible = .hidden;

    const pc = ac.app_context.?.parsing_quiz;
    if (pc.lexeme) |lexeme| {
        try ParsingSetupScreen.study_by_form(display, lexeme, ParsingSetupScreen.called_by);
    } else if (pc.word_set) |list| {
        try ParsingSetupScreen.study_by_list(display, list, ParsingSetupScreen.called_by);
    } else {
        try ParsingMenuScreen.show(display, element);
    }
}

var pickers = struct {
    case: *Element = undefined,
    gender: *Element = undefined,
    number: *Element = undefined,

    tense_form: *Element = undefined,
    voice: *Element = undefined,
    mood: *Element = undefined,
    person: *Element = undefined,
}{};

var buttons = struct {
    nominative: *Element = undefined,
    accusative: *Element = undefined,
    genitive: *Element = undefined,
    dative: *Element = undefined,
    singular: *Element = undefined,
    plural: *Element = undefined,
    masculine: *Element = undefined,
    feminine: *Element = undefined,
    neuter: *Element = undefined,
    present: *Element = undefined,
    future: *Element = undefined,
    imperfect: *Element = undefined,
    aorist: *Element = undefined,
    perfect: *Element = undefined,
    pluperfect: *Element = undefined,
    active: *Element = undefined,
    middle: *Element = undefined,
    passive: *Element = undefined,
    indicative: *Element = undefined,
    participle: *Element = undefined,
    subjunctive: *Element = undefined,
    imperative: *Element = undefined,
    infinitive: *Element = undefined,
    first: *Element = undefined,
    second: *Element = undefined,
    third: *Element = undefined,

    const Self = @This();

    pub fn list(b: *Self) [26]*Element {
        return .{
            b.present,    b.future,     b.aorist,      b.imperfect,
            b.perfect,    b.pluperfect, b.active,      b.middle,
            b.passive,    b.indicative, b.subjunctive, b.participle,
            b.imperative, b.infinitive, b.first,       b.second,
            b.third,      b.singular,   b.plural,      b.nominative,
            b.accusative, b.genitive,   b.dative,      b.masculine,
            b.feminine,   b.neuter,
        };
    }

    fn lock_unpicked_toggles(self: *Self) void {
        for (&self.list()) |*button| {
            if (button.*.type.button.toggle == .off) {
                button.*.type.button.toggle = .locked_off;
            }
        }
    }

    fn clear_options(self: *Self) void {
        for (&self.list()) |*button| {
            button.*.type.button.toggle = .off;
        }
    }

    fn options_picked(self: *Self, form: *praxis.Form) ?praxis.Parsing {
        var parsing: praxis.Parsing = .{
            .part_of_speech = ac.app_context.?.parsing_quiz.form_bank.items[0].parsing.part_of_speech,
        };
        var count: usize = 0;
        switch (form.parsing.part_of_speech) {
            .verb => {
                parsing.part_of_speech = .verb;

                // Tense form
                if (self.present.type.button.toggle == .on) {
                    parsing.tense_form = .present;
                    count += 1;
                } else if (self.future.type.button.toggle == .on) {
                    parsing.tense_form = .future;
                    count += 1;
                } else if (self.imperfect.type.button.toggle == .on) {
                    parsing.tense_form = .imperfect;
                    count += 1;
                } else if (self.aorist.type.button.toggle == .on) {
                    parsing.tense_form = .aorist;
                    count += 1;
                } else if (self.perfect.type.button.toggle == .on) {
                    parsing.tense_form = .perfect;
                    count += 1;
                } else if (self.pluperfect.type.button.toggle == .on) {
                    parsing.tense_form = .pluperfect;
                    count += 1;
                }

                // Voice
                if (self.active.type.button.toggle == .on) {
                    parsing.voice = .active;
                    count += 1;
                } else if (self.middle.type.button.toggle == .on) {
                    parsing.voice = .middle;
                    count += 1;
                } else if (self.passive.type.button.toggle == .on) {
                    parsing.voice = .passive;
                    count += 1;
                }

                if (self.indicative.type.button.toggle == .on) {
                    parsing.mood = .indicative;
                    count += 1;
                } else if (self.participle.type.button.toggle == .on) {
                    parsing.mood = .participle;
                    count += 1;
                } else if (self.subjunctive.type.button.toggle == .on) {
                    parsing.mood = .subjunctive;
                    count += 1;
                } else if (self.imperative.type.button.toggle == .on) {
                    parsing.mood = .imperative;
                    count += 1;
                } else if (self.infinitive.type.button.toggle == .on) {
                    parsing.mood = .infinitive;
                    count += 1;
                }

                if (form.parsing.mood != .participle) {
                    if (self.first.type.button.toggle == .on) {
                        parsing.person = .first;
                        count += 1;
                    } else if (self.second.type.button.toggle == .on) {
                        parsing.person = .second;
                        count += 1;
                    } else if (self.third.type.button.toggle == .on) {
                        parsing.person = .third;
                        count += 1;
                    }

                    if (self.singular.type.button.toggle == .on) {
                        parsing.number = .singular;
                        count += 1;
                    } else if (self.plural.type.button.toggle == .on) {
                        parsing.number = .plural;
                        count += 1;
                    }

                    if (count > 4) {
                        return parsing;
                    } else {
                        return null;
                    }
                } else {
                    if (self.nominative.type.button.toggle == .on) {
                        parsing.case = .nominative;
                        count += 1;
                    } else if (self.accusative.type.button.toggle == .on) {
                        parsing.case = .accusative;
                        count += 1;
                    } else if (self.dative.type.button.toggle == .on) {
                        parsing.case = .dative;
                        count += 1;
                    } else if (self.genitive.type.button.toggle == .on) {
                        parsing.case = .genitive;
                        count += 1;
                    }

                    // Number
                    if (self.singular.type.button.toggle == .on) {
                        parsing.number = .singular;
                        count += 1;
                    } else if (self.plural.type.button.toggle == .on) {
                        parsing.number = .plural;
                        count += 1;
                    }

                    // Gender
                    if (self.masculine.type.button.toggle == .on) {
                        parsing.gender = .masculine;
                        count += 1;
                    } else if (self.feminine.type.button.toggle == .on) {
                        parsing.gender = .feminine;
                        count += 1;
                    } else if (self.neuter.type.button.toggle == .on) {
                        parsing.gender = .neuter;
                        count += 1;
                    }

                    //trace("current choice: {any} count: {d}", .{ parsing, count });
                    if (count > 5) {
                        return parsing;
                    } else {
                        return null;
                    }
                }
            },
            .personal_pronoun => {
                // Person
                if (self.first.type.button.toggle == .on) {
                    parsing.person = .first;
                    count += 1;
                } else if (self.second.type.button.toggle == .on) {
                    parsing.person = .second;
                    count += 1;
                } else if (self.third.type.button.toggle == .on) {
                    parsing.person = .third;
                    count += 1;
                }

                // Case
                if (self.nominative.type.button.toggle == .on) {
                    parsing.case = .nominative;
                    count += 1;
                } else if (self.accusative.type.button.toggle == .on) {
                    parsing.case = .accusative;
                    count += 1;
                } else if (self.dative.type.button.toggle == .on) {
                    parsing.case = .dative;
                    count += 1;
                } else if (self.genitive.type.button.toggle == .on) {
                    parsing.case = .genitive;
                    count += 1;
                }

                if (form.lexeme) |lexeme| {
                    if (std.mem.eql(u8, lexeme.word, "αὐτός")) {

                        // Number
                        if (self.singular.type.button.toggle == .on) {
                            parsing.number = .singular;
                            count += 1;
                        } else if (self.plural.type.button.toggle == .on) {
                            parsing.number = .plural;
                            count += 1;
                        }

                        if (self.masculine.type.button.toggle == .on) {
                            parsing.gender = .masculine;
                            count += 1;
                        } else if (self.feminine.type.button.toggle == .on) {
                            parsing.gender = .feminine;
                            count += 1;
                        } else if (self.neuter.type.button.toggle == .on) {
                            parsing.gender = .neuter;
                            count += 1;
                        }
                        if (count > 3) {
                            return parsing;
                        }
                        return null;
                    }
                }

                // Number
                if (self.singular.type.button.toggle == .on) {
                    parsing.tense_form = .ref_singular;
                    count += 1;
                } else if (self.plural.type.button.toggle == .on) {
                    parsing.tense_form = .ref_plural;
                    count += 1;
                }

                if (count > 2) {
                    return parsing;
                } else {
                    return null;
                }
            },
            .noun, .adjective, .proper_noun => {
                // Case
                if (self.nominative.type.button.toggle == .on) {
                    parsing.case = .nominative;
                    count += 1;
                } else if (self.accusative.type.button.toggle == .on) {
                    parsing.case = .accusative;
                    count += 1;
                } else if (self.dative.type.button.toggle == .on) {
                    parsing.case = .dative;
                    count += 1;
                } else if (self.genitive.type.button.toggle == .on) {
                    parsing.case = .genitive;
                    count += 1;
                }

                // Number
                if (self.singular.type.button.toggle == .on) {
                    parsing.number = .singular;
                    count += 1;
                } else if (self.plural.type.button.toggle == .on) {
                    parsing.number = .plural;
                    count += 1;
                }

                if (self.masculine.type.button.toggle == .on) {
                    parsing.gender = .masculine;
                    count += 1;
                } else if (self.feminine.type.button.toggle == .on) {
                    parsing.gender = .feminine;
                    count += 1;
                } else if (self.neuter.type.button.toggle == .on) {
                    parsing.gender = .neuter;
                    count += 1;
                }

                if (count > 2) {
                    return parsing;
                } else {
                    return null;
                }
            },
            else => {
                err("Options picked cant handle {s}", .{@tagName(form.parsing.part_of_speech)});
                return null;
            },
        }
    }

    fn mark_button(toggle: *ToggleState, expect: bool) void {
        if (toggle.* == .on) {
            if (expect) {
                toggle.* = .correct;
            } else {
                toggle.* = .incorrect;
            }
        } else if (expect) {
            toggle.* = .on;
        }
    }

    fn mark_answers(self: *Self, form: *praxis.Form, user_choice: praxis.Parsing, gpa: std.mem.Allocator) error{OutOfMemory}!bool {
        var expected_parsing = form.parsing;
        var clean_choice = user_choice;

        // Special handling for αὐτός.
        if (form.lexeme != null and
            std.mem.eql(u8, form.lexeme.?.word, "αὐτός") and
            form.parsing.part_of_speech == .personal_pronoun)
        {
            // If third person is not picked,
            if (expected_parsing.person != .third) {
                // Dont clear the third person field because its not in the
                // parsing table. This will (correctly) cause the error dialogue
                // box to appear
            } else {
                expected_parsing.person = .unknown;
            }
            clean_choice.person = .unknown;
        }

        const parsing = form.parsing;
        var correct: bool = false;

        // There may be one or more parsing options for a given form.
        var valid_forms: std.ArrayListUnmanaged(*praxis.Form) = .empty;
        defer valid_forms.deinit(gpa);
        if (form.lexeme == null) {
            try valid_forms.append(gpa, form);
            if (user_choice == form.parsing) correct = true;
        } else {
            for (form.lexeme.?.forms.items) |item| {
                if (std.mem.eql(u8, form.word, item.word)) {
                    if (clean_choice == item.parsing) correct = true;
                    try valid_forms.append(gpa, item);
                    info("checkmatch {s} {any} {any}", .{ form.word, item.parsing, user_choice });
                }
            }
        }

        var oo: std.ArrayListUnmanaged(u8) = .empty;
        defer oo.deinit(gpa);
        for (valid_forms.items) |vf| {
            vf.parsing.string(oo.writer(gpa)) catch {};
            try oo.append(gpa, ' ');
        }
        info("check {s} (count={d}) matched {any}", .{ oo.items, valid_forms.items.len, correct });

        switch (form.parsing.part_of_speech) {
            .verb => {

                // Tense form
                mark_button(&self.present.type.button.toggle, formsHaveTenseForm(valid_forms.items, .present));
                mark_button(&self.future.type.button.toggle, formsHaveTenseForm(valid_forms.items, .future));
                mark_button(&self.imperfect.type.button.toggle, formsHaveTenseForm(valid_forms.items, .imperfect));
                mark_button(&self.aorist.type.button.toggle, formsHaveTenseForm(valid_forms.items, .aorist));
                mark_button(&self.perfect.type.button.toggle, formsHaveTenseForm(valid_forms.items, .perfect));
                mark_button(&self.pluperfect.type.button.toggle, formsHaveTenseForm(valid_forms.items, .pluperfect));

                // Voice
                mark_button(&self.active.type.button.toggle, formsHaveVoice(valid_forms.items, .active));
                mark_button(&self.middle.type.button.toggle, formsHaveVoice(valid_forms.items, .middle));
                mark_button(&self.passive.type.button.toggle, formsHaveVoice(valid_forms.items, .passive));

                // Mood
                mark_button(&self.indicative.type.button.toggle, formsHaveMood(valid_forms.items, .indicative));
                mark_button(&self.participle.type.button.toggle, formsHaveMood(valid_forms.items, .participle));
                mark_button(&self.subjunctive.type.button.toggle, formsHaveMood(valid_forms.items, .subjunctive));
                mark_button(&self.imperative.type.button.toggle, formsHaveMood(valid_forms.items, .imperative));
                mark_button(&self.infinitive.type.button.toggle, formsHaveMood(valid_forms.items, .infinitive));

                if (parsing.mood == .participle) {
                    // Case
                    mark_button(&self.nominative.type.button.toggle, formsHaveCase(valid_forms.items, .nominative));
                    mark_button(&self.accusative.type.button.toggle, formsHaveCase(valid_forms.items, .accusative));
                    mark_button(&self.dative.type.button.toggle, formsHaveCase(valid_forms.items, .dative));
                    mark_button(&self.genitive.type.button.toggle, formsHaveCase(valid_forms.items, .genitive));

                    // Person
                    mark_button(&self.singular.type.button.toggle, formsHaveNumber(valid_forms.items, .singular));
                    mark_button(&self.plural.type.button.toggle, formsHaveNumber(valid_forms.items, .plural));

                    // Gender
                    mark_button(&self.masculine.type.button.toggle, formsHaveGender(valid_forms.items, .masculine));
                    mark_button(&self.feminine.type.button.toggle, formsHaveGender(valid_forms.items, .feminine));
                    mark_button(&self.neuter.type.button.toggle, formsHaveGender(valid_forms.items, .neuter));
                } else {
                    // Person
                    mark_button(&self.first.type.button.toggle, formsHavePerson(valid_forms.items, .first));
                    mark_button(&self.second.type.button.toggle, formsHavePerson(valid_forms.items, .second));
                    mark_button(&self.third.type.button.toggle, formsHavePerson(valid_forms.items, .third));

                    // Number
                    mark_button(&self.singular.type.button.toggle, formsHaveNumber(valid_forms.items, .singular));
                    mark_button(&self.plural.type.button.toggle, formsHaveNumber(valid_forms.items, .plural));
                }
            },

            .personal_pronoun => {
                if (form.lexeme) |lexeme| {
                    if (std.mem.eql(u8, lexeme.word, "αὐτός")) {
                        // Gender
                        mark_button(&self.masculine.type.button.toggle, formsHaveGender(valid_forms.items, .masculine));
                        mark_button(&self.feminine.type.button.toggle, formsHaveGender(valid_forms.items, .feminine));
                        mark_button(&self.neuter.type.button.toggle, formsHaveGender(valid_forms.items, .neuter));

                        // Person
                        mark_button(&self.first.type.button.toggle, false);
                        mark_button(&self.second.type.button.toggle, false);
                        mark_button(&self.third.type.button.toggle, true);

                        // Number
                        mark_button(&self.singular.type.button.toggle, formsHaveNumber(valid_forms.items, .singular));
                        mark_button(&self.plural.type.button.toggle, formsHaveNumber(valid_forms.items, .plural));
                    }
                } else {
                    // Person
                    mark_button(&self.first.type.button.toggle, formsHavePerson(valid_forms.items, .first));
                    mark_button(&self.second.type.button.toggle, formsHavePerson(valid_forms.items, .second));
                    mark_button(&self.third.type.button.toggle, formsHavePerson(valid_forms.items, .third));

                    // Number
                    mark_button(&self.singular.type.button.toggle, formsHaveRefNumber(valid_forms.items, .ref_singular));
                    mark_button(&self.plural.type.button.toggle, formsHaveRefNumber(valid_forms.items, .ref_plural));
                }

                // Case
                mark_button(&self.nominative.type.button.toggle, formsHaveCase(valid_forms.items, .nominative));
                mark_button(&self.accusative.type.button.toggle, formsHaveCase(valid_forms.items, .accusative));
                mark_button(&self.dative.type.button.toggle, formsHaveCase(valid_forms.items, .dative));
                mark_button(&self.genitive.type.button.toggle, formsHaveCase(valid_forms.items, .genitive));
            },

            .noun, .adjective => {
                // Case
                mark_button(&self.nominative.type.button.toggle, formsHaveCase(valid_forms.items, .nominative));
                mark_button(&self.accusative.type.button.toggle, formsHaveCase(valid_forms.items, .accusative));
                mark_button(&self.dative.type.button.toggle, formsHaveCase(valid_forms.items, .dative));
                mark_button(&self.genitive.type.button.toggle, formsHaveCase(valid_forms.items, .genitive));

                // Person
                mark_button(&self.singular.type.button.toggle, formsHaveNumber(valid_forms.items, .singular));
                mark_button(&self.plural.type.button.toggle, formsHaveNumber(valid_forms.items, .plural));

                // Gender
                mark_button(&self.masculine.type.button.toggle, formsHaveGender(valid_forms.items, .masculine));
                mark_button(&self.feminine.type.button.toggle, formsHaveGender(valid_forms.items, .feminine));
                mark_button(&self.neuter.type.button.toggle, formsHaveGender(valid_forms.items, .neuter));
            },
            else => {
                err("mark_answers() unimplemented for {s}", .{@tagName(parsing.part_of_speech)});
            },
        }
        return correct;
    }
}{};

pub fn init(context: *AppContext) (error{
    OutOfMemory,
    ResourceNotFound,
    ResourceReadError,
    UnknownImageFormat,
} || ResourcesError)!void {
    var display = context.display;
    const allocator = context.allocator;

    seed();
    help_line_buffer_i = 0;

    panel = try display.root.add_alloc(allocator, display, .{
        .name = "parsing.quiz",
        .rect = .{ .x = 20, .y = 20 },
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .visible = .hidden,
        .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        .on_resized = handle_resize,
    });

    back_button = try display.add_back_button(allocator, panel, cancel_quiz);

    _ = try display.add_spacer(allocator, panel, 1);

    quiz_word = try panel.add_alloc(allocator, display, .{
        .name = "parsing.quiz.word",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "λυω",
            .text_size = .heading,
            .text_colour = .tinted,
        } },
        .pad = .{ .top = 30 + 60 },
    });

    help_line = try panel.add_alloc(allocator, display, .{
        .name = "parsing.quiz.hint",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Describe the grammar of this word.",
            .text_size = .normal,
            .text_colour = .normal,
        } },
    });

    _ = try panel.add_alloc(allocator, display, .{
        .name = "top.expander",
        .rect = .{ .width = 100, .height = 20 },
        .minimum = .{ .width = 100, .height = 20 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 0.7 } },
    });

    {
        pickers.tense_form = try panel.add_alloc(allocator, display, .{
            .name = "tense_form.picker",
            .background_texture_name = "white rounded rect",
            .layout = .{
                .x = .grows,
            },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
            .minimum = .{ .width = 500, .height = 30 },
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        });

        const tense_form_row1 = try pickers.tense_form.add_alloc(allocator, display, .{
            .name = "tense_form.row1",
            .rect = .{ .width = 500, .height = 30 },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = 5, .bottom = 5 },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
        });

        const tense_form_row2 = try pickers.tense_form.add_alloc(allocator, display, .{
            .name = "tense_form.row1",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = 5, .bottom = 5 },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
        });

        buttons.present = try engine.create_button(allocator, display, .{
            .name = "present",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Present",
                .toggle = .off,
                .on_click = tense_form_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try tense_form_row1.add_element(allocator, buttons.present);

        buttons.future = try engine.create_button(allocator, display, .{
            .name = "future",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Future",
                .toggle = .off,
                .on_click = tense_form_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try tense_form_row1.add_element(allocator, buttons.future);

        buttons.perfect = try engine.create_button(allocator, display, .{
            .name = "perfect",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Perfect",
                .toggle = .off,
                .on_click = tense_form_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try tense_form_row1.add_element(allocator, buttons.perfect);

        buttons.aorist = try engine.create_button(allocator, display, .{
            .name = "aorist",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Aorist",
                .toggle = .off,
                .on_click = tense_form_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try tense_form_row2.add_element(allocator, buttons.aorist);

        buttons.imperfect = try engine.create_button(allocator, display, .{
            .name = "imperfect",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Imperfect",
                .toggle = .off,
                .on_click = tense_form_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try tense_form_row2.add_element(allocator, buttons.imperfect);

        buttons.pluperfect = try engine.create_button(allocator, display, .{
            .name = "pluperfect",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Pluperfect",
                .toggle = .off,
                .on_click = tense_form_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try tense_form_row2.add_element(allocator, buttons.pluperfect);
    }

    {
        pickers.voice = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "voice.picker",
                .background_texture_name = "white rounded rect",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(allocator, pickers.voice);

        buttons.active = try make_parsing_button(allocator, display, "active", "Active", voice_changed);
        try pickers.voice.add_element(allocator, buttons.active);

        buttons.middle = try make_parsing_button(allocator, display, "middle", "Middle", voice_changed);
        try pickers.voice.add_element(allocator, buttons.middle);

        buttons.passive = try make_parsing_button(allocator, display, "passive", "Passive", voice_changed);
        try pickers.voice.add_element(allocator, buttons.passive);
    }

    {
        pickers.mood = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "mood.picker",
                .background_texture_name = "white rounded rect",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
            },
        );
        try panel.add_element(allocator, pickers.mood);

        const mood_row1 = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "mood.row1",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .top = 5, .bottom = 5 },
                .minimum = .{ .width = 300, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try pickers.mood.add_element(allocator, mood_row1);

        const mood_row2 = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "mood.row2",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .top = 5, .bottom = 5 },
                .minimum = .{ .width = 300, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try pickers.mood.add_element(allocator, mood_row2);

        buttons.indicative = try make_parsing_button(
            allocator,
            display,
            "indicative",
            "Indicative",
            mood_changed,
        );
        try mood_row1.add_element(allocator, buttons.indicative);

        buttons.participle = try make_parsing_button(
            allocator,
            display,
            "participle",
            "Participle",
            mood_changed,
        );
        try mood_row1.add_element(allocator, buttons.participle);

        buttons.subjunctive = try make_parsing_button(
            allocator,
            display,
            "subjunctive",
            "Subjunctive",
            mood_changed,
        );
        try mood_row1.add_element(allocator, buttons.subjunctive);

        buttons.imperative = try make_parsing_button(
            allocator,
            display,
            "imperative",
            "Imperative",
            mood_changed,
        );
        try mood_row2.add_element(allocator, buttons.imperative);

        buttons.infinitive = try make_parsing_button(
            allocator,
            display,
            "infinitive",
            "Infinitive",
            mood_changed,
        );
        try mood_row2.add_element(allocator, buttons.infinitive);
    }

    {
        pickers.person = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "person.picker",
                .background_texture_name = "white rounded rect",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(allocator, pickers.person);

        buttons.first = try engine.create_button(allocator, display, .{
            .name = "first_person",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "1st Person",
                .toggle = .off,
                .on_click = person_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.person.add_element(allocator, buttons.first);

        buttons.second = try engine.create_button(allocator, display, .{
            .name = "second_person",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "2nd Person",
                .toggle = .off,
                .on_click = person_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.person.add_element(allocator, buttons.second);

        buttons.third = try engine.create_button(
            allocator,
            display,
            .{
                .name = "third_person",
                .pad = .{
                    .left = PARSING_BUTTON_X_PADDING,
                    .right = PARSING_BUTTON_X_PADDING,
                    .top = PARSING_BUTTON_Y_PADDING,
                    .bottom = PARSING_BUTTON_Y_PADDING,
                },
                .layout = .{ .y = .shrinks, .x = .shrinks },
                .type = .{ .button = .{
                    .text = "3rd Person",
                    .toggle = .off,
                    .on_click = person_changed,
                    .background_default_name = "white rounded rect",
                    .background_pressed_name = "white rounded rect",
                    .background_hover_name = "white rounded rect",
                } },
            },
        );
        try pickers.person.add_element(allocator, buttons.third);
    }

    {
        pickers.case = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "case.picker",
                .background_texture_name = "white rounded rect",
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(allocator, pickers.case);

        buttons.nominative = try engine.create_button(allocator, display, .{
            .name = "nominative",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Nominative",
                .toggle = .off,
                .on_click = case_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.case.add_element(allocator, buttons.nominative);

        buttons.accusative = try engine.create_button(
            allocator,
            display,
            .{
                .name = "accusative",
                .pad = .{
                    .left = PARSING_BUTTON_X_PADDING,
                    .right = PARSING_BUTTON_X_PADDING,
                    .top = PARSING_BUTTON_Y_PADDING,
                    .bottom = PARSING_BUTTON_Y_PADDING,
                },
                .layout = .{ .y = .shrinks, .x = .shrinks },
                .type = .{ .button = .{
                    .text = "Accusative",
                    .toggle = .off,
                    .on_click = case_changed,
                    .background_default_name = "white rounded rect",
                    .background_pressed_name = "white rounded rect",
                    .background_hover_name = "white rounded rect",
                } },
            },
        );
        try pickers.case.add_element(allocator, buttons.accusative);

        buttons.genitive = try engine.create_button(allocator, display, .{
            .name = "genitive",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Genitive",
                .toggle = .off,
                .on_click = case_changed,
                .background_default_name = "white rounded rect2",
                .background_pressed_name = "white rounded rect2",
                .background_hover_name = "white rounded rect2",
            } },
        });
        try pickers.case.add_element(allocator, buttons.genitive);

        buttons.dative = try engine.create_button(allocator, display, .{
            .name = "dative",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Dative",
                .toggle = .off,
                .on_click = case_changed,
                .background_default_name = "white rounded rect2",
                .background_pressed_name = "white rounded rect2",
                .background_hover_name = "white rounded rect2",
            } },
        });
        try pickers.case.add_element(allocator, buttons.dative);
    }

    {
        pickers.number = try engine.create_panel(
            allocator,
            display,
            .{
                .name = "number.picker",
                .background_texture_name = "white rounded rect",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(allocator, pickers.number);

        buttons.singular = try engine.create_button(allocator, display, .{
            .name = "singular",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Singular",
                .toggle = .off,
                .on_click = number_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.number.add_element(allocator, buttons.singular);

        buttons.plural = try engine.create_button(allocator, display, .{
            .name = "plural",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Plural",
                .toggle = .off,
                .on_click = number_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.number.add_element(allocator, buttons.plural);
    }

    {
        pickers.gender = try panel.add_alloc(allocator, display, .{
            .name = "gender.picker",
            .background_texture_name = "white rounded rect",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
            .minimum = .{ .width = 500, .height = 30 },
            .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
        });

        buttons.masculine = try engine.create_button(allocator, display, .{
            .name = "masculine",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Masculine",
                .toggle = .off,
                .on_click = gender_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.gender.add_element(allocator, buttons.masculine);

        buttons.feminine = try engine.create_button(allocator, display, .{
            .name = "feminine",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .button = .{
                .text = "Feminine",
                .toggle = .off,
                .on_click = gender_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.gender.add_element(allocator, buttons.feminine);

        buttons.neuter = try engine.create_button(allocator, display, .{
            .name = "neuter",
            .pad = .{
                .left = PARSING_BUTTON_X_PADDING,
                .right = PARSING_BUTTON_X_PADDING,
                .top = PARSING_BUTTON_Y_PADDING,
                .bottom = PARSING_BUTTON_Y_PADDING,
            },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .visible = .visible,
            .type = .{ .button = .{
                .text = "Neuter",
                .toggle = .off,
                .on_click = gender_changed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try pickers.gender.add_element(allocator, buttons.neuter);
    }

    {
        correct_panel = try panel.add_alloc(allocator, display, .{
            .name = "correct.panel.align",
            .rect = .{ .x = 0, .y = 0, .width = 700, .height = 120 },
            .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
            .child_align = .{ .x = .centre, .y = .centre },
            .minimum = .{ .width = 700, .height = 120 },
            .visible = .hidden,
            .type = .{
                .panel = .{
                    .spacing = 10,
                    .direction = .left_to_right,
                },
            },
        });

        const alert_box = try correct_panel.add_alloc(allocator, display, .{
            .name = "correct.panel",
            .background_texture_name = "white rounded rect",
            .rect = .{ .x = 0, .y = 0, .width = 700, .height = 100 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .centre, .y = .centre },
            .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
            .minimum = .{ .width = 700, .height = 100 },
            .visible = .visible,
            .type = .{ .panel = .{
                .spacing = 10,
                .direction = .left_to_right,
                .style = .success,
            } },
        });

        const feedback = try engine.create_label(
            allocator,
            display,
            .{
                .name = "correct.feedback",
                .rect = .{ .width = 510, .height = 20 },
                .minimum = .{ .width = 510 },
                .layout = .{ .y = .shrinks, .x = .shrinks },
                .type = .{ .label = .{
                    .text = "Great.",
                    .text_size = .heading,
                    .text_colour = .success,
                } },
            },
        );
        try alert_box.add_element(allocator, feedback);

        const next1 = try engine.create_button(
            allocator,
            display,
            .{
                .name = "next",
                .rect = .{ .width = 140, .height = 80 },
                .minimum = .{ .width = 140, .height = 80 },
                .pad = .{ .left = 30, .right = 30, .top = 25, .bottom = 25 },
                .layout = .{ .y = .shrinks, .x = .shrinks },
                .child_align = .{ .x = .centre },
                .type = .{ .button = .{
                    .text = "Next",
                    .on_click = next_clicked,
                    .style = .success,
                    .background_default_name = "white rounded rect",
                    .background_pressed_name = "white rounded rect",
                    .background_hover_name = "white rounded rect",
                } },
            },
        );
        try alert_box.add_element(allocator, next1);
    }

    {
        incorrect_panel = try panel.add_alloc(allocator, display, .{
            .name = "incorrect.panel.align",
            .rect = .{ .x = 0, .y = 0, .width = 700, .height = 120 },
            .layout = .{ .x = .fixed, .y = .fixed, .position = .float },
            .child_align = .{ .x = .centre, .y = .centre },
            .minimum = .{ .width = 700, .height = 100 },
            .visible = .hidden,
            .type = .{
                .panel = .{
                    .spacing = 10,
                    .direction = .left_to_right,
                },
            },
        });

        const alert_box = try incorrect_panel.add_alloc(allocator, display, .{
            .name = "incorrect.panel",
            .background_texture_name = "white rounded rect",
            .rect = .{ .x = 0, .y = 0, .width = 700, .height = 100 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre, .y = .centre },
            .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
            .minimum = .{ .width = 700, .height = 100 },
            .type = .{ .panel = .{
                .spacing = 10,
                .direction = .left_to_right,
                .style = .failed,
            } },
        });

        _ = try alert_box.add_alloc(allocator, display, .{
            .name = "incorrect.feedback",
            .rect = .{ .width = 510, .height = 20 },
            .minimum = .{ .width = 510 },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .type = .{ .label = .{
                .text = "Try again.",
                .text_size = .heading,
                .text_colour = .failed,
            } },
        });

        const next2 = try engine.create_button(allocator, display, .{
            .name = "next",
            .rect = .{ .width = 140, .height = 80 },
            .minimum = .{ .width = 140, .height = 80 },
            .pad = .{ .left = 30, .right = 30, .top = 25, .bottom = 25 },
            .layout = .{ .y = .shrinks, .x = .shrinks },
            .child_align = .{ .x = .centre },
            .type = .{ .button = .{
                .text = "Next",
                .on_click = next_clicked,
                .style = .failed,
                .background_default_name = "white rounded rect",
                .background_pressed_name = "white rounded rect",
                .background_hover_name = "white rounded rect",
            } },
        });
        try alert_box.add_element(allocator, next2);
    }

    try panel.add_element(allocator, try engine.create_expander(
        allocator,
        display,
        .{
            .name = "bottom.expander",
            .rect = .{ .x = 0, .y = 0, .width = 100, .height = 5 },
            .minimum = .{ .width = 100, .height = 5 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 1.3 } },
        },
    ));
}

pub fn handle_resize(display: *Display, _: *Element) bool {
    var updated = false;
    const new_width = ParsingMenuScreen.best_width(display);
    if (panel.rect.width != new_width) {
        panel.rect.width = new_width;
        panel.minimum.width = new_width;
        panel.maximum.width = new_width;
        updated = true;
    }

    if (ac.app_context.?.preference.size == .large or ac.app_context.?.preference.size == .extra_large or display.root.rect.height < 1200) {
        if (help_line.visible != .hidden) {
            help_line.visible = .hidden;
            updated = true;
        }
    } else {
        if (help_line.visible == .hidden) {
            help_line.visible = .visible;
            updated = true;
        }
    }

    return updated;
}

fn make_parsing_button(allocator: Allocator, display: *Display, name: []const u8, text: []const u8, handler: fn (*Display, *Element) std.mem.Allocator.Error!void) !*Element {
    return try engine.create_button(allocator, display, .{
        .name = name,
        .pad = .{
            .left = PARSING_BUTTON_X_PADDING,
            .right = PARSING_BUTTON_X_PADDING,
            .top = PARSING_BUTTON_Y_PADDING,
            .bottom = PARSING_BUTTON_Y_PADDING,
        },
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .type = .{ .button = .{
            .text = text,
            .toggle = .off,
            .on_click = handler,
            .background_default_name = "white rounded rect",
            .background_pressed_name = "white rounded rect",
            .background_hover_name = "white rounded rect",
        } },
    });
}

pub fn next_clicked(display: *Display, element: *Element) error{OutOfMemory}!void {
    try slide_panel_out(display);
    if (ac.app_context.?.parsing_quiz.form_bank.items.len == 0) {
        MenuUI.progress_bar.visible = .hidden;
        MenuUI.toolbar.visible = .visible;
        if (ac.app_context.?.word_lexeme) |lexeme| {
            try ParsingSetupScreen.study_by_form(display, lexeme, ParsingSetupScreen.called_by);
        } else {
            try ParsingMenuScreen.show(display, element);
        }
        return;
    }
    _ = try show_next_quiz_card(display);
}

pub fn button_bounce(
    allocator: Allocator,
    display: *Display,
    button: *Element,
) error{OutOfMemory}!void {
    button.layout.x = .fixed;
    button.layout.y = .fixed;
    const animation: engine.Animator = .{
        .target = button,
        .mode = .move,
        .movement = .stretch,
        .duration = 100 * 1000,
        .start = button.rect,
        .end = .{
            .x = button.rect.x,
            .y = button.rect.y,
            .width = 10,
            .height = 2,
        },
        .on_end = button_bounce_end,
    };
    try display.add_animator(allocator, animation);
}

pub fn button_bounce_end(_: *Display, button: *Element) void {
    button.layout.x = .shrinks;
    button.layout.y = .shrinks;
}

const panel_slide_duration = 250 * 1000;

pub fn slide_panel_in(display: *Display, slide_panel: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    correct_panel.visible = .hidden;
    incorrect_panel.visible = .hidden;
    slide_panel.visible = .visible;
    slide_panel.rect.x = display.root.rect.width / 2 - slide_panel.rect.width / 2;
    slide_panel.rect.y = display.root.rect.height + 2;
    const animation: engine.Animator = .{
        .target = slide_panel,
        .mode = .move,
        .movement = .ease,
        .duration = panel_slide_duration,
        .start = slide_panel.rect,
        .end = .{
            .x = display.root.rect.width / 2 - slide_panel.rect.width / 2,
            .y = display.root.rect.height - display.root.pad.bottom - slide_panel.rect.height - 20,
            .width = slide_panel.rect.width,
            .height = slide_panel.rect.height,
        },
    };
    try display.add_animator(allocator, animation);
}

pub fn slide_panel_out(display: *Display) error{OutOfMemory}!void {
    if (correct_panel.visible != .hidden) {
        try slide_panel_down(display, correct_panel);
    }
    if (incorrect_panel.visible != .hidden) {
        try slide_panel_down(display, incorrect_panel);
    }
}

pub fn slide_panel_down(display: *Display, slide_panel: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    slide_panel.rect.x = display.root.rect.width / 2 - slide_panel.rect.width / 2;
    slide_panel.rect.y = display.root.rect.height - display.root.pad.bottom - slide_panel.rect.height - 20;
    const animation: engine.Animator = .{
        .target = slide_panel,
        .mode = .move,
        .movement = .ease,
        .duration = panel_slide_duration,
        .start = slide_panel.rect,
        .end = .{
            .x = display.root.rect.width / 2 - slide_panel.rect.width / 2,
            .y = display.root.rect.height + 2,
            .width = slide_panel.rect.width,
            .height = slide_panel.rect.height,
        },
    };
    try display.add_animator(allocator, animation);
}

var help_line_buffer: [2][500]u8 = undefined;
var help_line_buffer_i: usize = 0;

pub fn show_next_quiz_card(display: *Display) error{OutOfMemory}!bool {
    const ctx = ac.app_context.?;
    if (ctx.parsing_quiz.form_bank.items.len == 0) {
        warn("Not starting quiz. Form bank has no words.", .{});
        return false;
    }

    const form = ac.app_context.?.parsing_quiz.next_form();
    MenuUI.progress_bar.type.progress_bar.progress = ac.app_context.?.parsing_quiz.progress();

    try quiz_word.set_text(ctx.allocator, display, form.*.word, false);

    help_line_buffer_i += 1;
    if (help_line_buffer_i >= help_line_buffer.len) {
        help_line_buffer_i = 0;
    }

    const text = std.fmt.bufPrint(&help_line_buffer[help_line_buffer_i], "Describe the grammar of {s}.", .{form.*.word}) catch "Describe the grammar of this word.";
    try help_line.set_text(ctx.allocator, display, text, false);

    info("showing card {s} ({any})", .{ form.*.word, form.*.parsing });

    switch (form.*.parsing.part_of_speech) {
        .verb => {
            pickers.case.visible = .hidden;
            pickers.number.visible = .hidden;
            pickers.gender.visible = .hidden;
            pickers.tense_form.visible = .visible;
            pickers.voice.visible = .visible;
            pickers.mood.visible = .visible;
            pickers.person.visible = .visible;
            pickers.number.visible = .visible;
        },
        .noun, .adjective, .proper_noun => {
            pickers.case.visible = .visible;
            pickers.number.visible = .visible;
            pickers.gender.visible = .visible;
            pickers.tense_form.visible = .hidden;
            pickers.voice.visible = .hidden;
            pickers.mood.visible = .hidden;
            pickers.person.visible = .hidden;
        },
        .personal_pronoun => {
            pickers.case.visible = .visible;
            pickers.number.visible = .visible;
            pickers.gender.visible = .hidden;
            pickers.tense_form.visible = .hidden;
            pickers.voice.visible = .hidden;
            pickers.mood.visible = .hidden;
            pickers.person.visible = .visible;
            if (form.lexeme) |lexeme| {
                if (std.mem.eql(u8, lexeme.word, "αὐτός"))
                    pickers.gender.visible = .visible;
            }
        },
        else => {
            err("show_next_quiz_card doesnt handle {s}", .{@tagName(form.*.parsing.part_of_speech)});
        },
    }

    buttons.clear_options();
    display.need_relayout = true;
    return true;
}

fn show_answer_if_ready(display: *Display) error{OutOfMemory}!void {
    std.debug.assert(ac.app_context.?.parsing_quiz.form_bank.items.len > 0);
    const current_form = ac.app_context.?.parsing_quiz.form_bank.items[0];
    if (buttons.options_picked(current_form)) |parsing| {
        const correct = try buttons.mark_answers(current_form, parsing, display.allocator);
        if (correct) {
            info("User chose {any} correct.", .{parsing});
            try slide_panel_in(display, correct_panel);
            _ = ac.app_context.?.parsing_quiz.remove_current_form();
        } else {
            info("User chose {any} incorrect. Expecting {any}", .{ parsing, current_form.parsing });
            try slide_panel_in(display, incorrect_panel);
        }
        buttons.lock_unpicked_toggles();
        display.need_relayout = true;
    } else {
        trace("user still picking", .{});
    }
    return;
}

fn case_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.nominative,
            buttons.accusative,
            buttons.genitive,
            buttons.dative,
        });
        try button_bounce(allocator, display, element);
    }
    try show_answer_if_ready(display);
}

fn number_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.singular,
            buttons.plural,
        });
        try button_bounce(allocator, display, element);
    }
    try show_answer_if_ready(display);
}

fn gender_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.masculine,
            buttons.feminine,
            buttons.neuter,
        });
        try button_bounce(allocator, display, element);
    }
    try show_answer_if_ready(display);
}

fn tense_form_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.present,
            buttons.future,
            buttons.aorist,
            buttons.imperfect,
            buttons.perfect,
            buttons.pluperfect,
        });
        try button_bounce(allocator, display, element);
    }
    try show_answer_if_ready(display);
}

fn mood_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.indicative,
            buttons.participle,
            buttons.subjunctive,
            buttons.infinitive,
            buttons.imperative,
        });
        try button_bounce(allocator, display, element);
    }

    if (buttons.participle.type.button.toggle == .on) {
        pickers.tense_form.visible = .visible;
        pickers.voice.visible = .visible;
        pickers.mood.visible = .visible;
        pickers.person.visible = .hidden;
        pickers.case.visible = .visible;
        pickers.number.visible = .visible;
        pickers.gender.visible = .visible;
        display.need_relayout = true;
    } else {
        pickers.tense_form.visible = .visible;
        pickers.voice.visible = .visible;
        pickers.mood.visible = .visible;
        pickers.person.visible = .visible;
        pickers.case.visible = .hidden;
        pickers.number.visible = .visible;
        pickers.gender.visible = .hidden;
        display.need_relayout = true;
    }
    try show_answer_if_ready(display);
}

fn voice_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.active,
            buttons.middle,
            buttons.passive,
        });
        try button_bounce(allocator, display, element);
    }
    try show_answer_if_ready(display);
}

fn person_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    const allocator = ac.app_context.?.allocator;
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.first,
            buttons.second,
            buttons.third,
        });
        try button_bounce(allocator, display, element);
    }
    try show_answer_if_ready(display);
}

fn clear_other_toggles(current: *Element, others: []const *Element) void {
    for (others) |*other| {
        if (current != other.*)
            other.*.type.button.toggle = .off;
    }
}

fn formsHaveTenseForm(forms: []*praxis.Form, tense_form: praxis.TenseForm) bool {
    for (forms) |form|
        if (form.parsing.tense_form == tense_form)
            return true;
    return false;
}

fn formsHaveVoice(forms: []*praxis.Form, voice: praxis.Voice) bool {
    for (forms) |form|
        if (form.parsing.voice == voice)
            return true;
    return false;
}

fn formsHaveGender(forms: []*praxis.Form, gender: praxis.Gender) bool {
    for (forms) |form|
        if (form.parsing.gender == gender)
            return true;
    return false;
}

fn formsHaveMood(forms: []*praxis.Form, mood: praxis.Mood) bool {
    for (forms) |form|
        if (form.parsing.mood == mood)
            return true;
    return false;
}

fn formsHaveCase(forms: []*praxis.Form, case: praxis.Case) bool {
    for (forms) |form|
        if (form.parsing.case == case)
            return true;
    return false;
}

fn formsHaveNumber(forms: []*praxis.Form, number: praxis.Number) bool {
    for (forms) |form|
        if (form.parsing.number == number)
            return true;
    return false;
}

fn formsHaveRefNumber(forms: []*praxis.Form, number: praxis.TenseForm) bool {
    for (forms) |form|
        if (form.parsing.tense_form == number)
            return true;
    return false;
}

fn formsHavePerson(forms: []*praxis.Form, person: praxis.Person) bool {
    for (forms) |form|
        if (form.parsing.person == person)
            return true;
    return false;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const praxis = @import("praxis");
const Lexeme = praxis.Lexeme;
const Form = praxis.Form;

const resources = @import("resources");
const Resources = resources.Resources;
const ResourcesError = resources.Resources.Error;
const seed = resources.seed;

const engine = @import("engine");
const Display = engine.Display;
const ToggleState = engine.ToggleState;
const Element = engine.Element;
const trace = engine.trace;
const debug = engine.debug;
const info = engine.info;
const warn = engine.warn;
const err = engine.err;

const ac = @import("app_context.zig");
const AppContext = ac.AppContext;

const MenuUI = @import("menu_ui.zig");
const ParsingSetupScreen = @import("screen_parsing_setup.zig");
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
