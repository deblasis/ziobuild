const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "modules_reverse" });

    // Declare in REVERSE dependency order to test deferred resolution.
    // lib_b depends on lib_a, but we declare lib_b FIRST.
    _ = ctx.module("lib_b", .{
        .root = "src/lib_b.zig",
        .imports = &.{
            .{ .mod = "lib_a" },
        },
    });
    _ = ctx.module("lib_a", .{ .root = "src/lib_a.zig" });

    // App references both
    const app = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .mod = "lib_a" },
            .{ .mod = "lib_b" },
        },
    });

    _ = ctx.testModules(.{});

    _ = ctx.releases(.{
        .of = app,
        .targets = &.{.linux_x64},
    });

    ctx.help();
}
