//! Public C API for the terminal library.
//! Mirrors ghostty's include/ghostty.h pattern.

const std = @import("std");
const config_mod = @import("config/root.zig");
const terminal = @import("terminal/main.zig");

pub fn init() void {}
pub fn deinit() void {}

pub fn processInput(input: []const u8) []const u8 {
    return terminal.parse(input);
}

test "lib api roundtrip" {
    init();
    defer deinit();
    const result = processInput("test");
    try std.testing.expect(result.len > 0);
}
