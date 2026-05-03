const std = @import("std");
const a = @import("lib_a");
const b = @import("lib_b");
const aggregator = @import("aggregator");

pub fn main(init: std.process.Init) !void {
    _ = init;
    _ = a.value;
    _ = b.doubled;
    _ = aggregator.sum;
}
