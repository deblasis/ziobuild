const std = @import("std");

pub const Glyph = struct { codepoint: u32, width: u16, height: u16 };

pub fn rasterize(codepoint: u32) Glyph {
    return .{ .codepoint = codepoint, .width = 8, .height = 16 };
}

test "rasterize returns valid glyph" {
    const g = rasterize('A');
    try std.testing.expectEqual(@as(u32, 'A'), g.codepoint);
    try std.testing.expect(g.width > 0);
}
