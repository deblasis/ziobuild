const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "multi_exe" });

    // Build option
    const emit_tool = zb.boolOption(b, "emit-tool", true, "Also build the tool executable");

    // Main app with default "run" step
    _ = ctx.app(.{ .root = "src/main.zig" });

    // Secondary exe with custom step name — no collision with "run"
    if (emit_tool) {
        _ = ctx.app(.{
            .name = "multi_exe_tool",
            .root = "src/tool.zig",
            .step_name = "run-tool",
            .step_description = "Run the tool",
        });
    }

    _ = ctx.tests(.{ .root = "src/main.zig" });
    ctx.help();
}
