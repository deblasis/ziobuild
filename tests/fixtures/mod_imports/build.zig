const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "mod_imports" });

    _ = ctx.module("lib_a", .{ .root = "src/lib_a.zig" });
    _ = ctx.module("lib_b", .{
        .root = "src/lib_b.zig",
        .mod_imports = &.{"lib_a"},
    });

    // App uses mod_imports shorthand instead of Dep.mod
    _ = ctx.app(.{
        .root = "src/main.zig",
        .mod_imports = &.{ "lib_a", "lib_b" },
    });

    _ = ctx.testModules(.{});

    ctx.help();
}
