//! `Context.module` registers a named module in the Context's internal
//! registry. Other helpers (`app`, `lib`, `tests`, `releases`) can
//! then reference it by name via `Dep.mod` or `mod_imports`.
//!
//! Returns the `*Module` so callers can pass it to `Dep.direct` if
//! they prefer explicit wiring.
//!
//! v0.3: Imports are deferred. The module is registered immediately
//! (so it's visible to later `module()` calls), but its imports are
//! resolved lazily by `ensureResolved()`. This removes ordering
//! constraints — you can reference a module before it's declared.

const std = @import("std");

const context_mod = @import("context.zig");

pub const Options = struct {
    /// Path to the root source file relative to the build root.
    root: []const u8,
    /// Imports for this module. Can reference other registered modules
    /// by name via `.mod`, ZON deps, or direct modules.
    imports: []const context_mod.Dep = &.{},
    /// Shorthand: each string becomes an import of the module with
    /// that name from the registry. Equivalent to adding
    /// `.{ .mod = name }` for each entry.
    mod_imports: []const []const u8 = &.{},
    /// If true, import ALL registered modules by their registry name.
    /// The module itself is excluded (no self-import).
    import_all: bool = false,
    /// Override the Context default target.
    target: ?std.Build.ResolvedTarget = null,
    /// Override the Context default optimize.
    optimize: ?std.builtin.OptimizeMode = null,
    /// Link libc into this module. Needed by any module that calls into
    /// the C library, for example std.c.dlopen. Leave null to inherit
    /// Zig's default, which links libc on some targets (macOS) and not
    /// others (Linux), which is a common cross-platform build surprise.
    link_libc: ?bool = null,
};

/// Register a named module. Returns the `*Module`.
/// Panics if a module with the same name was already registered.
/// Imports are deferred — they will be resolved by `ensureResolved()`.
pub fn module(ctx: context_mod.Context, name: []const u8, options: Options) *std.Build.Module {
    const target = options.target orelse ctx.target;
    const optimize = options.optimize orelse ctx.optimize;

    const mod = ctx.b.createModule(.{
        .root_source_file = ctx.b.path(options.root),
        .target = target,
        .optimize = optimize,
        .link_libc = options.link_libc,
    });

    // Register immediately so the module is visible for ordering-
    // independent resolution.
    const gop = ctx.modules.getOrPut(ctx.b.allocator, name) catch @panic("OOM");
    if (gop.found_existing) {
        std.debug.panic(
            "ziobuild: module '{s}' is already registered. Use a unique name for each module.",
            .{name},
        );
    }
    gop.value_ptr.* = mod;

    // Defer import resolution.
    const has_imports = options.imports.len > 0 or options.mod_imports.len > 0 or options.import_all;
    if (has_imports) {
        ctx.addPending(.{
            .consumer = mod,
            .deps = options.imports,
            .mod_imports = options.mod_imports,
            .import_all = options.import_all,
            .self_module = mod,
        });
    }

    return mod;
}

test "module options struct compiles" {
    const _opts: Options = .{ .root = "src/root.zig" };
    _ = _opts;
    try std.testing.expect(true);
}
