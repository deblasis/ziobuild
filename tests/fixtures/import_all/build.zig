const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "import_all" });

    _ = ctx.module("lib_a", .{ .root = "src/lib_a.zig" });
    _ = ctx.module("lib_b", .{
        .root = "src/lib_b.zig",
        .mod_imports = &.{"lib_a"},
    });

    // The aggregator module imports ALL registered modules automatically.
    _ = ctx.module("aggregator", .{
        .root = "src/aggregator.zig",
        .import_all = true,
    });

    // App also uses import_all
    _ = ctx.app(.{
        .root = "src/main.zig",
        .import_all = true,
    });

    _ = ctx.testModules(.{});

    ctx.help();
}
