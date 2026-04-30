//! Simple DNS resolver stub (mirrors ghostty's dependency pattern).
pub fn resolve(hostname: []const u8) !u32 {
    _ = hostname;
    return 0x7F000001;
}

test "resolve returns localhost" {
    try @import("std").testing.expectEqual(@as(u32, 0x7F000001), try resolve("localhost"));
}
