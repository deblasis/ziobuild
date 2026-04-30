const std = @import("std");

pub fn main() !void {
    var buf: [64]u8 = undefined;
    const ls = std.debug.lockStderr(&buf);
    defer std.debug.unlockStderr();
    const w = &ls.file_writer.interface;
    try w.writeAll("smoke\n");
    try w.flush();
}

test "smoke arithmetic" {
    try std.testing.expectEqual(@as(u32, 4), 2 + 2);
}
