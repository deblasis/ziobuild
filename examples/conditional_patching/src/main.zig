const std = @import("std");
const math = @import("math_lib");

pub fn main() !void {
    var buf: [256]u8 = undefined;
    const ls = std.debug.lockStderr(&buf);
    defer std.debug.unlockStderr();
    const w = &ls.file_writer.interface;

    try w.writeAll("math_lib version: ");
    try w.writeAll(math.version);
    try w.writeAll("\n");

    const result = math.add(2, 3);
    const buf2 = std.fmt.bufPrint(&buf, "{d}", .{result}) catch unreachable;
    try w.writeAll("2 + 3 = ");
    try w.writeAll(buf2);
    try w.writeAll("\n");

    try w.flush();
}
