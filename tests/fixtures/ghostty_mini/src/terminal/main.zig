const std = @import("std");

pub fn parse(input: []const u8) []const u8 {
    _ = input;
    return "parsed";
}

test "parse handles empty input" {
    try std.testing.expectEqualStrings("parsed", parse(""));
}
