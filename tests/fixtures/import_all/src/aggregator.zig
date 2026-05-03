// import_all gives us lib_a, lib_b, and aggregator.
// aggregator should NOT import itself (self-import skipped).
const a = @import("lib_a");
const b = @import("lib_b");

pub const sum: u32 = a.value + b.doubled;

test "aggregator: sum is 126" {
    try @import("std").testing.expectEqual(@as(u32, 126), sum);
}
