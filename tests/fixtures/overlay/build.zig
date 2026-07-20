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

    // Apply a file overlay (no git needed), gated on the optimize mode
    // so the test suite can drive both branches from the command line:
    // a plain `zig build` overlays, `zig build -Doptimize=ReleaseFast`
    // does not.
    ctx.overlay("dummy_dep", .{
        .dir = "overlays/dummy_dep",
        .when = zb.Expr.optimizeMode(.Debug),
    });

    ctx.help();
}
