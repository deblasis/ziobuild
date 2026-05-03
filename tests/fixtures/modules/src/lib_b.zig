//! Module B — imports lib_a via module registry.
const a = @import("lib_a");
pub const doubled: u32 = a.value * 2;

test "lib_b: doubled is 84" {
    try @import("std").testing.expectEqual(@as(u32, 84), doubled);
}
