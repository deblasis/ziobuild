const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        _ = @import("../src/terminal/main.zig").parse("benchmark input");
    }
    const elapsed = timer.read();
    std.debug.print("terminal parse: {} ops in {}ns ({d:.1} ns/op)\n", .{
        i,
        elapsed,
        @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(i)),
    });
}
