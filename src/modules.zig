//! `Context.testModules` creates a test compile for every module in
//! the registry and aggregates them under a single step.
//!
//! v0.3: Calls `ensureResolved()` before iterating so all deferred
//! imports are wired up before tests run.

const std = @import("std");

const context_mod = @import("context.zig");

pub const Options = struct {
    /// Top-level step name. Defaults to `"test"`.
    step_name: []const u8 = "test",
    /// Step description.
    step_description: []const u8 = "Run all module tests",
};

/// Create one `addTest` per registered module and aggregate under
/// a single top-level step. Returns the slice of test compiles.
pub fn testModules(
    ctx: context_mod.Context,
    options: Options,
) []const *std.Build.Step.Compile {
    const b = ctx.b;
    const arena = b.allocator;

    // Resolve all deferred imports before touching the module graph.
    ctx.ensureResolved();

    if (ctx.modules.count() == 0) return &.{};

    const aggregate = b.step(options.step_name, options.step_description);
    const out = arena.alloc(*std.Build.Step.Compile, ctx.modules.count()) catch @panic("OOM");

    for (ctx.modules.keys(), ctx.modules.values(), 0..) |name, mod, i| {
        const test_exe = b.addTest(.{
            .name = b.fmt("test-{s}", .{name}),
            .root_module = mod,
        });
        const run = b.addRunArtifact(test_exe);
        aggregate.dependOn(&run.step);
        out[i] = test_exe;
    }
    return out;
}

test "testModules options struct compiles" {
    const _opts: Options = .{};
    _ = _opts;
    try std.testing.expect(true);
}
