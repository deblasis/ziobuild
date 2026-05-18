const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "conditional_patching" });

    // Build the app, importing math_lib from build.zig.zon.
    _ = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .zon_dep = "math_lib" },
        },
    });

    // Apply a patch to math_lib when building with Zig >= 0.16.0.
    // The patch file lives in patches/math_lib/ and is a standard
    // unified diff that `git apply` can process.
    ctx.patch("math_lib", .{
        .file = "patches/math_lib/fix-zig-0.16.patch",
        .when = zb.Expr.zigVersion(.gte, "0.16.0"),
    });

    // You can compose expressions. For example, patch only on Linux:
    //
    // ctx.patch("math_lib", .{
    //     .file = "patches/math_lib/fix-linux.patch",
    //     .when = zb.Expr.zigVersion(.gte, "0.16.0")
    //         .andAlso(zb.Expr.targetOs(.linux), b.allocator),
    // });

    // You can also use expressions for arbitrary build logic:
    //
    // if (zb.Expr.zigVersion(.gte, "0.16.0").evaluate(b, ctx.target, ctx.optimize)) {
    //     // conditional build logic here
    // }

    ctx.help();
}
