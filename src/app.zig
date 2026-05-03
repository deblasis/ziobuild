//! `Context.app` builds an executable, installs it (by default), and
//! registers a run step. Returns the underlying `*Compile` so callers
//! can drop down to raw `std.Build` whenever they want.

const std = @import("std");

const context_mod = @import("context.zig");

/// Options for `Context.app`.
pub const Options = struct {
    /// Executable name. Defaults to `ctx.name`.
    name: ?[]const u8 = null,
    /// Path to the entry-point file relative to the build root.
    root: []const u8,
    /// Imports to add to the executable's root module.
    imports: []const context_mod.Dep = &.{},
    /// Override the Context default target.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default optimize.
    optimize: ?std.builtin.OptimizeMode = null,
    /// Install the artifact under `zig-out/bin`. Defaults to true.
    install: bool = true,
    /// Register a top-level run step. Defaults to true.
    register_run: bool = true,
    /// Custom run step name. Defaults to `"run"`. Only used if
    /// `register_run` is true. Must be unique across all app() calls.
    step_name: ?[]const u8 = null,
    /// Description for the run step. Defaults to `"Run <name>"`.
    step_description: ?[]const u8 = null,
};

/// Build an executable.
pub fn app(ctx: context_mod.Context, options: Options) *std.Build.Step.Compile {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;
    const name = options.name orelse ctx.name;

    const mod = ctx.b.createModule(.{
        .root_source_file = ctx.b.path(options.root),
        .target = target,
        .optimize = optimize,
    });
    ctx.resolveDeps(mod, options.imports);

    const exe = ctx.b.addExecutable(.{
        .name = name,
        .root_module = mod,
    });
    if (options.install) ctx.b.installArtifact(exe);

    if (options.register_run) {
        const run = ctx.b.addRunArtifact(exe);
        if (ctx.b.args) |args| run.addArgs(args);
        const sname = options.step_name orelse "run";
        const sdesc = options.step_description orelse ctx.b.fmt("Run {s}", .{name});
        const step = ctx.b.step(sname, sdesc);
        step.dependOn(&run.step);
    }

    return exe;
}

test "app options struct compiles" {
    const _opts: Options = .{ .root = "src/main.zig" };
    _ = _opts;
    try std.testing.expect(true);
}
