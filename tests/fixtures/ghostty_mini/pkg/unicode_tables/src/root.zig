//! Unicode table lookups stub (mirrors ghostty's unicode data dependency).
pub fn width(codepoint: u32) u8 {
    if (codepoint < 0x80) return 1;
    if (codepoint < 0x800) return 2;
    return 3;
}

test "ASCII width is 1" {
    try @import("std").testing.expectEqual(@as(u8, 1), width('A'));
}
