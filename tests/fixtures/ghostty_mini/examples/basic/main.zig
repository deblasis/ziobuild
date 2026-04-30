const std = @import("std");

pub fn main() !void {
    std.debug.print("ghostty-mini basic example\n", .{});
}

test "basic example compiles" {
    try std.testing.expect(true);
}
