const PARSING_BUTTON_X_PADDING: f32 = 16.0;
const PARSING_BUTTON_Y_PADDING: f32 = 10.0 + 4;

var panel: *Element = undefined;
var quiz_word: *Element = undefined;
var help_line: *Element = undefined;
var correct_panel: *Element = undefined;
var incorrect_panel: *Element = undefined;
var back_button: *Element = undefined;

pub fn show(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (ac.app_context.?.parsing_quiz.form_bank.items.len == 0) {
        warn("Not starting quiz. Form bank has no words.", .{});
        return;
    }
    info("Starting quiz. Form bank has {d} words.", .{
        ac.app_context.?.parsing_quiz.form_bank.items.len,
    });

    display.choose_panel("parsing.quiz");
    if (!try show_next_quiz_card(display)) {
        try ParsingMenuScreen.show(display, element);
    }

    correct_panel.visible = .hidden;
    incorrect_panel.visible = .hidden;
    MenuUI.progress_bar.type.progress_bar.progress = 0;
    MenuUI.progress_bar.visible = .visible;
    MenuUI.toolbar.visible = .hidden;
    _ = MenuUI.align_progress_bar(display, MenuUI.progress_bar);

    // Adjust order of case buttons depending on user preference
    if (ac.app_context.?.preference.uk_order) {
        trace("Case buttons in UK order", .{});
        pickers.case.type.panel.children.clearRetainingCapacity();
        try pickers.case.type.panel.children.append(buttons.nominative);
        try pickers.case.type.panel.children.append(buttons.accusative);
        try pickers.case.type.panel.children.append(buttons.genitive);
        try pickers.case.type.panel.children.append(buttons.dative);
        display.need_relayout = true;
    } else {
        trace("Case buttons in US order", .{});
        pickers.case.type.panel.children.clearRetainingCapacity();
        try pickers.case.type.panel.children.append(buttons.nominative);
        try pickers.case.type.panel.children.append(buttons.genitive);
        try pickers.case.type.panel.children.append(buttons.dative);
        try pickers.case.type.panel.children.append(buttons.accusative);
        display.need_relayout = true;
    }
}

pub fn deinit() void {
    //
}

pub fn cancel_quiz(display: *Display, element: *Element) error{OutOfMemory}!void {
    MenuUI.progress_bar.visible = .hidden;
    MenuUI.toolbar.visible = .visible;

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
        if (form.parsing.part_of_speech == .verb) {
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

                // Person
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
        }

        // Its a noun
        {
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

            // Person
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
            if (count > 2) {
                return parsing;
            } else {
                return null;
            }
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

    fn mark_answers(self: *Self, form: *praxis.Form) void {
        const parsing = form.parsing;
        switch (form.parsing.part_of_speech) {
            .verb => {

                // Tense form
                mark_button(&self.present.type.button.toggle, parsing.tense_form == .present);
                mark_button(&self.future.type.button.toggle, parsing.tense_form == .future);
                mark_button(&self.imperfect.type.button.toggle, parsing.tense_form == .imperfect);
                mark_button(&self.aorist.type.button.toggle, parsing.tense_form == .aorist);
                mark_button(&self.perfect.type.button.toggle, parsing.tense_form == .perfect);
                mark_button(&self.pluperfect.type.button.toggle, parsing.tense_form == .pluperfect);

                // Voice
                mark_button(&self.active.type.button.toggle, parsing.voice == .active);
                mark_button(&self.middle.type.button.toggle, parsing.voice == .middle);
                mark_button(&self.passive.type.button.toggle, parsing.voice == .passive);

                // Mood
                mark_button(&self.indicative.type.button.toggle, parsing.mood == .indicative);
                mark_button(&self.participle.type.button.toggle, parsing.mood == .participle);
                mark_button(&self.subjunctive.type.button.toggle, parsing.mood == .subjunctive);
                mark_button(&self.imperative.type.button.toggle, parsing.mood == .imperative);
                mark_button(&self.infinitive.type.button.toggle, parsing.mood == .infinitive);

                if (parsing.mood == .participle) {
                    // Case
                    mark_button(&self.nominative.type.button.toggle, parsing.case == .nominative);
                    mark_button(&self.accusative.type.button.toggle, parsing.case == .accusative);
                    mark_button(&self.dative.type.button.toggle, parsing.case == .dative);
                    mark_button(&self.genitive.type.button.toggle, parsing.case == .genitive);

                    // Person
                    mark_button(&self.singular.type.button.toggle, parsing.number == .singular);
                    mark_button(&self.plural.type.button.toggle, parsing.number == .plural);

                    // Gender
                    mark_button(&self.masculine.type.button.toggle, parsing.gender == .masculine);
                    mark_button(&self.feminine.type.button.toggle, parsing.gender == .feminine);
                    mark_button(&self.neuter.type.button.toggle, parsing.gender == .neuter);
                } else {
                    // Person
                    mark_button(&self.first.type.button.toggle, parsing.person == .first);
                    mark_button(&self.second.type.button.toggle, parsing.person == .second);
                    mark_button(&self.third.type.button.toggle, parsing.person == .third);

                    // Number
                    mark_button(&self.singular.type.button.toggle, parsing.number == .singular);
                    mark_button(&self.plural.type.button.toggle, parsing.number == .plural);
                }
            },

            .noun, .adjective => {
                // Case
                mark_button(&self.nominative.type.button.toggle, parsing.case == .nominative);
                mark_button(&self.accusative.type.button.toggle, parsing.case == .accusative);
                mark_button(&self.dative.type.button.toggle, parsing.case == .dative);
                mark_button(&self.genitive.type.button.toggle, parsing.case == .genitive);

                // Person
                mark_button(&self.singular.type.button.toggle, parsing.number == .singular);
                mark_button(&self.plural.type.button.toggle, parsing.number == .plural);

                // Gender
                mark_button(&self.masculine.type.button.toggle, parsing.gender == .masculine);
                mark_button(&self.feminine.type.button.toggle, parsing.gender == .feminine);
                mark_button(&self.neuter.type.button.toggle, parsing.gender == .neuter);
            },
            else => {
                err("mark_answers() unimplemented for {s}", .{@tagName(parsing.part_of_speech)});
            },
        }
    }
}{};

pub fn init(context: *AppContext) error{
    OutOfMemory,
    ResourceNotFound,
    ResourceReadError,
    UnknownImageFormat,
}!void {
    var display = context.display;
    seed();
    help_line_buffer_i = 0;

    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
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
        },
    ));

    back_button = try display.add_back_button(panel, cancel_quiz);

    _ = try display.add_spacer(panel, 1);

    quiz_word = try engine.create_label(
        display,
        "",
        .{
            .name = "parsing.quiz.word",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "λυω",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    );
    try panel.add_element(quiz_word);
    quiz_word.pad.top = 30 + 60; // Normal top padding place progress bar padding

    help_line = try engine.create_label(
        display,
        "",
        .{
            .name = "parsing.quiz.hint",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .type = .{ .label = .{
                .text = "Describe the grammar of this word.",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    );
    try panel.add_element(help_line);

    try panel.add_element(try engine.create_expander(
        display,
        .{
            .name = "top.expander",
            .rect = .{ .width = 100, .height = 20 },
            .minimum = .{ .width = 100, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 0.7 } },
        },
    ));

    {
        pickers.tense_form = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "tense_form.picker",
                .layout = .{
                    .x = .grows,
                },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
            },
        );
        try panel.add_element(pickers.tense_form);

        const tense_form_row1 = try engine.create_panel(
            display,
            "",
            .{
                .name = "tense_form.row1",
                .rect = .{ .width = 500, .height = 30 },
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre },
                .pad = .{ .top = 5, .bottom = 5 },
                .minimum = .{ .width = 300, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try pickers.tense_form.add_element(tense_form_row1);

        const tense_form_row2 = try engine.create_panel(
            display,
            "",
            .{
                .name = "tense_form.row1",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre },
                .pad = .{ .top = 5, .bottom = 5 },
                .minimum = .{ .width = 300, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try pickers.tense_form.add_element(tense_form_row2);

        buttons.present = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try tense_form_row1.add_element(buttons.present);

        buttons.future = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try tense_form_row1.add_element(buttons.future);

        buttons.perfect = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try tense_form_row1.add_element(buttons.perfect);

        buttons.aorist = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try tense_form_row2.add_element(buttons.aorist);

        buttons.imperfect = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try tense_form_row2.add_element(buttons.imperfect);

        buttons.pluperfect = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try tense_form_row2.add_element(buttons.pluperfect);
    }

    {
        pickers.voice = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "voice.picker",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(pickers.voice);

        buttons.active = try make_parsing_button(display, "active", "Active", voice_changed);
        try pickers.voice.add_element(buttons.active);

        buttons.middle = try make_parsing_button(display, "middle", "Middle", voice_changed);
        try pickers.voice.add_element(buttons.middle);

        buttons.passive = try make_parsing_button(display, "passive", "Passive", voice_changed);
        try pickers.voice.add_element(buttons.passive);
    }

    {
        pickers.mood = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "mood.picker",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
            },
        );
        try panel.add_element(pickers.mood);

        const mood_row1 = try engine.create_panel(
            display,
            "",
            .{
                .name = "mood.row1",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .top = 5, .bottom = 5 },
                .minimum = .{ .width = 300, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try pickers.mood.add_element(mood_row1);

        const mood_row2 = try engine.create_panel(
            display,
            "",
            .{
                .name = "mood.row2",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .top = 5, .bottom = 5 },
                .minimum = .{ .width = 300, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try pickers.mood.add_element(mood_row2);

        buttons.indicative = try make_parsing_button(
            display,
            "indicative",
            "Indicative",
            mood_changed,
        );
        try mood_row1.add_element(buttons.indicative);

        buttons.participle = try make_parsing_button(
            display,
            "participle",
            "Participle",
            mood_changed,
        );
        try mood_row1.add_element(buttons.participle);

        buttons.subjunctive = try make_parsing_button(
            display,
            "subjunctive",
            "Subjunctive",
            mood_changed,
        );
        try mood_row1.add_element(buttons.subjunctive);

        buttons.imperative = try make_parsing_button(
            display,
            "imperative",
            "Imperative",
            mood_changed,
        );
        try mood_row2.add_element(buttons.imperative);

        buttons.infinitive = try make_parsing_button(
            display,
            "infinitive",
            "Infinitive",
            mood_changed,
        );
        try mood_row2.add_element(buttons.infinitive);
    }

    {
        pickers.person = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "person.picker",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(pickers.person);

        buttons.first = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.person.add_element(buttons.first);

        buttons.second = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.person.add_element(buttons.second);

        buttons.third = try engine.create_button(
            display,
            "",
            "",
            "",
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.person.add_element(buttons.third);
    }

    {
        pickers.case = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "case.picker",
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(pickers.case);

        buttons.nominative = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.case.add_element(buttons.nominative);

        buttons.accusative = try engine.create_button(
            display,
            "",
            "",
            "",
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
                } },
            },
            "white rounded rect2",
            "white rounded rect2",
            "white rounded rect2",
        );
        try pickers.case.add_element(buttons.accusative);

        buttons.genitive = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect2",
            "white rounded rect2",
            "white rounded rect2",
        );
        try pickers.case.add_element(buttons.genitive);

        buttons.dative = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.case.add_element(buttons.dative);
    }

    {
        pickers.number = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "number.picker",
                .layout = .{ .x = .grows },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(pickers.number);

        buttons.singular = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.number.add_element(buttons.singular);

        buttons.plural = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.number.add_element(buttons.plural);
    }

    {
        pickers.gender = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "gender.picker",
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 500, .height = 30 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .left_to_right } },
            },
        );
        try panel.add_element(pickers.gender);

        buttons.masculine = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.gender.add_element(buttons.masculine);

        buttons.feminine = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.gender.add_element(buttons.feminine);

        buttons.neuter = try engine.create_button(
            display,
            "",
            "",
            "",
            .{
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try pickers.gender.add_element(buttons.neuter);
    }

    {
        correct_panel = try engine.create_panel(
            display,
            "",
            .{
                .name = "correct.panel.align",
                .rect = .{ .x = 0, .y = 0, .width = 600, .height = 90 },
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre, .y = .end },
                .minimum = .{ .width = 600, .height = 90 },
                .visible = .hidden,
                .type = .{
                    .panel = .{
                        .spacing = 10,
                        .direction = .left_to_right,
                    },
                },
            },
        );
        try panel.add_element(correct_panel);

        const alert_box = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "correct.panel",
                .rect = .{ .x = 0, .y = 0, .width = 600, .height = 90 },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 600, .height = 90 },
                .visible = .visible,
                .type = .{ .panel = .{
                    .spacing = 10,
                    .direction = .left_to_right,
                    .style = .success,
                } },
            },
        );
        try correct_panel.add_element(alert_box);

        const feedback = try engine.create_label(
            display,
            "",
            .{
                .name = "correct.feedback",
                .rect = .{ .width = 450, .height = 20 },
                .minimum = .{ .width = 450 },
                .layout = .{ .y = .shrinks, .x = .shrinks },
                .type = .{ .label = .{
                    .text = "Great.",
                    .text_size = .heading,
                    .text_colour = .success,
                } },
            },
        );
        try alert_box.add_element(feedback);

        const next1 = try engine.create_button(
            display,
            "",
            "",
            "",
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
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try alert_box.add_element(next1);
    }

    {
        incorrect_panel = try engine.create_panel(
            display,
            "",
            .{
                .name = "incorrect.panel.align",
                .rect = .{ .x = 0, .y = 0, .width = 600, .height = 90 },
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre, .y = .end },
                .minimum = .{ .width = 600, .height = 90 },
                .visible = .hidden,
                .type = .{
                    .panel = .{
                        .spacing = 10,
                        .direction = .left_to_right,
                    },
                },
            },
        );
        try panel.add_element(incorrect_panel);

        const alert_box = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "incorrect.panel",
                .rect = .{ .x = 0, .y = 0, .width = 600, .height = 90 },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .child_align = .{ .x = .centre, .y = .start },
                .pad = .{ .left = 15, .right = 15, .top = 15, .bottom = 15 },
                .minimum = .{ .width = 600, .height = 90 },
                .type = .{ .panel = .{
                    .spacing = 10,
                    .direction = .left_to_right,
                    .style = .failed,
                } },
            },
        );
        try incorrect_panel.add_element(alert_box);

        const feedback = try engine.create_label(
            display,
            "",
            .{
                .name = "incorrect.feedback",
                .rect = .{ .width = 450, .height = 20 },
                .minimum = .{ .width = 450 },
                .layout = .{ .y = .shrinks, .x = .shrinks },
                .type = .{ .label = .{
                    .text = "Try again.",
                    .text_size = .heading,
                    .text_colour = .failed,
                } },
            },
        );
        try alert_box.add_element(feedback);

        const next2 = try engine.create_button(
            display,
            "",
            "",
            "",
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
                    .style = .failed,
                } },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        );
        try alert_box.add_element(next2);
    }

    try panel.add_element(try engine.create_expander(
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

fn make_parsing_button(display: *Display, name: []const u8, text: []const u8, handler: fn (*Display, *Element) std.mem.Allocator.Error!void) !*Element {
    return try engine.create_button(
        display,
        "",
        "",
        "",
        .{
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
            } },
        },
        "white rounded rect",
        "white rounded rect",
        "white rounded rect",
    );
}

pub fn next_clicked(display: *Display, element: *Element) error{OutOfMemory}!void {
    correct_panel.visible = .hidden;
    incorrect_panel.visible = .hidden;
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

var help_line_buffer: [2][500]u8 = undefined;
var help_line_buffer_i: usize = 0;

pub fn show_next_quiz_card(display: *Display) error{OutOfMemory}!bool {
    if (ac.app_context.?.parsing_quiz.form_bank.items.len == 0) {
        warn("Not starting quiz. Form bank has no words.", .{});
        return false;
    }

    const form = ac.app_context.?.parsing_quiz.next_form();
    MenuUI.progress_bar.type.progress_bar.progress = ac.app_context.?.parsing_quiz.progress();

    try quiz_word.set_text(display, form.*.word, false);

    help_line_buffer_i += 1;
    if (help_line_buffer_i >= help_line_buffer.len) {
        help_line_buffer_i = 0;
    }

    const text = std.fmt.bufPrint(&help_line_buffer[help_line_buffer_i], "Describe the grammar of {s}.", .{form.*.word}) catch "Describe the grammar of this word.";
    try help_line.set_text(display, text, false);

    if (form.*.parsing.part_of_speech == .verb) {
        pickers.case.visible = .hidden;
        pickers.number.visible = .hidden;
        pickers.gender.visible = .hidden;
        pickers.tense_form.visible = .visible;
        pickers.voice.visible = .visible;
        pickers.mood.visible = .visible;
        pickers.person.visible = .visible;
        pickers.number.visible = .visible;
    } else {
        pickers.case.visible = .visible;
        pickers.number.visible = .visible;
        pickers.gender.visible = .visible;
        pickers.tense_form.visible = .hidden;
        pickers.voice.visible = .hidden;
        pickers.mood.visible = .hidden;
        pickers.person.visible = .hidden;
    }

    buttons.clear_options();
    display.need_relayout = true;
    return true;
}

fn show_answer_if_ready(display: *Display) error{OutOfMemory}!void {
    std.debug.assert(ac.app_context.?.parsing_quiz.form_bank.items.len > 0);
    const current_form = ac.app_context.?.parsing_quiz.form_bank.items[0];
    if (buttons.options_picked(current_form)) |parsing| {
        var out = std.ArrayList(u8).init(ac.app_context.?.allocator);
        defer out.deinit();
        parsing.string(out.writer()) catch |e| {
            if (e == error.Incomplete) {
                debug("invalid state. parsing incomplete after user picking.", .{});
            }
        };
        if (parsing == current_form.parsing) {
            info("User chose {s} correct.", .{out.items});
            buttons.mark_answers(current_form);
            correct_panel.visible = .visible;
            incorrect_panel.visible = .hidden;
            _ = ac.app_context.?.parsing_quiz.remove_current_form();
        } else if (alternateFormCorrect(current_form, parsing)) |alt| {
            info("User chose {s} alternate form correct", .{out.items});
            buttons.mark_answers(alt);
            correct_panel.visible = .visible;
            incorrect_panel.visible = .hidden;
            _ = ac.app_context.?.parsing_quiz.remove_current_form();
        } else {
            var out2 = std.ArrayList(u8).init(ac.app_context.?.allocator);
            defer out2.deinit();
            current_form.parsing.string(out2.writer()) catch |e| {
                if (e == error.Incomplete) {
                    debug("invalid state. parsing incomplete after user picking.", .{});
                }
            };
            info("User chose {s} incorrect. Expecting {s}", .{ out.items, out2.items });
            buttons.mark_answers(current_form);
            correct_panel.visible = .hidden;
            incorrect_panel.visible = .visible;
        }
        buttons.lock_unpicked_toggles();
        display.need_relayout = true;
    } else {
        trace("user still picking", .{});
    }
    return;
}

fn alternateFormCorrect(form: *Form, parsing: praxis.Parsing) ?*Form {
    if (form.lexeme == null) {
        return null;
    }
    for (form.lexeme.?.forms.items) |item| {
        if (std.mem.eql(u8, form.word, item.word)) {
            if (item.parsing == parsing) {
                return item;
            }
        }
    }
    return null;
}

fn case_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.nominative,
            buttons.accusative,
            buttons.genitive,
            buttons.dative,
        });
    }
    try show_answer_if_ready(display);
}

fn number_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.singular,
            buttons.plural,
        });
    }
    try show_answer_if_ready(display);
}

fn gender_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.masculine,
            buttons.feminine,
            buttons.neuter,
        });
    }
    try show_answer_if_ready(display);
}

fn tense_form_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.present,
            buttons.future,
            buttons.aorist,
            buttons.imperfect,
            buttons.perfect,
            buttons.pluperfect,
        });
    }
    try show_answer_if_ready(display);
}

fn mood_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.indicative,
            buttons.participle,
            buttons.subjunctive,
            buttons.infinitive,
            buttons.imperative,
        });
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
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.active,
            buttons.middle,
            buttons.passive,
        });
    }
    try show_answer_if_ready(display);
}

fn person_changed(display: *Display, element: *Element) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.first,
            buttons.second,
            buttons.third,
        });
    }
    try show_answer_if_ready(display);
}

fn clear_other_toggles(current: *Element, others: []const *Element) void {
    for (others) |*other| {
        if (current != other.*) {
            other.*.type.button.toggle = .off;
        }
    }
}

const std = @import("std");

const praxis = @import("praxis");
const Lexeme = praxis.Lexeme;
const Form = praxis.Form;

const resources = @import("resources");
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
