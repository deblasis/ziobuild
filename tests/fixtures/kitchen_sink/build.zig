const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "kitchen" });
    const app = ctx.app(.{ .root = "src/main.zig" });
    _ = ctx.lib(.{ .name = "kitchen_lib", .root = "src/lib.zig" });
    _ = ctx.tests(.{ .root = "src/lib.zig" });
    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{.linux_x64},
    });
    ctx.help();
}
