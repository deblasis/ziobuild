const std = @import("std");

pub fn main() !void {
    std.debug.print("no examples ok\n", .{});
}

test "smoke" {
    try std.testing.expect(true);
}
