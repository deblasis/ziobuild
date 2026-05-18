const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "overlay_test" });

    _ = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .zon_dep = "dummy_dep" },
        },
    });

    // Apply a file overlay (no git needed).
    ctx.overlay("dummy_dep", .{
        .dir = "overlays/dummy_dep",
        .when = zb.Expr.literal(true),
    });

    ctx.help();
}
