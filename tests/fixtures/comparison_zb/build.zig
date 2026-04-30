const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "comparison-zb" });
    _ = ctx.app(.{
        .root = "src/main.zig",
    });
    _ = ctx.tests(.{
        .root = "src/main.zig",
    });
    ctx.help();
}
