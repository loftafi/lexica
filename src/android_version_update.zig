//! Used by `build.zig` to bump the android build version
//! using the build number in `build.txt`

/// Use to update `AndroidManifest.xml`
pub fn update_android_metadata(
    manifest: []const u8,
    gradle: []const u8,
    strings: []const u8,
    app_name: []const u8,
    app_version: []const u8,
    build_number: []const u8,
    allocator: std.mem.Allocator,
) !void {
    var buff: [100]u8 = undefined;
    try update_android_strings_variable(strings, "app_name", app_name, allocator);
    try update_android_manifest_variable(manifest, "versionName", app_version, allocator);
    try update_android_manifest_variable(manifest, "versionCode", build_number, allocator);
    try update_android_gradle_variable(gradle, "versionName", try std.fmt.bufPrint(&buff, "\"{s}\"", .{app_version}), allocator);
    try update_android_gradle_variable(gradle, "versionCode", build_number, allocator);
}

pub fn update_android_manifest_variable(
    filename: []const u8,
    comptime key: []const u8,
    value: []const u8,
    allocator: std.mem.Allocator,
) !void {
    const manifest_variable_start = "android:" ++ key ++ "=\"";
    const manifest_variable_end = "\"";

    if (std.fs.cwd().readFileAlloc(allocator, filename, 999999999)) |data| {
        defer allocator.free(data);
        const new_data = try replace_variable(data, manifest_variable_start, manifest_variable_end, value, allocator);
        defer allocator.free(new_data);
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        _ = try file.write(new_data);
        std.log.info("Updated android manifest variable {s} = \"{s}\"", .{ key, value });
    } else |e| {
        std.log.warn("Error reading android manifest file. {any}", .{e});
    }
}

pub fn update_android_strings_variable(
    filename: []const u8,
    comptime key: []const u8,
    value: []const u8,
    allocator: std.mem.Allocator,
) !void {
    const manifest_variable_start = "<string name=\"" ++ key ++ "\">";
    const manifest_variable_end = "</string>";
    if (std.fs.cwd().readFileAlloc(allocator, filename, 999999999)) |data| {
        defer allocator.free(data);
        const new_data = try replace_variable(data, manifest_variable_start, manifest_variable_end, value, allocator);
        defer allocator.free(new_data);
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        _ = try file.write(new_data);
        std.log.info("Updated android manifest variable {s} = \"{s}\"", .{ key, value });
    } else |e| {
        std.log.warn("Error reading android manifest file. {any}", .{e});
    }
}

pub fn update_android_gradle_variable(
    filename: []const u8,
    comptime key: []const u8,
    value: []const u8,
    allocator: std.mem.Allocator,
) !void {
    const gradle_variable_start = key ++ " ";
    const gradle_variable_end = "\n";
    if (std.fs.cwd().readFileAlloc(allocator, filename, 999999999)) |data| {
        defer allocator.free(data);
        const new_data = try replace_variable(data, gradle_variable_start, gradle_variable_end, value, allocator);
        defer allocator.free(new_data);
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        _ = try file.write(new_data);
        std.log.info("Updated android gradle variable {s} = \"{s}\"", .{ key, value });
    } else |e| {
        std.log.warn("Error reading android gradle file. {any}", .{e});
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
            try out.writer().print("{s}", .{value});
        }
    }
    return allocator.dupe(u8, out.items);
}

const std = @import("std");

test "manifest_version_update" {
    {
        const sample =
            \\<manifest xmlns:android="http://schemas.android.com/apk/res/android"
            \\android:versionCode="1"
            \\android:versionName="1.0"
            \\xmlns:tools="http://schemas.android.com/tools"
            \\android:installLocation="auto">
        ;
        const updated =
            \\<manifest xmlns:android="http://schemas.android.com/apk/res/android"
            \\android:versionCode="333"
            \\android:versionName="3.3.3"
            \\xmlns:tools="http://schemas.android.com/tools"
            \\android:installLocation="auto">
        ;

        const result = try replace_variable(sample, "android:versionName=\"", "\"", "3.3.3", std.testing.allocator);
        defer std.testing.allocator.free(result);
        const result2 = try replace_variable(result, "android:versionCode=\"", "\"\n", "333", std.testing.allocator);
        defer std.testing.allocator.free(result2);
        try std.testing.expectEqualStrings(updated, result2);
    }
    try update_android_metadata(
        "android/app/src/main/AndroidManifest.xml",
        "android/app/build.gradle",
        "android/app/src/main/res/values/strings.xml",
        "test App",
        "3.3.3",
        "333",
        std.testing.allocator,
    );
}

test "gradle_version_update" {
    {
        const sample =
            \\defaultConfig {
            \\  minSdkVersion 21
            \\  targetSdkVersion 35
            \\  versionCode 33
            \\  versionName "1.0"
            \\  stuff 99
        ;
        const updated =
            \\defaultConfig {
            \\  minSdkVersion 21
            \\  targetSdkVersion 35
            \\  versionCode 22
            \\  versionName "2.2"
            \\  stuff 99
        ;

        const result = try replace_variable(sample, "versionName ", "\n", "\"2.2\"", std.testing.allocator);
        defer std.testing.allocator.free(result);
        const result2 = try replace_variable(result, "versionCode ", "\n", "22", std.testing.allocator);
        defer std.testing.allocator.free(result2);
        try std.testing.expectEqualStrings(updated, result2);
    }
    try update_android_metadata(
        "android/app/src/main/AndroidManifest.xml",
        "android/app/build.gradle",
        "android/app/src/main/res/values/strings.xml",
        "test App",
        "2.2",
        "22",
        std.testing.allocator,
    );
}
