const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "noex" });
    _ = ctx.app(.{ .root = "src/main.zig" });
    _ = ctx.tests(.{ .root = "src/main.zig" });
    // Call examples() even though the directory doesn't exist.
    // Must return an empty slice, not panic.
    const exes = ctx.examples("examples/*/main.zig");
    _ = exes;
    ctx.help();
}
