//! Study a single word, or a list of words
pub const ParsingSetupScreen = @This();

const ICON_PAD = 30;

app: *AppContext = undefined,

panel: *Entity = undefined,
noun_panel: *Entity = undefined,
verb_panel: *Entity = undefined,
counter: *Entity = undefined,
scroller: *Entity = undefined,
back_button: *Entity = undefined,
help_line: *Entity = undefined,
noun_verb_spacer: *Entity = undefined,

button_bar: *Entity = undefined,
button_bar_spacer: *Entity = undefined,
start_button: *Entity = undefined,
delete_button: *Entity = undefined,
edit_button: *Entity = undefined,

called_by: ac.Screen = .unknown,

/// The list of words that we are studying (In word list study mode.)
list: ?*WordSet = null,

/// The individual word that we are studying (In word study mode)
lexeme: ?*Lexeme = null,
heading: *Entity = undefined,

checkboxes: Checkboxes = .{},

/// Study all forms of a specific lexeme
pub fn study_by_form(
    self: *ParsingSetupScreen,
    display: *Display,
    called_lexeme: *praxis.Lexeme,
    from_caller: ac.Screen,
    event: *Event,
) error{OutOfMemory}!void {
    const ctx = ac.app_context.?;

    self.called_by = from_caller;
    self.lexeme = called_lexeme;
    ctx.word_lexeme = self.lexeme;
    self.list = null;
    self.button_bar_spacer.visible = .hidden;
    self.edit_button.visible = .hidden;
    self.delete_button.visible = .hidden;
    self.button_bar.style = .background;
    self.scroller.offset = .{ .x = 0, .y = 0 };

    info("ParsingSetupScreen({s} {s})", .{ @tagName(self.called_by), self.lexeme.?.word });

    // Checkboxes should contain the default values
    self.checkboxes.load_preferences();

    // Only show filter options that are valid for these word forms
    try ctx.parsing_quiz.setup_with_lexeme(called_lexeme);
    self.checkboxes.update_statistics(ctx.parsing_quiz.all_forms.items);

    debug("parsing picker for {s}", .{called_lexeme.word});
    try self.heading.setText(display, "");
    try self.heading.setText(display, called_lexeme.word);
    try self.help_line.setText(display, "");

    try self.help_line.setText(display, display.bucket.addFmt("Choose which forms of {s} to study.", .{called_lexeme.word}) catch "");
    try self.help_line.setVisibility(display, .hidden);

    try self.refresh_menu(display);
    try display.choosePanel("parsing.setup", event);
}

/// Study all forms of lexemes in a word set.
pub fn study_by_list(
    self: *ParsingSetupScreen,
    display: *Display,
    study_list: *WordSet,
    from_caller: ac.Screen,
    event: *Event,
) error{OutOfMemory}!void {
    self.called_by = from_caller;
    self.list = study_list;
    ac.app_context.?.word_lexeme = null;
    self.lexeme = null;
    self.button_bar_spacer.visible = .visible;
    self.edit_button.visible = .visible;
    self.delete_button.visible = .visible;
    self.button_bar.style = .faded;
    self.app.list_edit.list = self.list;
    self.scroller.offset = .{ .x = 0, .y = 0 };

    info("ParsingSetupScreen({s} {s})", .{ @tagName(self.called_by), study_list.name.items });

    // Checkboxes should contain the default values
    self.checkboxes.load_preferences();

    // Only show filter options that are valid for these word forms
    self.checkboxes.update_statistics(try study_list.study_forms(display.allocator));

    debug("parsing picker for {s}", .{study_list.name.items});
    try self.heading.setText(display, "");
    try self.heading.setText(display, study_list.name.items);
    self.help_line.visible = .hidden;

    try self.refresh_menu(display);
    try display.choosePanel("parsing.setup", event);
}

pub const Checkboxes = struct {
    present_future: *Entity = undefined,
    imperfect: *Entity = undefined,
    aorist: *Entity = undefined,
    perfect_pluperfect: *Entity = undefined,
    middle_passive: *Entity = undefined,
    middle_passive_spacer: *Entity = undefined,
    indicative: *Entity = undefined,
    participles: *Entity = undefined,
    subjunctive: *Entity = undefined,
    infinitive: *Entity = undefined,
    imperative: *Entity = undefined,
    nominative_accusative: *Entity = undefined,
    genitive_dative: *Entity = undefined,
    third_declension: *Entity = undefined,

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

pub fn deinit(self: *ParsingSetupScreen) void {
    self.* = undefined;
}

pub fn init(self: *ParsingSetupScreen, context: *AppContext) !void {
    self.app = context;

    var display = context.display;

    self.panel = try display.addPanel(.{
        .name = "parsing.setup",
        .rect = .{ .x = 0, .y = 0 },
        .layout = .{ .x = .grows, .y = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .minimum = .{ .width = ac.APP_MINIMUM_WIDTH, .height = ac.APP_MINIMUM_HEIGHT },
        .maximum = .{ .width = ac.APP_MAXIMUM_WIDTH },
        .pad = .{ .left = ac.APP_PAD, .right = ac.APP_PAD },
        .visible = .hidden,
        .type = .{ .panel = .{
            .spacing = 10,
            .direction = .top_to_bottom,
            .choosable = .choosable,
        } },
    });

    self.back_button = try self.app.add_back_button(self.panel, .{
        .func = @ptrCast(&go_back),
        .ptr = self,
    });

    self.heading = try self.panel.add(.{
        .name = "parsing.setup.word",
        .pad = .{ .left = 10, .right = 10, .top = 10, .bottom = 10 },
        .layout = .{ .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "",
            .text_size = .heading,
        } },
    }, display);
    self.heading.pad.top = 30;

    self.scroller = try self.panel.add(.{
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
        .on_resized = .{
            .func = @ptrCast(&handle_resize),
            .ptr = self,
        },
    }, display);

    self.help_line = try self.scroller.add(.{
        .name = "parsing.setup.heading",
        .rect = .{ .width = 500, .height = 20 },
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .type = .{ .label = .{
            .text = "Choose which forms to study.",
        } },
    }, display);

    _ = try self.scroller.add(.{
        .name = "top.expander",
        .rect = .{ .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 0.7 } },
    }, display);

    {
        self.noun_panel = try self.scroller.add(.{
            .name = "noun.config.panel",
            .background = .{ .image_name = "white rounded rect" },
            .rect = .{ .width = 500, .height = 30 },
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = 20, .bottom = 20 },
            .minimum = .{ .width = 500, .height = 30 },
            .maximum = .{ .width = 1000 },
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        }, display);

        self.checkboxes.nominative_accusative = try self.noun_panel.add(.{
            .name = "include.na",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Nominative and Accusative",
                .on_change = .{ .func = @ptrCast(&change_nominative_accusative_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.genitive_dative = try self.noun_panel.add(.{
            .name = "include.gd",
            .rect = .{ .width = 600, .height = 20 },
            .minimum = .{ .width = 200, .height = 200 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Genitive and Dative",
                .on_change = .{ .func = @ptrCast(&change_genitive_dative_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.third_declension = try self.noun_panel.add(.{
            .name = "include.third",
            .layout = .{ .y = .shrinks, .x = .grows },
            .visible = .hidden,
            .type = .{ .checkbox = .{
                .text = "Third Declension",
                .on_change = .{ .func = @ptrCast(&change_third_declension_preference), .ptr = self },
            } },
        }, display);
    }

    self.noun_verb_spacer = try self.scroller.add(.{
        .name = "noun_verb_spacer",
        .rect = .{ .width = 20, .height = 20 },
        .minimum = .{ .width = 20, .height = 20 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .panel = .{} },
    }, display);

    {
        self.verb_panel = try self.scroller.add(.{
            .name = "verb.config.panel",
            .background = .{ .image_name = "white rounded rect" },
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .top = 20, .bottom = 20 },
            .minimum = .{ .width = 500, .height = 30 },
            .maximum = .{ .width = 1000 },
            .type = .{ .panel = .{ .spacing = 10, .direction = .top_to_bottom } },
        }, display);

        self.checkboxes.present_future = try self.verb_panel.add(.{
            .name = "include.pf",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Present and Future",
                .on_change = .{ .func = @ptrCast(&change_present_future_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.imperfect = try self.verb_panel.add(.{
            .name = "include.impf",
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Imperfect",
                .on_change = .{ .func = @ptrCast(&change_imperfect_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.aorist = try self.verb_panel.add(.{
            .name = "include.aor",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Aorist",
                .on_change = .{ .func = @ptrCast(&change_aorist_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.perfect_pluperfect = try self.verb_panel.add(.{
            .name = "include.pfplpf",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Perfect and Pluperfect",
                .on_change = .{ .func = @ptrCast(&change_perfect_pluperfect_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.middle_passive_spacer = try self.verb_panel.add(.{
            .name = "spacer",
            .rect = .{ .width = 20, .height = 20 },
            .minimum = .{ .width = 20, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .panel = .{} },
        }, display);

        self.checkboxes.middle_passive = try self.verb_panel.add(.{
            .name = "include.midpsv",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Middle and Passive",
                .on_change = .{ .func = @ptrCast(&change_middle_passive_preference), .ptr = self },
            } },
        }, display);

        _ = try self.scroller.add(.{
            .name = "middle.expander",
            .rect = .{ .width = 100, .height = 20 },
            .minimum = .{ .width = 100, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .expander = .{ .weight = 0.4 } },
        }, display);

        self.checkboxes.indicative = try self.scroller.add(.{
            .name = "include.indicative",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Indicative",
                .on_change = .{ .func = @ptrCast(&change_indicative_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.participles = try self.scroller.add(.{
            .name = "include.ptcp",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Participles",
                .on_change = .{ .func = @ptrCast(&change_participles_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.subjunctive = try self.scroller.add(
            .{
                .name = "include.sbj",
                .rect = .{ .width = 600, .height = 20 },
                .layout = .{ .y = .shrinks, .x = .grows },
                .type = .{ .checkbox = .{
                    .text = "Subjunctive",
                    .on_change = .{ .func = @ptrCast(&change_subjunctive_preference), .ptr = self },
                } },
            },
            display,
        );

        self.checkboxes.infinitive = try self.scroller.add(.{
            .name = "include.inf",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Infinitive",
                .on_change = .{ .func = @ptrCast(&change_infinitive_preference), .ptr = self },
            } },
        }, display);

        self.checkboxes.imperative = try self.scroller.add(.{
            .name = "include.impv",
            .rect = .{ .width = 600, .height = 20 },
            .layout = .{ .y = .shrinks, .x = .grows },
            .type = .{ .checkbox = .{
                .text = "Imperative",
                .on_change = .{ .func = @ptrCast(&change_imperative_preference), .ptr = self },
            } },
        }, display);

        _ = try display.add_spacer(self.scroller, 20);
    }

    self.counter = try self.scroller.add(.{
        .name = "filter.count",
        .rect = .{ .width = 500, .height = 50 },
        .minimum = .{ .width = 420, .height = 50 },
        .layout = .{ .y = .shrinks, .x = .grows },
        .child_align = .{ .x = .centre, .y = .start },
        .pad = .{ .left = 25, .right = 25, .top = 60, .bottom = 60 },
        .style = .tinted,
        .type = .{ .label = .{
            .text = "0 forms",
        } },
    }, display);

    {
        var wrapper = try self.scroller.add(.{
            .name = "start.parsing.panel",
            .layout = .{ .x = .grows, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 20, .right = 20 },
            .minimum = .{ .width = 500, .height = 20 },
            .maximum = .{ .width = 1000 },
            .type = .{ .panel = .{
                .direction = .left_to_right,
            } },
        }, display);

        self.button_bar = try wrapper.add(.{
            .name = "start.parsing.panel",
            .background = .{ .image_name = "white rounded rect" },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .child_align = .{ .x = .centre },
            .pad = .{ .left = 10, .right = 30, .top = 20, .bottom = 20 },
            .minimum = .{ .width = 500, .height = 20 },
            .maximum = .{ .width = 1000 },
            .style = .faded,
            .type = .{ .panel = .{
                .direction = .left_to_right,
                .spacing = 6,
            } },
        }, display);

        self.edit_button = try self.button_bar.add(.{
            .name = "list.edit.button",
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = ICON_PAD, .right = ICON_PAD / 2, .top = ICON_PAD, .bottom = ICON_PAD },
            .child_align = .{ .x = .start, .y = .start },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{
                .button = .{
                    .icon = .{
                        .default_name = "edit-list-button",
                        .hover_name = "edit-list-button",
                        .pressed_name = "edit-list-button",
                        .size = .{ .width = 80, .height = 80 },
                    },
                    .text = "Edit",
                    .on_pressed = .{
                        .func = @ptrCast(&ListEditScreen.show),
                        .ptr = &self.app.list_edit,
                    },
                    .spacing = 15,
                },
            },
        }, display);

        self.delete_button = try self.button_bar.add(.{
            .name = "delete.button",
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = ICON_PAD / 2, .right = ICON_PAD, .top = ICON_PAD, .bottom = ICON_PAD },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{
                .button = .{
                    .icon = .{
                        .default_name = "delete list button",
                        .hover_name = "delete list button",
                        .pressed_name = "delete list button",
                        .size = .{ .width = 80, .height = 80 },
                    },
                    .text = "Delete",
                    .on_pressed = .{ .func = @ptrCast(&ListDeleteScreen.show), .ptr = self },
                    .spacing = 15,
                },
            },
        }, display);

        self.button_bar_spacer = try self.button_bar.add(.{
            .name = "button.spacer",
            .rect = .{ .width = 30, .height = 20 },
            .minimum = .{ .width = 30, .height = 20 },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .type = .{ .panel = .{} },
        }, display);

        self.start_button = try self.button_bar.add(.{
            .name = "start.button",
            .rect = .{ .x = 0, .y = 0, .width = 10, .height = 15 },
            .minimum = .{ .width = 10, .height = 15 },
            .pad = .{ .left = 30, .right = 30, .top = 30, .bottom = 30 },
            .child_align = .{ .x = .start, .y = .start },
            .layout = .{ .x = .shrinks, .y = .shrinks },
            .background = .{ .image_name = "white rounded rect" },
            .type = .{
                .button = .{
                    .icon = .{
                        .default_name = "parsing button",
                        .pressed_name = "parsing button",
                        .hover_name = "parsing button",
                        .size = .{ .width = 80, .height = 80 },
                    },
                    .button = .{
                        .hover_name = "white rounded rect",
                        .pressed_name = "white rounded rect",
                    },
                    .text = "Practice",
                    .on_pressed = .{ .func = @ptrCast(&show_parsing_card), .ptr = self },
                    .spacing = 20,
                },
            },
        }, display);
    }

    _ = try self.scroller.add(.{
        .name = "bottom.expander",
        .rect = .{ .width = 100, .height = 5 },
        .minimum = .{ .width = 100, .height = 5 },
        .layout = .{ .x = .shrinks, .y = .shrinks },
        .type = .{ .expander = .{ .weight = 0.7 } },
    }, display);

    _ = try display.add_spacer(self.scroller, 70);
}

pub fn go_back(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    event: *Event,
) Allocator.Error!void {

    // Go back to word info screen if thats where we were
    if (self.called_by == .word_info and self.lexeme != null) {
        info("ParsingSetupScreen({s} {s}) back", .{ @tagName(self.called_by), self.lexeme.?.word });
        try self.app.word_info.show(display, self.lexeme.?, event);
        return;
    }

    // Otherwise we came from the parsing menu screen.
    info("ParsingSetupScreen({s}) back", .{@tagName(self.called_by)});
    try self.app.parsing_menu.show(display, element, event);
}

pub fn handle_resize(self: *ParsingSetupScreen, display: *Display, _: *Entity) bool {
    var updated = false;

    if (ac.app_context.?.preference.size == .large or ac.app_context.?.preference.size == .extra_large) {
        if (self.help_line.visible != .hidden) {
            self.help_line.visible = .hidden;
            updated = true;
        }
    } else {
        if (self.help_line.visible == .hidden) {
            self.help_line.visible = .visible;
            updated = true;
        }
    }

    const size = engine.TextSize.normal.size();
    const height = size + (ICON_PAD * 2);
    if (self.edit_button.type.button.icon.size.width != size) {
        self.edit_button.type.button.icon.size.width = size;
        self.edit_button.type.button.icon.size.height = size;
        self.edit_button.minimum.width = height;
        self.edit_button.rect.height = height;
        self.edit_button.minimum.height = height;
        self.start_button.type.button.icon.size.width = size;
        self.start_button.type.button.icon.size.height = size;
        self.start_button.minimum.width = height;
        self.start_button.rect.height = height;
        self.start_button.minimum.height = height;
        self.delete_button.type.button.icon.size.width = size;
        self.delete_button.type.button.icon.size.height = size;
        self.delete_button.minimum.width = height;
        self.delete_button.rect.height = height;
        self.delete_button.minimum.height = height;
        updated = true;
    }

    const new_width = best_width(display);
    debug("parent_width={d} width={d}", .{ display.root.rect.width, new_width });
    if (self.panel.rect.width != new_width) {
        self.panel.rect.width = new_width;
        self.panel.minimum.width = new_width;
        self.panel.maximum.width = new_width;
        updated = true;
    }

    if (self.scroller.rect.height != display.root.rect.height - 340) {
        self.scroller.rect.height = display.root.rect.height - 340;
        self.scroller.minimum.height = self.scroller.rect.height;
        self.scroller.maximum.height = self.scroller.rect.height;
        updated = true;
    }

    return updated;
}

fn is_visible(visible: bool) engine.Entity.Visibility {
    if (visible) {
        return .visible;
    }
    return .hidden;
}

pub fn update_counter_text(self: *ParsingSetupScreen, display: *Display) error{OutOfMemory}!void {
    switch (ac.app_context.?.parsing_quiz.total_cards) {
        0 => try self.counter.setText(display, "No word forms."),
        1 => try self.counter.setText(display, "1 word form."),
        else => |count| try self.counter.setText(display, display.bucket.addFmt("{d} forms", .{count}) catch ""),
    }
}

pub fn update_option_panels(self: *ParsingSetupScreen) void {
    if (self.lexeme) |word| {
        if (word.pos.part_of_speech == .verb) {
            self.noun_panel.visible = .hidden;
            self.verb_panel.visible = .visible;
        } else {
            self.noun_panel.visible = .visible;
            self.verb_panel.visible = .hidden;
        }
        return;
    }
    if (self.list) |current_list| {
        if (current_list.has_noun_or_adjective()) {
            self.noun_panel.visible = .visible;
        } else {
            self.noun_panel.visible = .hidden;
        }
        if (current_list.has_verb()) {
            self.verb_panel.visible = .visible;
        } else {
            self.verb_panel.visible = .hidden;
        }
    }
    if (self.verb_panel.visible == .visible and self.noun_panel.visible == .visible) {
        self.noun_verb_spacer.visible = .visible;
    } else {
        self.noun_verb_spacer.visible = .hidden;
    }
}

fn refresh_menu(self: *ParsingSetupScreen, display: *Display) !void {
    if (ac.app_context.?.preference.present_future == false and
        ac.app_context.?.preference.imperfect == false and
        ac.app_context.?.preference.aorist == false and
        ac.app_context.?.preference.perfect_pluperfect == false)
    {
        ac.app_context.?.preference.present_future = true;
        self.checkboxes.present_future.type.checkbox.checked = true;
    }
    if (ac.app_context.?.preference.indicative == false and
        ac.app_context.?.preference.participle == false and
        ac.app_context.?.preference.subjunctive == false and
        ac.app_context.?.preference.imperative == false and
        ac.app_context.?.preference.infinitive == false)
    {
        ac.app_context.?.preference.indicative = true;
        self.checkboxes.indicative.type.checkbox.checked = true;
    }
    if (ac.app_context.?.preference.nominative_accusative == false and
        ac.app_context.?.preference.genitive_dative == false)
    {
        ac.app_context.?.preference.nominative_accusative = true;
        self.checkboxes.nominative_accusative.type.checkbox.checked = true;
    }

    if (self.lexeme) |current_lexeme| {
        try ac.app_context.?.parsing_quiz.setup_with_lexeme(current_lexeme);
    } else if (self.list) |current_list| {
        try ac.app_context.?.parsing_quiz.setup_with_word_set(current_list);
    } else {
        err("Cant refresh menus without lexeme specified.", .{});
    }
    self.update_option_panels();
    try self.update_counter_text(display);
}

pub fn change_nominative_accusative_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        if (ac.app_context.?.preference.nominative_accusative != element.type.checkbox.checked) {
            ac.app_context.?.preference.nominative_accusative = element.type.checkbox.checked;
            try self.refresh_menu(display);
        }
    }
}

pub fn change_third_declension_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        if (ac.app_context.?.preference.third_declension != element.type.checkbox.checked) {
            ac.app_context.?.preference.third_declension = element.type.checkbox.checked;
            try self.refresh_menu(display);
        }
    }
}

pub fn change_genitive_dative_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.genitive_dative = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_present_future_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.present_future = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_aorist_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.aorist = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_imperfect_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.imperfect = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_perfect_pluperfect_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.perfect_pluperfect = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_middle_passive_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.middle_passive = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_mi_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.mi = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_indicative_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.indicative = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_participles_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.participle = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_infinitive_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.infinitive = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_subjunctive_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.subjunctive = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
}

pub fn change_imperative_preference(
    self: *ParsingSetupScreen,
    display: *Display,
    element: *Entity,
    _: *Event,
) std.mem.Allocator.Error!void {
    if (element.type == .checkbox) {
        ac.app_context.?.preference.imperative = element.type.checkbox.checked;
    }
    try self.refresh_menu(display);
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
const Allocator = std.mem.Allocator;

const engine = @import("engine");
const debug = engine.log.debug;
const info = engine.log.info;
const err = engine.log.err;
const Display = engine.Display;
const Entity = engine.Entity;
const Event = engine.Event;

const praxis = @import("praxis");
const Lexeme = praxis.Lexeme;

const ac = @import("App.zig");
const AppContext = ac.AppContext;
const ParsingMenuScreen = @import("screen_parsing_menu.zig");
const ParsingCardScreen = @import("ParsingCardScreen.zig");
const ListEditScreen = @import("screen_list_edit.zig");
const ListDeleteScreen = @import("screen_list_delete.zig");
const show_parsing_menu = ParsingMenuScreen.show;
const show_parsing_card = ParsingCardScreen.show;
const show_list_editor = ListEditScreen.show;
const best_width = @import("SearchScreen.zig").best_width;
const Lists = @import("lists.zig");
const WordSet = Lists.WordSet;
