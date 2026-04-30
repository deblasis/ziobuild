const std = @import("std");

pub fn main() !void {
    std.debug.print("ghostty-mini daemon example\n", .{});
}

test "daemon example compiles" {
    try std.testing.expect(true);
}
