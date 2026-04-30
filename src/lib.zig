//! `Context.lib` builds a library and (by default) installs it.
//! Returns the underlying `*std.Build.Step.Compile` for raw access.

const std = @import("std");

const context_mod = @import("context.zig");

/// Options for `Context.lib`.
pub const Options = struct {
    /// Library name. Defaults to `ctx.name`.
    name: ?[]const u8 = null,
    /// Path to the root file relative to the build root.
    root: []const u8,
    /// Dep names declared in `build.zig.zon`.
    deps: []const []const u8 = &.{},
    /// Static or dynamic. Defaults to static.
    linkage: std.builtin.LinkMode = .static,
    /// Override the Context default.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default.
    optimize: ?std.builtin.OptimizeMode = null,
    /// Install. Defaults to true.
    install: bool = true,
};

/// Build a library.
pub fn lib(ctx: context_mod.Context, options: Options) *std.Build.Step.Compile {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;
    const name = options.name orelse ctx.name;

    const mod = context_mod.buildModule(ctx, options.root, options.deps, target, optimize);
    const compile = ctx.b.addLibrary(.{
        .name = name,
        .root_module = mod,
        .linkage = options.linkage,
    });
    if (options.install) ctx.b.installArtifact(compile);
    return compile;
}

test "lib options struct compiles" {
    const _opts: Options = .{ .root = "src/root.zig" };
    _ = _opts;
    try std.testing.expect(true);
}
