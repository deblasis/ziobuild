const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "patches_test" });

    _ = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .zon_dep = "dummy_dep" },
        },
    });

    // Register a conditional patch, gated on the optimize mode so the
    // test suite can drive both branches from the command line:
    // a plain `zig build` patches, `zig build -Doptimize=ReleaseFast`
    // does not.
    ctx.patch("dummy_dep", .{
        .file = "patches/dummy_dep/fix.patch",
        .when = zb.Expr.optimizeMode(.Debug),
    });

    ctx.help();
}
