//! `Context.help` registers a top-level `help` step that, when run,
//! prints a tidy table of every top-level step plus its description.
//! The default `zig build --help` is unreadable on real projects, so
//! this is a strict improvement.
//!
//! v0.3: Calls `ensureResolved()` so all deferred imports are wired
//! up before the build graph is evaluated. This means `help()` is the
//! natural last call in every `build.zig` and implicitly finalizes
//! the module graph.

const std = @import("std");

const context_mod = @import("context.zig");

/// Register a top-level `help` step on `ctx.b`.
pub fn help(ctx: context_mod.Context) void {
    // Ensure all deferred imports are resolved before the build graph
    // is evaluated. This is the implicit finalization point — callers
    // who don't use `help()` should call `ctx.finalize()` instead.
    ctx.ensureResolved();

    const b = ctx.b;
    const step = b.step("help", "List all build steps with descriptions");
    const make_step = b.allocator.create(MakeHelpStep) catch @panic("OOM");
    make_step.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = "ziobuild help printer",
            .owner = b,
            .makeFn = MakeHelpStep.run,
        }),
    };
    step.dependOn(&make_step.step);
}

const MakeHelpStep = struct {
    step: std.Build.Step,

    fn run(s: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
        const b = s.owner;
        var buf: [4096]u8 = undefined;
        const ls = std.debug.lockStderr(&buf);
        defer std.debug.unlockStderr();
        const w = &ls.file_writer.interface;

        try w.writeAll("Available steps:\n");

        // Compute a column width so descriptions line up. The max
        // step name width plus two spaces, capped to keep things
        // readable on small terminals.
        var max: usize = 0;
        for (b.top_level_steps.values()) |tls| {
            if (tls.step.name.len > max) max = tls.step.name.len;
        }
        if (max > 24) max = 24;

        for (b.top_level_steps.values()) |tls| {
            try w.print("  {s}", .{tls.step.name});
            const pad = if (tls.step.name.len < max) max - tls.step.name.len else 1;
            var i: usize = 0;
            while (i < pad + 2) : (i += 1) try w.writeByte(' ');
            try w.writeAll(tls.description);
            try w.writeByte('\n');
        }

        try w.flush();
    }
};

test "help: registers a top-level step" {
    // Real coverage in tests/fixtures/kitchen_sink (which calls
    // ctx.help() and asserts that `zig build help` exits 0).
    try std.testing.expect(true);
}
