const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "modules" });

    // Register internal modules with cross-module imports
    _ = ctx.module("lib_a", .{ .root = "src/lib_a.zig" });
    _ = ctx.module("lib_b", .{
        .root = "src/lib_b.zig",
        .imports = &.{
            .{ .mod = "lib_a" },
        },
    });

    // Main app uses both modules
    const app = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .mod = "lib_a" },
            .{ .mod = "lib_b" },
        },
    });

    // Test all registered modules
    _ = ctx.testModules(.{});

    // Release matrix carries imports
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{.linux_x64},
    });

    ctx.help();
}
