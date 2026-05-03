//! Typed build option helpers that wrap `b.option()` and provide
//! defaults. These are top-level namespace functions (not Context
//! methods) because they're typically called before or during Context
//! initialization.

const std = @import("std");

/// Declare a boolean build option with a default.
pub fn boolOption(
    b: *std.Build,
    name: []const u8,
    default: bool,
    description: []const u8,
) bool {
    return b.option(bool, name, description) orelse default;
}

/// Declare a string build option with a default.
pub fn stringOption(
    b: *std.Build,
    name: []const u8,
    default: ?[]const u8,
    description: []const u8,
) ?[]const u8 {
    return b.option([]const u8, name, description) orelse default;
}

/// Declare an enum build option with a default.
/// The enum type must be passed explicitly.
pub fn enumOption(
    b: *std.Build,
    comptime Enum: type,
    name: []const u8,
    default: Enum,
    description: []const u8,
) Enum {
    return b.option(Enum, name, description) orelse default;
}

/// Declare an integer build option with a default.
pub fn intOption(
    b: *std.Build,
    comptime Int: type,
    name: []const u8,
    default: Int,
    description: []const u8,
) Int {
    return b.option(Int, name, description) orelse default;
}

test "options helpers compile" {
    try std.testing.expect(true);
}
