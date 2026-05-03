//! Module A — standalone, no imports.
pub const value: u32 = 42;

test "lib_a: value is 42" {
    try @import("std").testing.expectEqual(@as(u32, 42), value);
}
