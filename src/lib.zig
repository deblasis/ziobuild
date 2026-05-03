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
    /// Imports to add to the library's root module.
    imports: []const context_mod.Dep = &.{},
    /// Static or dynamic. Defaults to static.
    linkage: std.builtin.LinkMode = .static,
    /// Override the Context default target.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default optimize.
    optimize: ?std.builtin.OptimizeMode = null,
    /// Install. Defaults to true.
    install: bool = true,
};

/// Build a library.
pub fn lib(ctx: context_mod.Context, options: Options) *std.Build.Step.Compile {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;
    const name = options.name orelse ctx.name;

    const mod = ctx.b.createModule(.{
        .root_source_file = ctx.b.path(options.root),
        .target = target,
        .optimize = optimize,
    });
    ctx.resolveDeps(mod, options.imports);

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
