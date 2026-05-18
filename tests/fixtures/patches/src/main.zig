const std = @import("std");
const dummy = @import("dummy_dep");

pub fn main() !void {
    var buf: [256]u8 = undefined;
    const ls = std.debug.lockStderr(&buf);
    defer std.debug.unlockStderr();
    const w = &ls.file_writer.interface;
    try w.writeAll(dummy.greeting);
    try w.writeAll("\n");
    try w.flush();
}
