const std = @import("std");

pub fn main() !void {
    std.debug.print("custom target ok\n", .{});
}

test "smoke" {
    try std.testing.expect(true);
}
