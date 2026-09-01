pub const ParsingCardScreen = @This();

const PARSING_BUTTON_X_PADDING: f32 = 7;
const PARSING_BUTTON_Y_PADDING: f32 = 7;

app: *AppContext = undefined,
panel: *Entity = undefined,
quiz_word: *Entity = undefined,
help_line: *Entity = undefined,
progress_bar: *Entity = undefined,

correct_panel: FeedbackPanel,
incorrect_panel: FeedbackPanel,

pub fn show(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    event: *const Event,
) error{OutOfMemory}!void {
    const ctx = self.app;
    const allocator = ctx.allocator;

    if (ctx.parsing_quiz.form_bank.items.len == 0) {
        warn("Not starting quiz. Form bank has no words.", .{});
        return;
    }
    info("ParsingCard: Starting practice with form bank of {d} words.", .{
        ctx.parsing_quiz.form_bank.items.len,
    });

    try display.choosePanel(self.panel.name, event);
    if (!try self.setupNextCard(display)) {
        err("ParsingCard failed to setupNextCard(). Aborting.", .{});
        try ctx.parsing_menu.show(display, element, event);
    }

    self.correct_panel.panel.visible = .hidden;
    self.incorrect_panel.panel.visible = .hidden;

    try self.app.menu_ui.progress_bar.setVisibility(display, .visible);
    try self.app.menu_ui.toolbar.setVisibility(display, .hidden);
    _ = self.app.menu_ui.resizeProgressBar(display, self.app.menu_ui.progress_bar);

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

pub fn init(self: *ParsingCardScreen, app: *AppContext) (error{
    OutOfMemory,
    ResourceNotFound,
    ResourceReadError,
    UnknownImageFormat,
} || ResourcesError || engine.Error)!void {
    self.app = app;
    var display = app.display;

    seed(app.io);
    help_line_buffer_i = 0;

    std.debug.assert(self.app.menu_ui.progress_bar.type == .panel);
    std.debug.assert(self.app.menu_ui.progress_bar.getChild(0) != null);

    self.progress_bar = self.app.menu_ui.progress_bar.getChild(0).?;
    self.progress_bar.type.progress_bar.progress = 0;

    _ = try display.appendPanel(
        \\panel:panel name "parsing.card"
        \\  hidden vertical choosable avoid_safe_area
        \\  layout grows grows align centre start
        \\  minimum width=280 height=360
        \\  maximum width=500
        \\  pad left=0.5em right=0.5em top=2em spacing 10
        \\  on_resized resizeCard
    , ParsingCardScreen, self);

    _ = try app.add_back_button(self.panel, .{
        .func = @ptrCast(&tapBack),
        .ptr = self,
    });

    _ = try display.add_spacer(self.panel, 1);

    self.quiz_word = try self.panel.add(.{
        .name = "parsing.quiz.word",
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "λυω",
            .text_size = .heading,
        } },
        .pad = .{ .top = 3, .bottom = 5 },
    }, display);

    self.help_line = try self.panel.add(.{
        .name = "parsing.quiz.hint",
        .layout = .{ .x = .grows, .y = .shrinks },
        .child_align = .{ .x = .centre },
        .type = .{ .label = .{
            .text = "Describe the grammar of this word.",
        } },
    }, display);

    _ = try self.panel.add(.{
        .name = "top.expander",
        .type = .{ .expander = .{ .weight = 0.7 } },
    }, display);

    {
        pickers.tense_form = try self.panel.add(.{
            .name = "tense_form.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{
                .spacing = PARSING_BUTTON_Y_PADDING,
                .direction = .top_to_bottom,
            } },
        }, display);

        const tense_form_row1 = try pickers.tense_form.add(.{
            .name = "tense_form.row1",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        const tense_form_row2 = try pickers.tense_form.add(.{
            .name = "tense_form.row2",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        buttons.present = try tense_form_row1.add(try self.initParsingButton(
            "present",
            "Present",
            @ptrCast(&tense_form_changed),
        ), display);

        buttons.future = try tense_form_row1.add(try self.initParsingButton(
            "future",
            "Future",
            @ptrCast(&tense_form_changed),
        ), display);

        buttons.perfect = try tense_form_row1.add(try self.initParsingButton(
            "perfect",
            "Perfect",
            @ptrCast(&tense_form_changed),
        ), display);

        buttons.aorist = try tense_form_row2.add(try self.initParsingButton(
            "aorist",
            "Aorist",
            @ptrCast(&tense_form_changed),
        ), display);

        buttons.imperfect = try tense_form_row2.add(try self.initParsingButton(
            "imperfect",
            "Imperfect",
            @ptrCast(&tense_form_changed),
        ), display);

        buttons.pluperfect = try tense_form_row2.add(try self.initParsingButton(
            "pluperfect",
            "Pluperfect",
            @ptrCast(&tense_form_changed),
        ), display);
    }

    {
        pickers.voice = try self.panel.add(.{
            .name = "voice.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        buttons.active = try pickers.voice.add(try self.initParsingButton(
            "active",
            "Active",
            @ptrCast(&voice_changed),
        ), display);

        buttons.middle = try pickers.voice.add(try self.initParsingButton(
            "middle",
            "Middle",
            @ptrCast(&voice_changed),
        ), display);

        buttons.passive = try pickers.voice.add(try self.initParsingButton(
            "passive",
            "Passive",
            @ptrCast(&voice_changed),
        ), display);
    }

    {
        pickers.mood = try self.panel.add(.{
            .name = "mood.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_Y_PADDING, .direction = .top_to_bottom } },
        }, display);

        const mood_row1 = try pickers.mood.add(.{
            .name = "mood.row1",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        const mood_row2 = try pickers.mood.add(.{
            .name = "mood.row2",
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        buttons.indicative = try mood_row1.add(try self.initParsingButton(
            "indicative",
            "Indicative",
            @ptrCast(&mood_changed),
        ), display);

        buttons.participle = try mood_row1.add(try self.initParsingButton(
            "participle",
            "Participle",
            @ptrCast(&mood_changed),
        ), display);

        buttons.subjunctive = try mood_row1.add(try self.initParsingButton(
            "subjunctive",
            "Subjunctive",
            @ptrCast(&mood_changed),
        ), display);

        buttons.imperative = try mood_row2.add(try self.initParsingButton(
            "imperative",
            "Imperative",
            @ptrCast(&mood_changed),
        ), display);

        buttons.infinitive = try mood_row2.add(try self.initParsingButton(
            "infinitive",
            "Infinitive",
            @ptrCast(&mood_changed),
        ), display);
    }

    {
        pickers.person = try self.panel.add(.{
            .name = "person.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{
                .spacing = PARSING_BUTTON_X_PADDING,
                .direction = .left_to_right,
            } },
        }, display);

        buttons.first = try pickers.person.add(try self.initParsingButton(
            "first_person",
            "1st Person",
            @ptrCast(&person_changed),
        ), display);

        buttons.second = try pickers.person.add(try self.initParsingButton(
            "second_person",
            "2nd Person",
            @ptrCast(&person_changed),
        ), display);

        buttons.third = try pickers.person.add(try self.initParsingButton(
            "third_person",
            "3rd Person",
            @ptrCast(&person_changed),
        ), display);
    }

    {
        pickers.case = try self.panel.add(.{
            .name = "case.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },

            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        buttons.nominative = try pickers.case.add(try self.initParsingButton(
            "nominative",
            "Nominative",
            @ptrCast(&case_changed),
        ), display);

        buttons.accusative = try pickers.case.add(try self.initParsingButton(
            "accusative",
            "Accusative",
            @ptrCast(&case_changed),
        ), display);

        buttons.genitive = try pickers.case.add(try self.initParsingButton(
            "genitive",
            "Genitive",
            @ptrCast(&case_changed),
        ), display);

        buttons.dative = try pickers.case.add(try self.initParsingButton(
            "dative",
            "Dative",
            @ptrCast(&case_changed),
        ), display);
    }

    {
        pickers.number = try self.panel.add(.{
            .name = "number.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        buttons.singular = try pickers.number.add(try self.initParsingButton(
            "singular",
            "Singular",
            @ptrCast(&number_changed),
        ), display);

        buttons.plural = try pickers.number.add(try self.initParsingButton(
            "plural",
            "Plural",
            @ptrCast(&number_changed),
        ), display);
    }

    {
        pickers.gender = try self.panel.add(.{
            .name = "gender.picker",
            .background = .{
                .image_name = "white rounded rect",
                .image_corner_radius = 14,
                .corner_radius = 14,
            },
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = PARSING_BUTTON_Y_PADDING, .bottom = PARSING_BUTTON_Y_PADDING },
            .minimum = .{ .width = 300, .height = 30 },
            .type = .{ .panel = .{ .spacing = PARSING_BUTTON_X_PADDING, .direction = .left_to_right } },
        }, display);

        buttons.masculine = try pickers.gender.add(try self.initParsingButton(
            "masculine",
            "Masculine",
            @ptrCast(&gender_changed),
        ), display);

        buttons.feminine = try pickers.gender.add(try self.initParsingButton(
            "feminine",
            "Feminine",
            @ptrCast(&gender_changed),
        ), display);

        buttons.neuter = try pickers.gender.add(try self.initParsingButton(
            "neuter",
            "Neuter",
            @ptrCast(&gender_changed),
        ), display);
    }

    try self.correct_panel.init(
        ac.APP_MINIMUM_WIDTH,
        ac.APP_MAXIMUM_WIDTH - 40,
        &self.app.bucket,
        display,
        self.panel,
        .success,
        .{ .func = null, .ptr = self },
        .{ .func = @ptrCast(&next_clicked), .ptr = self },
    );
    try self.incorrect_panel.init(
        ac.APP_MINIMUM_WIDTH,
        ac.APP_MAXIMUM_WIDTH - 40,
        &self.app.bucket,
        display,
        self.panel,
        .failed,
        .{ .func = null, .ptr = self },
        .{ .func = @ptrCast(&next_clicked), .ptr = self },
    );

    _ = try self.panel.add(.{
        .name = "bottom.expander",
        .rect = .{ .x = 0, .y = 0, .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 1.3 } },
    }, display);

    _ = try self.panel.add(.{
        .rect = .{ .x = 30, .y = 30 },
        .layout = .{ .x = .fixed, .y = .fixed },
        .type = .{ .panel = .{} },
    }, display);
}

pub fn deinit(self: *ParsingCardScreen) void {
    self.* = undefined;
}

fn initParsingButton(
    self: *ParsingCardScreen,
    name: []const u8,
    text: []const u8,
    handler: *const fn (*anyopaque, *Display, *Entity, *const Event) Allocator.Error!void,
) !Entity {
    return .{
        .name = name,
        .pad = .{
            .left = PARSING_BUTTON_X_PADDING,
            .right = PARSING_BUTTON_X_PADDING,
            .top = PARSING_BUTTON_Y_PADDING,
            .bottom = PARSING_BUTTON_Y_PADDING,
        },
        .background = .{
            .image_corner_radius = 14,
            .corner_radius = 14,
        },
        .layout = .{ .y = .shrinks, .x = .shrinks },
        .type = .{ .button = .{
            .text = text,
            .toggle = .off,
            .on_pressed = .{ .func = handler, .ptr = self },
            .button = .{
                .default_name = "white rounded rect",
                .pressed_name = "white rounded rect",
                .hover_name = "white rounded rect",
            },
        } },
    };
}

pub fn tapBack(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) error{OutOfMemory}!void {
    try self.app.menu_ui.progress_bar.setVisibility(display, .hidden);
    try self.app.menu_ui.toolbar.setVisibility(display, .visible);
    self.correct_panel.panel.visible = .hidden;
    self.incorrect_panel.panel.visible = .hidden;

    const pc = self.app.parsing_quiz;
    if (pc.lexeme) |lexeme| {
        try self.app.parsing_setup.study_by_form(
            display,
            lexeme,
            self.app.parsing_setup.called_by,
            event,
        );
    } else if (pc.word_set) |list| {
        try self.app.parsing_setup.study_by_list(
            display,
            list,
            self.app.parsing_setup.called_by,
            event,
        );
    } else {
        try self.app.parsing_menu.show(display, element, event);
    }
}

var pickers = struct {
    case: *Entity = undefined,
    gender: *Entity = undefined,
    number: *Entity = undefined,

    tense_form: *Entity = undefined,
    voice: *Entity = undefined,
    mood: *Entity = undefined,
    person: *Entity = undefined,
}{};

var buttons = struct {
    nominative: *Entity = undefined,
    accusative: *Entity = undefined,
    genitive: *Entity = undefined,
    dative: *Entity = undefined,
    singular: *Entity = undefined,
    plural: *Entity = undefined,
    masculine: *Entity = undefined,
    feminine: *Entity = undefined,
    neuter: *Entity = undefined,
    present: *Entity = undefined,
    future: *Entity = undefined,
    imperfect: *Entity = undefined,
    aorist: *Entity = undefined,
    perfect: *Entity = undefined,
    pluperfect: *Entity = undefined,
    active: *Entity = undefined,
    middle: *Entity = undefined,
    passive: *Entity = undefined,
    indicative: *Entity = undefined,
    participle: *Entity = undefined,
    subjunctive: *Entity = undefined,
    imperative: *Entity = undefined,
    infinitive: *Entity = undefined,
    first: *Entity = undefined,
    second: *Entity = undefined,
    third: *Entity = undefined,

    const Self = @This();

    pub fn list(b: *Self) [26]*Entity {
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

        var oo: std.Io.Writer.Allocating = .init(gpa);
        defer oo.deinit();
        for (valid_forms.items) |vf| {
            vf.parsing.string(&oo.writer) catch {};
            oo.writer.writeByte(' ') catch {};
        }
        info("check {s} (count={d}) matched {any}", .{ oo.written(), valid_forms.items.len, correct });

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

pub fn resizeCard(self: *ParsingCardScreen, display: *Display, _: *Entity) bool {
    if (self.app.preference.size == .large or
        self.app.preference.size == .extra_large or
        display.root.rect.height < 1200)
        self.help_line.setVisibility(display, .hidden) catch {}
    else
        self.help_line.setVisibility(display, .visible) catch {};
    return false;
}

pub fn next_clicked(self: *ParsingCardScreen, display: *Display, element: *Entity, event: *Event) error{OutOfMemory}!void {
    //try self.slide_panel_out(display);
    if (self.app.parsing_quiz.form_bank.items.len == 0) {
        try self.app.menu_ui.progress_bar.setVisibility(display, .hidden);
        try self.app.menu_ui.toolbar.setVisibility(display, .visible);
        if (ac.app_context.?.word_lexeme) |lexeme| {
            try self.app.parsing_setup.study_by_form(display, lexeme, self.app.parsing_setup.called_by, event);
        } else {
            try self.app.parsing_menu.show(display, element, event);
        }
        return;
    }
    _ = try self.setupNextCard(display);
}

pub fn button_bounce(
    self: *ParsingCardScreen,
    display: *Display,
    button: *Entity,
) error{OutOfMemory}!void {
    button.layout.x = .fixed;
    button.layout.y = .fixed;
    const animation: engine.Animator = .{
        .target = button,
        .mode = .{ .move = .{
            .start = button.rect,
            .end = .{
                .x = button.rect.x,
                .y = button.rect.y,
                .width = 10,
                .height = 2,
            },
        } },
        .movement = .stretch,
        .duration = 100 * 1000,
        .on_end = .{ .func = @ptrCast(&button_bounce_end), .ptr = self },
    };
    try display.addAnimator(animation);
}

pub fn button_bounce_end(
    _: *ParsingCardScreen,
    _: *Display,
    button: *Entity,
) Allocator.Error!void {
    button.layout.x = .shrinks;
    button.layout.y = .shrinks;
}

var help_line_buffer: [2][500]u8 = undefined;
var help_line_buffer_i: usize = 0;

pub fn setupNextCard(
    self: *ParsingCardScreen,
    display: *Display,
) error{OutOfMemory}!bool {
    if (self.app.parsing_quiz.form_bank.items.len == 0) {
        warn("Not starting quiz. Form bank has no words.", .{});
        return false;
    }

    const form = ac.app_context.?.parsing_quiz.next_form();
    self.progress_bar.type.progress_bar.progress = self.app.parsing_quiz.progress();

    try self.quiz_word.setText(display, form.*.word);

    help_line_buffer_i += 1;
    if (help_line_buffer_i >= help_line_buffer.len) {
        help_line_buffer_i = 0;
    }

    const text = std.fmt.bufPrint(&help_line_buffer[help_line_buffer_i], "Describe the grammar of {s}.", .{form.*.word}) catch "Describe the grammar of this word.";
    try self.help_line.setText(display, text);

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
            err("setupNextCard doesnt handle {s}", .{@tagName(form.*.parsing.part_of_speech)});
        },
    }

    buttons.clear_options();
    display.need_relayout = true;
    return true;
}

fn show_answer_if_ready(self: *ParsingCardScreen, display: *Display) error{OutOfMemory}!void {
    std.debug.assert(self.app.parsing_quiz.form_bank.items.len > 0);
    const current_form = self.app.parsing_quiz.form_bank.items[0];
    if (buttons.options_picked(current_form)) |parsing| {
        const correct = try buttons.mark_answers(current_form, parsing, display.allocator);
        if (correct) {
            info("User chose {any} correct.", .{parsing});
            self.correct_panel.showCorrectFeedback(display, null, null, &.{}) catch |f| {
                err("Failed to show correct panel {t}.", .{f});
            };
            _ = self.app.parsing_quiz.remove_current_form();
        } else {
            info("User chose {any} incorrect. Expecting {any}", .{ parsing, current_form.parsing });
            self.incorrect_panel.showIncorrectFeedback(display, null, null, &.{}) catch |f| {
                err("Failed to show incorrect panel {t}.", .{f});
            };
        }
        buttons.lock_unpicked_toggles();
        display.need_relayout = true;
    } else {
        trace("user still picking", .{});
    }
    return;
}

fn case_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.nominative,
            buttons.accusative,
            buttons.genitive,
            buttons.dative,
        });
        try self.button_bounce(display, element);
    }
    try self.show_answer_if_ready(display);
}

fn number_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.singular,
            buttons.plural,
        });
        try self.button_bounce(display, element);
    }
    try self.show_answer_if_ready(display);
}

fn gender_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.masculine,
            buttons.feminine,
            buttons.neuter,
        });
        try self.button_bounce(display, element);
    }
    try self.show_answer_if_ready(display);
}

fn tense_form_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.present,
            buttons.future,
            buttons.aorist,
            buttons.imperfect,
            buttons.perfect,
            buttons.pluperfect,
        });
        try self.button_bounce(display, element);
    }
    try self.show_answer_if_ready(display);
}

fn mood_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.indicative,
            buttons.participle,
            buttons.subjunctive,
            buttons.infinitive,
            buttons.imperative,
        });
        try self.button_bounce(display, element);
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
    try self.show_answer_if_ready(display);
}

fn voice_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.active,
            buttons.middle,
            buttons.passive,
        });
        try self.button_bounce(display, element);
    }
    try self.show_answer_if_ready(display);
}

fn person_changed(
    self: *ParsingCardScreen,
    display: *Display,
    element: *Entity,
    _: *const Event,
) error{OutOfMemory}!void {
    if (element.type.button.toggle == .on) {
        clear_other_toggles(element, &.{
            buttons.first,
            buttons.second,
            buttons.third,
        });
        try self.button_bounce(display, element);
    }
    try self.show_answer_if_ready(display);
}

fn clear_other_toggles(current: *Entity, others: []const *Entity) void {
    for (others) |*other| {
        if (current != other.*)
            other.*.type.button.toggle = .off;
    }
}

fn formsHaveTenseForm(forms: []*praxis.Form, tense_form: praxis.Parsing.TenseForm) bool {
    for (forms) |form|
        if (form.parsing.tense_form == tense_form)
            return true;
    return false;
}

fn formsHaveVoice(forms: []*praxis.Form, voice: praxis.Parsing.Voice) bool {
    for (forms) |form|
        if (form.parsing.voice == voice)
            return true;
    return false;
}

fn formsHaveGender(forms: []*praxis.Form, gender: praxis.Parsing.Gender) bool {
    for (forms) |form|
        if (form.parsing.gender == gender)
            return true;
    return false;
}

fn formsHaveMood(forms: []*praxis.Form, mood: praxis.Parsing.Mood) bool {
    for (forms) |form|
        if (form.parsing.mood == mood)
            return true;
    return false;
}

fn formsHaveCase(forms: []*praxis.Form, case: praxis.Parsing.Case) bool {
    for (forms) |form|
        if (form.parsing.case == case)
            return true;
    return false;
}

fn formsHaveNumber(forms: []*praxis.Form, number: praxis.Parsing.Number) bool {
    for (forms) |form|
        if (form.parsing.number == number)
            return true;
    return false;
}

fn formsHaveRefNumber(forms: []*praxis.Form, number: praxis.Parsing.TenseForm) bool {
    for (forms) |form|
        if (form.parsing.tense_form == number)
            return true;
    return false;
}

fn formsHavePerson(forms: []*praxis.Form, person: praxis.Parsing.Person) bool {
    for (forms) |form|
        if (form.parsing.person == person)
            return true;
    return false;
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const Display = engine.Display;
const ToggleState = engine.ToggleState;
const Entity = engine.Entity;
const Event = engine.Event;
const trace = engine.log.trace;
const debug = engine.log.debug;
const info = engine.log.info;
const warn = engine.log.warn;
const err = engine.log.err;

const praxis = @import("praxis");
const Lexeme = praxis.Lexeme;
const Form = praxis.Form;

const resources = @import("resources");
const Resources = resources.Resources;
const ResourcesError = resources.Resources.Error;
const seed = praxis.random.seed;

const ac = @import("App.zig");
const AppContext = ac.AppContext;

const MenuUI = @import("MenuUI.zig");
const FeedbackPanel = @import("FeedbackPanel.zig");
const ParsingMenuScreen = @import("ParsingMenuScreen.zig");
