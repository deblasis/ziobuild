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

    // Register a conditional patch. The expression is always-true
    // so the test reliably exercises the patch path.
    ctx.patch("dummy_dep", .{
        .file = "patches/dummy_dep/fix.patch",
        .when = zb.Expr.literal(true),
    });

    ctx.help();
}
