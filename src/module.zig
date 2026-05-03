//! `Context.module` registers a named module in the Context's internal
//! registry. Other helpers (`app`, `lib`, `tests`, `releases`) can
//! then reference it by name via `Dep.module_registry`.
//!
//! Returns the `*Module` so callers can pass it to `Dep.direct` if
//! they prefer explicit wiring.

const std = @import("std");

const context_mod = @import("context.zig");

pub const Options = struct {
    /// Path to the root source file relative to the build root.
    root: []const u8,
    /// Imports for this module. Can reference other registered modules
    /// by name via `.module_registry`, ZON deps, or direct modules.
    imports: []const context_mod.Dep = &.{},
    /// Override the Context default target.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default optimize.
    optimize: ?std.builtin.OptimizeMode = null,
};

/// Register a named module. Returns the `*Module`.
/// Panics if a module with the same name was already registered.
pub fn module(ctx: context_mod.Context, name: []const u8, options: Options) *std.Build.Module {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;

    const mod = ctx.b.createModule(.{
        .root_source_file = ctx.b.path(options.root),
        .target = target,
        .optimize = optimize,
    });
    ctx.resolveDeps(mod, options.imports);

    const gop = ctx.modules.getOrPut(ctx.b.allocator, name) catch @panic("OOM");
    if (gop.found_existing) {
        std.debug.panic(
            "ziobuild: module '{s}' is already registered. Use a unique name for each module.",
            .{name},
        );
    }
    gop.value_ptr.* = mod;
    return mod;
}

test "module options struct compiles" {
    const _opts: Options = .{ .root = "src/root.zig" };
    _ = _opts;
    try std.testing.expect(true);
}
