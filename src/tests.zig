//! `Context.tests` declares a test compile, wraps it with
//! `addRunArtifact`, and registers a top-level test step (default
//! name `test`) that depends on the run.

const std = @import("std");

const context_mod = @import("context.zig");

/// Options for `Context.tests`.
pub const Options = struct {
    /// Path to the test entry-point file relative to the build root.
    root: []const u8,
    /// Test binary name (cosmetic). Defaults to `test`.
    name: ?[]const u8 = null,
    /// Imports to add to the test module.
    imports: []const context_mod.Dep = &.{},
    /// Override the Context default target.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default optimize.
    optimize: ?std.builtin.OptimizeMode = null,
    /// Top-level step name. Defaults to `test`. Must be unique if
    /// you call `tests()` multiple times.
    step_name: ?[]const u8 = null,
    /// Description for the step. Defaults to "Run tests".
    step_description: []const u8 = "Run tests",
};

/// Build a test compile and register a top-level step.
pub fn tests(ctx: context_mod.Context, options: Options) *std.Build.Step.Compile {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;

    const mod = ctx.b.createModule(.{
        .root_source_file = ctx.b.path(options.root),
        .target = target,
        .optimize = optimize,
    });
    ctx.resolveDeps(mod, options.imports);

    const test_exe = ctx.b.addTest(.{
        .name = options.name orelse "test",
        .root_module = mod,
    });
    const run = ctx.b.addRunArtifact(test_exe);
    const step = ctx.b.step(options.step_name orelse "test", options.step_description);
    step.dependOn(&run.step);
    return test_exe;
}

test "tests options struct compiles" {
    const _opts: Options = .{ .root = "src/root.zig" };
    _ = _opts;
    try std.testing.expect(true);
}
