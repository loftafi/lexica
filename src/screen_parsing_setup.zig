//! Study a single word, or a list of words

var panel: *Element = undefined;
var noun_panel: *Element = undefined;
var verb_panel: *Element = undefined;
var counter: *Element = undefined;
var scroller: *Element = undefined;
var back_button: *Element = undefined;
var help_line: *Element = undefined;
var noun_verb_spacer: *Element = undefined;

var button_bar: *Element = undefined;
var button_bar_spacer: *Element = undefined;
var start_button: *Element = undefined;
var delete_button: *Element = undefined;
var edit_button: *Element = undefined;
pub var called_by: ac.Screen = .unknown;

const ICON_PAD = 30;

/// The list of words that we are studying (In word list study mode.)
pub var list: ?*WordSet = null;

/// The individual word that we are studying (In word study mode)
var lexeme: ?*Lexeme = null;
var heading: *Element = undefined;

pub fn study_by_form(display: *Display, called_lexeme: *praxis.Lexeme, from_caller: ac.Screen) error{OutOfMemory}!void {
    called_by = from_caller;
    lexeme = called_lexeme;
    ac.app_context.?.word_lexeme = lexeme;
    list = null;
    button_bar_spacer.visible = .hidden;
    edit_button.visible = .hidden;
    delete_button.visible = .hidden;
    button_bar.type.panel.style = .background;
    scroller.offset = .{ .x = 0, .y = 0 };

    info("ParsingSetupScreen({s} {s})", .{ @tagName(called_by), lexeme.?.word });

    // Checkboxes should contain the default values
    checkboxes.load_preferences();

    // Only show filter options that are valid for these word forms
    try ac.app_context.?.parsing_quiz.setup_with_lexeme(called_lexeme);
    checkboxes.update_statistics(ac.app_context.?.parsing_quiz.all_forms.items);

    debug("parsing picker for {s}", .{called_lexeme.word});
    try heading.set_text(display, "", false);
    try heading.set_text(display, called_lexeme.word, false);
    try help_line.set_text(display, "", false);
    if (new_help_line(display, "Choose which forms of {s} to study.", .{called_lexeme.word})) {
        try help_line.set_text(display, help_text, false);
    } else |_| {
        try help_line.set_text(display, "Choose which forms to study.", false);
    }
    help_line.visible = .hidden;

    try refresh_menu(display);
    display.choose_panel("parsing.setup");
    display.need_relayout = true;
}

pub fn study_by_list(display: *Display, study_list: *WordSet, from_caller: ac.Screen) error{OutOfMemory}!void {
    called_by = from_caller;
    list = study_list;
    ac.app_context.?.word_lexeme = null;
    lexeme = null;
    button_bar_spacer.visible = .visible;
    edit_button.visible = .visible;
    delete_button.visible = .visible;
    button_bar.type.panel.style = .faded;
    ListEditScreen.list = list;
    scroller.offset = .{ .x = 0, .y = 0 };

    info("ParsingSetupScreen({s} {s})", .{ @tagName(called_by), study_list.name.items });

    // Checkboxes should contain the default values
    checkboxes.load_preferences();

    // Only show filter options that are valid for these word forms
    checkboxes.update_statistics(try study_list.study_forms());

    debug("parsing picker for {s}", .{study_list.name.items});
    try heading.set_text(display, "", false);
    try heading.set_text(display, study_list.name.items, false);
    help_line.visible = .hidden;

    try refresh_menu(display);
    display.choose_panel("parsing.setup");
    display.need_relayout = true;
}

pub const Checkboxes = struct {
    present_future: *Element = undefined,
    imperfect: *Element = undefined,
    aorist: *Element = undefined,
    perfect_pluperfect: *Element = undefined,
    middle_passive: *Element = undefined,
    middle_passive_spacer: *Element = undefined,
    indicative: *Element = undefined,
    participles: *Element = undefined,
    subjunctive: *Element = undefined,
    infinitive: *Element = undefined,
    imperative: *Element = undefined,
    nominative_accusative: *Element = undefined,
    genitive_dative: *Element = undefined,
    third_declension: *Element = undefined,

    pub fn load_preferences(self: *Checkboxes) void {
        self.present_future.type.checkbox.checked = ac.app_context.?.preference.present_future;
        self.aorist.type.checkbox.checked = ac.app_context.?.preference.aorist;
        self.imperfect.type.checkbox.checked = ac.app_context.?.preference.imperfect;
        self.perfect_pluperfect.type.checkbox.checked = ac.app_context.?.preference.perfect_pluperfect;

        self.middle_passive.type.checkbox.checked = ac.app_context.?.preference.middle_passive;
        self.nominative_accusative.type.checkbox.checked = ac.app_context.?.preference.nominative_accusative;
        self.genitive_dative.type.checkbox.checked = ac.app_context.?.preference.genitive_dative;
        self.third_declension.type.checkbox.checked = ac.app_context.?.preference.third_declension;

        self.indicative.type.checkbox.checked = ac.app_context.?.preference.indicative;
        self.participles.type.checkbox.checked = ac.app_context.?.preference.participle;
        self.subjunctive.type.checkbox.checked = ac.app_context.?.preference.subjunctive;
        self.infinitive.type.checkbox.checked = ac.app_context.?.preference.infinitive;
        self.imperative.type.checkbox.checked = ac.app_context.?.preference.imperative;
    }

    // Only show filter options that are valid for these word forms
    pub fn update_statistics(self: *Checkboxes, forms: []*praxis.Form) void {
        var stats = @import("filter_stats.zig").Stats{};
        stats.count(forms);
        self.nominative_accusative.visible = is_visible(stats.nominative_accusative.match > 0);
        self.genitive_dative.visible = is_visible(stats.genitive_dative.match > 0);
        self.third_declension.visible = is_visible(stats.third_declension.match > 0);
        self.present_future.visible = is_visible(stats.present_future.match > 0);
        self.aorist.visible = is_visible(stats.aorist.match > 0);
        self.perfect_pluperfect.visible = is_visible(stats.perfect_pluperfect.match > 0);
        self.indicative.visible = is_visible(stats.indicative.match > 0);
        self.imperfect.visible = is_visible(stats.imperfect.match > 0);
        self.imperative.visible = is_visible(stats.imperative.match > 0);
        self.infinitive.visible = is_visible(stats.infinitive.match > 0);
        self.subjunctive.visible = is_visible(stats.subjunctive.match > 0);
        self.middle_passive.visible = is_visible(stats.middle_passive.match > 0);
        self.participles.visible = is_visible(stats.participle.match > 0);
    }
};

var checkboxes = Checkboxes{};

pub fn deinit() void {
    //
}

pub fn init(context: *AppContext) !void {
    var display = context.display;

    panel = try display.root.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "parsing.setup",
            .rect = .{ .x = 0, .y = 0 },
            .layout = .{ .x = .grows, .y = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
            .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
            .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
            .visible = .hidden,
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        },
    ));

    back_button = try display.add_back_button(panel, go_back);

    heading = try panel.add(try engine.create_label(
        display,
        "",
        .{
            .name = "parsing.setup.word",
            .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
            .layout = .{ .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .type = .{ .label = .{
                .text = "",
                .text_size = .heading,
                .text_colour = .tinted,
            } },
        },
    ));
    heading.pad.top = 30;

    scroller = try engine.create_panel(
        context.display,
        "",
        .{
            .name = "scroll.panel",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .minimum = .{ .width = 400, .height = 600 },
            .type = .{
                .panel = .{
                    .scrollable = .{
                        .scroll = .{ .x = false, .y = true },
                        .size = .{ .width = 600, .height = 600 },
                    },
                    .direction = .top_to_bottom,
                    .spacing = 10,
                },
            },
            .on_resized = handle_resize,
        },
    );
    try panel.add_element(scroller);

    help_line = try engine.create_label(
        display,
        "",
        .{
            .name = "parsing.setup.heading",
            .rect = .{ .width = 500, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .type = .{ .label = .{
                .text = "Choose which forms to study.",
                .text_size = .normal,
                .text_colour = .normal,
            } },
        },
    );
    try scroller.add_element(help_line);

    try scroller.add_element(try engine.create_expander(
        display,
        .{
            .name = "top.expander",
            .rect = .{ .width = 100, .height = 5 },
            .minimum = .{ .width = 100, .height = 5 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 0.7 } },
        },
    ));

    {
        noun_panel = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "noun.config.panel",
                .rect = .{ .width = 500, .height = 30 },
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .top = 20, .bottom = 20 },
                .minimum = .{ .width = 500, .height = 30 },
                .maximum = .{ .width = 1000 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
            },
        );
        try scroller.add_element(noun_panel);

        checkboxes.nominative_accusative = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.na",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Nominative and Accusative",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_nominative_accusative_preference,
                } },
            },
        );
        try noun_panel.add_element(checkboxes.nominative_accusative);

        checkboxes.genitive_dative = try noun_panel.add(try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.gd",
                .rect = .{ .width = 600, .height = 20 },
                .minimum = .{ .width = 200, .height = 200 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Genitive and Dative",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_genitive_dative_preference,
                } },
            },
        ));

        checkboxes.third_declension = try noun_panel.add(try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.third",
                .layout = .{ .y = .shrinks, .x = .grows },
                .visible = .hidden,
                .type = .{ .checkbox = .{
                    .text = "Third Declension",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_third_declension_preference,
                } },
            },
        ));
    }

    noun_verb_spacer = try scroller.add(try engine.create_panel(
        display,
        "",
        .{
            .name = "noun_verb_spacer",
            .rect = .{ .width = 20, .height = 20 },
            .minimum = .{ .width = 20, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .panel = .{} },
        },
    ));

    {
        verb_panel = try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "verb.config.panel",
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .top = 20, .bottom = 20 },
                .minimum = .{ .width = 500, .height = 30 },
                .maximum = .{ .width = 1000 },
                .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
            },
        );
        checkboxes.present_future = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.pf",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Present and Future",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_present_future_preference,
                } },
            },
        );
        try verb_panel.add_element(checkboxes.present_future);

        checkboxes.imperfect = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.impf",
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Imperfect",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_imperfect_preference,
                } },
            },
        );
        try verb_panel.add_element(checkboxes.imperfect);

        checkboxes.aorist = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.aor",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Aorist",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_aorist_preference,
                } },
            },
        );
        try verb_panel.add_element(checkboxes.aorist);

        checkboxes.perfect_pluperfect = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.pfplpf",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Perfect and Pluperfect",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_perfect_pluperfect_preference,
                } },
            },
        );
        try verb_panel.add_element(checkboxes.perfect_pluperfect);

        checkboxes.middle_passive_spacer = try engine.create_panel(
            display,
            "",
            .{
                .name = "spacer",
                .rect = .{ .width = 20, .height = 20 },
                .minimum = .{ .width = 20, .height = 20 },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{ .panel = .{} },
            },
        );
        try verb_panel.add_element(checkboxes.middle_passive_spacer);

        checkboxes.middle_passive = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.midpsv",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Middle and Passive",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_middle_passive_preference,
                } },
            },
        );
        try verb_panel.add_element(checkboxes.middle_passive);
        try scroller.add_element(verb_panel);

        try scroller.add_element(try engine.create_expander(
            display,
            .{
                .name = "middle.expander",
                .rect = .{ .width = 100, .height = 20 },
                .minimum = .{ .width = 100, .height = 20 },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{ .expander = .{ .weight = 0.4 } },
            },
        ));

        checkboxes.indicative = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.indicative",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Indicative",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_indicative_preference,
                } },
            },
        );
        try scroller.add_element(checkboxes.indicative);

        checkboxes.participles = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.ptcp",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Participles",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_participles_preference,
                } },
            },
        );
        try scroller.add_element(checkboxes.participles);

        checkboxes.subjunctive = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.sbj",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Subjunctive",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_subjunctive_preference,
                } },
            },
        );
        try scroller.add_element(checkboxes.subjunctive);

        checkboxes.infinitive = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.inf",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Infinitive",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_infinitive_preference,
                } },
            },
        );
        try scroller.add_element(checkboxes.infinitive);

        checkboxes.imperative = try engine.create_checkbox(
            display,
            "",
            .{
                .name = "include.impv",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Imperative",
                    .text_size = .normal,
                    .text_colour = .normal,
                    .on_change = change_imperative_preference,
                } },
            },
        );
        try scroller.add_element(checkboxes.imperative);

        _ = try display.add_spacer(scroller, 20);
    }

    counter = try engine.create_label(
        display,
        "",
        .{
            .name = "filter.count",
            .rect = .{ .width = 500, .height = 50 },
            .minimum = .{ .width = 420, .height = 50 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .child_align = .{ .x = .centre, .y = .start },
            .pad = .{ .left = 25, .right = 25, .top = 60, .bottom = 60 },
            .type = .{ .label = .{
                .text = "0 forms",
                .text_size = .normal,
                .text_colour = .tinted,
            } },
        },
    );
    try scroller.add_element(counter);

    {
        var wrapper = try scroller.add(try engine.create_panel(
            display,
            "",
            .{
                .name = "start.parsing.panel",
                .layout = .{ .x = .grows, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 20, .right = 20 },
                .minimum = .{ .width = 500, .height = 20 },
                .maximum = .{ .width = 1000 },
                .type = .{ .panel = .{
                    .direction = .left_to_right,
                } },
            },
        ));

        button_bar = try wrapper.add(try engine.create_panel(
            display,
            "white rounded rect",
            .{
                .name = "start.parsing.panel",
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .child_align = .{ .x = .centre },
                .pad = .{ .left = 10, .right = 30, .top = 20, .bottom = 20 },
                .minimum = .{ .width = 500, .height = 20 },
                .maximum = .{ .width = 1000 },
                .type = .{ .panel = .{
                    .style = .faded,
                    .direction = .left_to_right,
                    .spacing = 6,
                } },
            },
        ));

        edit_button = try button_bar.add(try engine.create_button(
            display,
            "edit-list-button",
            "edit-list-button",
            "edit-list-button",
            .{
                .name = "list.edit.button",
                .minimum = .{ .width = 10, .height = 15 },
                .pad = .{ .left = ICON_PAD, .right = ICON_PAD / 2, .top = ICON_PAD, .bottom = ICON_PAD },
                .child_align = .{ .x = .start, .y = .start },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{
                    .button = .{
                        .text = "Edit",
                        .on_click = show_list_editor,
                        .icon_size = .{ .x = 80, .y = 80 },
                        .spacing = 15,
                    },
                },
            },
            "",
            "",
            "",
        ));

        delete_button = try button_bar.add(try engine.create_button(
            display,
            "delete list button",
            "delete list button",
            "delete list button",
            .{
                .name = "delete.button",
                .minimum = .{ .width = 10, .height = 15 },
                .pad = .{ .left = ICON_PAD / 2, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{
                    .button = .{
                        .text = "Delete",
                        .on_click = show_list_delete,
                        .icon_size = .{ .x = 80, .y = 80 },
                        .spacing = 15,
                    },
                },
            },
            "",
            "",
            "",
        ));

        button_bar_spacer = try button_bar.add(try engine.create_panel(
            display,
            "",
            .{
                .name = "button.spacer",
                .rect = .{ .width = 30, .height = 20 },
                .minimum = .{ .width = 30, .height = 20 },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{ .panel = .{} },
            },
        ));

        start_button = try button_bar.add(try engine.create_button(
            display,
            "parsing button",
            "parsing button",
            "parsing button",
            .{
                .name = "start.button",
                .rect = .{ .x = 0, .y = 0, .width = 10, .height = 15 },
                .minimum = .{ .width = 10, .height = 15 },
                .pad = .{ .left = 30, .right = 30, .top = 30, .bottom = 30 },
                .child_align = .{ .x = .start, .y = .start },
                .layout = .{ .x = .shrinks, .y = .shrinks },
                .type = .{
                    .button = .{
                        .text = "Practice",
                        .on_click = show_parsing_card,
                        .icon_size = .{ .x = 80, .y = 80 },
                        .spacing = 20,
                    },
                },
            },
            "white rounded rect",
            "white rounded rect",
            "white rounded rect",
        ));
    }

    try scroller.add_element(try engine.create_expander(
        display,
        .{
            .name = "bottom.expander",
            .rect = .{ .width = 100, .height = 5 },
            .minimum = .{ .width = 100, .height = 5 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 0.7 } },
        },
    ));

    _ = try display.add_spacer(scroller, 70);
}

pub fn go_back(display: *Display, element: *Element) std.mem.Allocator.Error!void {

    // Go back to word info screen if thats where we were
    if (called_by == .word_info and lexeme != null) {
        info("ParsingSetupScreen({s} {s}) back", .{ @tagName(called_by), lexeme.?.word });
        try @import("screen_word_info.zig").show(display, lexeme.?);
        return;
    }

    // Otherwise we came from the parsing menu screen.
    info("ParsingSetupScreen({s}) back", .{@tagName(called_by)});
    try ParsingMenuScreen.show(display, element);
}

pub fn handle_resize(display: *Display, _: *Element) bool {
    var updated = false;

    if (ac.app_context.?.preference.size == .large or ac.app_context.?.preference.size == .extra_large) {
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

    const size = display.text_height * display.scale * engine.TextSize.normal.height();
    const height = size + (ICON_PAD * 2);
    if (edit_button.type.button.icon_size.x != size) {
        edit_button.type.button.icon_size.x = size;
        edit_button.type.button.icon_size.y = size;
        edit_button.minimum.width = height;
        edit_button.rect.height = height;
        edit_button.minimum.height = height;
        start_button.type.button.icon_size.x = size;
        start_button.type.button.icon_size.y = size;
        start_button.minimum.width = height;
        start_button.rect.height = height;
        start_button.minimum.height = height;
        delete_button.type.button.icon_size.x = size;
        delete_button.type.button.icon_size.y = size;
        delete_button.minimum.width = height;
        delete_button.rect.height = height;
        delete_button.minimum.height = height;
        updated = true;
    }

    const new_width = best_width(display);
    debug("parent_width={d} width={d}", .{ display.root.rect.width, new_width });
    if (panel.rect.width != new_width) {
        panel.rect.width = new_width;
        panel.minimum.width = new_width;
        panel.maximum.width = new_width;
        updated = true;
    }

    if (scroller.rect.height != display.root.rect.height - 340) {
        scroller.rect.height = display.root.rect.height - 340;
        scroller.minimum.height = scroller.rect.height;
        scroller.maximum.height = scroller.rect.height;
        updated = true;
    }

    return updated;
}

/// We need memory buffers for the `set_text` function.
var help_text: []const u8 = "";
var help_text_old: []const u8 = "";

fn new_help_line(display: *Display, comptime fmt: []const u8, args: anytype) !void {
    if (help_text_old.len > 0) {
        display.allocator.free(help_text_old);
    }
    help_text_old = help_text;
    if (fmt.len == 0) {
        help_text = "";
        return;
    }
    help_text = try std.fmt.allocPrint(display.allocator, fmt, args);
}

/// We need memory buffers for the `set_text` function.
var count_text: []const u8 = "";
var count_text_old: []const u8 = "";

fn new_count_line(display: *Display, comptime fmt: []const u8, args: anytype) !void {
    if (count_text_old.len > 0) {
        display.allocator.free(count_text_old);
    }
    count_text_old = count_text;
    if (fmt.len == 0) {
        count_text = "";
        return;
    }
    count_text = try std.fmt.allocPrint(display.allocator, fmt, args);
}

pub fn destroy(display: *Display) void {
    if (count_text.len > 0) {
        display.allocator.free(count_text);
    }
    if (count_text_old.len > 0) {
        display.allocator.free(count_text_old);
    }
    if (help_text.len > 0) {
        display.allocator.free(help_text);
    }
    if (help_text_old.len > 0) {
        display.allocator.free(help_text_old);
    }
}

fn is_visible(visible: bool) engine.Visibility {
    if (visible) {
        return .visible;
    }
    return .hidden;
}

pub fn update_counter_text(display: *Display) void {
    const count = ac.app_context.?.parsing_quiz.total_cards;
    if (count == 0) {
        counter.set_text(display, "No word forms.", false) catch {};
    } else if (count == 1) {
        counter.set_text(display, "1 word form.", false) catch {};
    } else {
        if (new_count_line(display, "{d} forms", .{count})) {
            counter.set_text(display, count_text, false) catch {};
        } else |_| {
            counter.set_text(display, "", false) catch {};
        }
    }
}

pub fn update_option_panels() void {
    if (lexeme) |word| {
        if (word.pos.part_of_speech == .verb) {
            noun_panel.visible = .hidden;
            verb_panel.visible = .visible;
        } else {
            noun_panel.visible = .visible;
            verb_panel.visible = .hidden;
        }
        return;
    }
    if (list) |current_list| {
        if (current_list.has_noun_or_adjective()) {
            noun_panel.visible = .visible;
        } else {
            noun_panel.visible = .hidden;
        }
        if (current_list.has_verb()) {
            verb_panel.visible = .visible;
        } else {
            verb_panel.visible = .hidden;
        }
    }
    if (verb_panel.visible == .visible and noun_panel.visible == .visible) {
        noun_verb_spacer.visible = .visible;
    } else {
        noun_verb_spacer.visible = .hidden;
    }
}

fn refresh_menu(display: *Display) !void {
    if (ac.app_context.?.preference.present_future == false and
        ac.app_context.?.preference.imperfect == false and
        ac.app_context.?.preference.aorist == false and
        ac.app_context.?.preference.perfect_pluperfect == false)
    {
        ac.app_context.?.preference.present_future = true;
        checkboxes.present_future.type.checkbox.checked = true;
    }
    if (ac.app_context.?.preference.indicative == false and
        ac.app_context.?.preference.participle == false and
        ac.app_context.?.preference.subjunctive == false and
        ac.app_context.?.preference.imperative == false and
        ac.app_context.?.preference.infinitive == false)
    {
        ac.app_context.?.preference.indicative = true;
        checkboxes.indicative.type.checkbox.checked = true;
    }
    if (ac.app_context.?.preference.nominative_accusative == false and
        ac.app_context.?.preference.genitive_dative == false)
    {
        ac.app_context.?.preference.nominative_accusative = true;
        checkboxes.nominative_accusative.type.checkbox.checked = true;
    }

    if (lexeme) |current_lexeme| {
        try ac.app_context.?.parsing_quiz.setup_with_lexeme(current_lexeme);
    } else if (list) |current_list| {
        try ac.app_context.?.parsing_quiz.setup_with_word_set(current_list);
    } else {
        err("Cant refresh menus without lexeme specified.", .{});
    }
    update_option_panels();
    update_counter_text(display);
}

pub fn change_nominative_accusative_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        if (ac.app_context.?.preference.nominative_accusative != element.type.checkbox.checked) {
            ac.app_context.?.preference.nominative_accusative = element.type.checkbox.checked;
            try refresh_menu(display);
        }
    }
}

pub fn change_third_declension_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        if (ac.app_context.?.preference.third_declension != element.type.checkbox.checked) {
            ac.app_context.?.preference.third_declension = element.type.checkbox.checked;
            try refresh_menu(display);
        }
    }
}

pub fn change_genitive_dative_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.genitive_dative = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_present_future_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.present_future = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_aorist_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.aorist = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_imperfect_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.imperfect = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_perfect_pluperfect_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.perfect_pluperfect = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_middle_passive_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.middle_passive = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_mi_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.mi = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_indicative_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.indicative = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_participles_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.participle = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_infinitive_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.infinitive = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_subjunctive_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.subjunctive = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn change_imperative_preference(display: *Display, element: *Element) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.imperative = element.type.checkbox.checked;
    }
    try refresh_menu(display);
}

pub fn filter_forms(forms: []*praxis.Form, set: *ArrayList(*praxis.Form)) error{OutOfMemory}!void {
    for (forms) |form| {
        const pos = form.parsing.part_of_speech;
        if (pos == .noun or pos == .verb or pos == .adjective or
            (pos == .proper_noun and form.lexeme.?.pos.indeclinable == false))
            try set.append(form);
    }
}

const std = @import("std");
const ArrayList = std.ArrayList;
const praxis = @import("praxis");
const Lexeme = praxis.Lexeme;
const engine = @import("engine");
const debug = engine.debug;
const info = engine.info;
const err = engine.err;
const Display = engine.Display;
const Element = engine.Element;
const ac = @import("app_context.zig");
const AppContext = ac.AppContext;
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const ParsingCardScreen = @import("screen_parsing_card.zig");
const ListEditScreen = @import("screen_list_edit.zig");
const ListDeleteScreen = @import("screen_list_delete.zig");
const show_parsing_menu = ParsingMenuScreen.show;
const show_parsing_card = ParsingCardScreen.show;
const show_list_editor = ListEditScreen.show;
const show_list_delete = ListDeleteScreen.show;
const best_width = @import("screen_search.zig").best_width;
const Lists = @import("lists.zig");
const WordSet = Lists.WordSet;
