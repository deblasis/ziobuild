const std = @import("std");

pub fn main() !void {
    std.debug.print("comparison fixture ok\n", .{});
}

test "smoke" {
    try std.testing.expect(true);
}
