//! `Context.app` builds an executable, installs it (by default), and
//! registers a `run` step that depends on it. Returns the underlying
//! `*std.Build.Step.Compile` so callers can drop down to raw
//! `std.Build` whenever they want.

const std = @import("std");

const context_mod = @import("context.zig");

/// Options for `Context.app`.
pub const Options = struct {
    /// Executable name. Defaults to `ctx.name`.
    name: ?[]const u8 = null,
    /// Path to the entry-point file relative to the build root.
    root: []const u8,
    /// Dep names declared in `build.zig.zon`. Each is resolved and
    /// added as an import on the executable's root module.
    deps: []const []const u8 = &.{},
    /// Override the Context default.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default.
    optimize: ?std.builtin.OptimizeMode = null,
    /// Install the artifact under `zig-out/bin`. Defaults to true.
    install: bool = true,
    /// Register a top-level `run` step. Defaults to true.
    register_run: bool = true,
};

/// Build an executable.
pub fn app(ctx: context_mod.Context, options: Options) *std.Build.Step.Compile {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;
    const name = options.name orelse ctx.name;

    const mod = context_mod.buildModule(ctx, options.root, options.deps, target, optimize);
    const exe = ctx.b.addExecutable(.{
        .name = name,
        .root_module = mod,
    });
    if (options.install) ctx.b.installArtifact(exe);

    if (options.register_run) {
        const run = ctx.b.addRunArtifact(exe);
        if (ctx.b.args) |args| run.addArgs(args);
        const step = ctx.b.step("run", ctx.b.fmt("Run {s}", .{name}));
        step.dependOn(&run.step);
    }

    return exe;
}

test "app options struct compiles" {
    // Compile-only smoke test. Real coverage is in the smoke and
    // kitchen_sink integration fixtures, which actually invoke
    // `Context.app` and assert artifacts on disk.
    const _opts: Options = .{ .root = "src/main.zig" };
    _ = _opts;
    try std.testing.expect(true);
}
