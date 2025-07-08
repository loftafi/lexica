//! Use in `build.zig` to update the xcode project variables.

pub fn update_xcode_variables(
    filename: []const u8,
    app_name: []const u8,
    app_version: []const u8,
    app_id: []const u8,
    build_number: []const u8,
    allocator: std.mem.Allocator,
) !void {
    try update_xcode_variable(filename, "CURRENT_PROJECT_VERSION", build_number, allocator);
    try update_xcode_variable(filename, "INFOPLIST_KEY_CFBundleDisplayName", app_name, allocator);
    try update_xcode_variable(filename, "MARKETING_VERSION", app_version, allocator);
    try update_xcode_variable(filename, "PRODUCT_BUNDLE_IDENTIFIER", app_id, allocator);
}

/// Use to update the xcode `project.pbxproj`
pub fn update_xcode_variable(filename: []const u8, comptime key: []const u8, value: []const u8, allocator: std.mem.Allocator) !void {
    const variable_start = key ++ " = ";
    const variable_end = ";";

    if (std.fs.cwd().readFileAlloc(allocator, filename, 999999999)) |data| {
        defer allocator.free(data);
        const new_data = try replace_variable(data, variable_start, variable_end, value, allocator);
        defer allocator.free(new_data);
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        _ = try file.write(new_data);
        std.log.info("Updated xcode {s} = \"{s}\"", .{ key, value });
    } else |e| {
        std.log.warn("Error reading xcode variable. {any}", .{e});
    }
}

pub fn replace_variable(data: []const u8, comptime key_start: []const u8, comptime key_end: []const u8, value: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    var i = std.mem.tokenizeSequence(u8, data, key_start);
    var first = true;
    while (i.next()) |v| {
        var part = v;
        if (!first) {
            if (std.mem.indexOf(u8, v, key_end)) |x| {
                part = v[x..];
            }
        } else {
            first = false;
        }
        try out.appendSlice(part);
        if (i.peek() != null) {
            try out.appendSlice(key_start);
            if (std.mem.indexOf(u8, value, " ") != null) {
                try out.writer().print("\"{s}\"", .{value});
            } else {
                try out.writer().print("{s}", .{value});
            }
        }
    }
    return allocator.dupe(u8, out.items);
}

const std = @import("std");

test "basic_version_update" {
    {
        const sample = "this is a \n test CURRENT_PROJECT_VERSION = 123;\nbye";
        const updated = "this is a \n test CURRENT_PROJECT_VERSION = 999;\nbye";

        const result = try replace_variable(sample, "CURRENT_PROJECT_VERSION", "999", std.testing.allocator);
        defer std.testing.allocator.free(result);
        try std.testing.expectEqualStrings(updated, result);
    }

    {
        const sample = "this is a \n test CURRENT_PROJECT_VERSION = 123;\nbye\n\nCURRENT_PROJECT_VERSION = 332;\n\n";
        const updated = "this is a \n test CURRENT_PROJECT_VERSION = 999;\nbye\n\nCURRENT_PROJECT_VERSION = 999;\n\n";

        const result = try replace_variable(sample, "CURRENT_PROJECT_VERSION", "999", std.testing.allocator);
        defer std.testing.allocator.free(result);
        try std.testing.expectEqualStrings(updated, result);
    }

    try update_xcode_variables(
        "ios/Lexica.xcodeproj/project.pbxproj",
        "Test App",
        "9.2",
        "org.test.lexica",
        "900",
        std.testing.allocator,
    );
}
