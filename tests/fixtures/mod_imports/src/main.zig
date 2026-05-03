const std = @import("std");
const a = @import("lib_a");
const b = @import("lib_b");

pub fn main(init: std.process.Init) !void {
    _ = init;
    _ = a.value;
    _ = b.doubled;
}
