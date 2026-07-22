const std = @import("std");

pub fn main() !void {
    // Zig 0.16 removed `std.time.Timer`; the monotonic clock is now read
    // through an Io instance. This bench only needs a clock read, no
    // allocation and no async, so the hardcoded single threaded instance
    // is enough.
    const io = std.Io.Threaded.global_single_threaded.io();
    const start = std.Io.Clock.awake.now(io);
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        _ = @import("../src/terminal/main.zig").parse("benchmark input");
    }
    const elapsed: u64 = @intCast(@max(0, start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds));
    std.debug.print("terminal parse: {} ops in {}ns ({d:.1} ns/op)\n", .{
        i,
        elapsed,
        @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(i)),
    });
}
