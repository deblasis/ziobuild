const std = @import("std");

pub fn double(x: u32) u32 {
    return x * 2;
}

test "double zero" {
    try std.testing.expectEqual(@as(u32, 0), double(0));
}

test "double seven" {
    try std.testing.expectEqual(@as(u32, 14), double(7));
}
