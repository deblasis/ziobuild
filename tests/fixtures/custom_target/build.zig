const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "ct" });
    const app = ctx.app(.{ .root = "src/main.zig" });
    _ = ctx.tests(.{ .root = "src/main.zig" });
    _ = ctx.releases(.{
        .of = app,
        .custom_targets = &.{
            .{ .name = "freestanding-x86_64", .query = .{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
            } },
        },
    });
    ctx.help();
}
