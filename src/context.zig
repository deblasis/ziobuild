//! `Context` is the entry point. It bundles a `*std.Build`, a default
//! resolved target, a default optimize mode, the project name, and
//! an internal module registry. Every helper (`app`, `lib`, `tests`,
//! `examples`, `releases`, `help`, `module`, `testModules`) hangs off
//! it.
//!
//! v0.3: Dependency resolution is **deferred**. Calls to `module()`,
//! `app()`, `tests()`, `lib()` store their import lists without
//! resolving them. Resolution happens lazily when any consumer needs
//! the full module graph (e.g. `testModules()`, `releases()`,
//! `help()`, or an explicit `finalize()`). This removes ordering
//! constraints — modules can be declared in any order and can
//! reference each other freely.

const std = @import("std");

const target_mod = @import("target.zig");
const deps_mod = @import("deps.zig");
const app_mod = @import("app.zig");
const lib_mod = @import("lib.zig");
const tests_mod = @import("tests.zig");
const examples_mod = @import("examples_glob.zig");
const releases_mod = @import("releases.zig");
const help_mod = @import("help.zig");
const module_mod = @import("module.zig");
const modules_mod = @import("modules.zig");

/// A single import that can be attached to a module. Three sources:
///
///   - `.mod` — resolved by name from the Context's internal module
///     registry (registered via `ctx.module()`).
///   - `.zon_dep` — resolved by name from `build.zig.zon` via
///     `b.dependency()`.
///   - `.direct` — a pre-built `*Module` with an explicit import name.
pub const Dep = union(enum) {
    mod: []const u8,
    zon_dep: []const u8,
    direct: struct { name: []const u8, module: *std.Build.Module },
};

/// A pending (deferred) import list that will be resolved later.
pub const PendingImports = struct {
    consumer: *std.Build.Module,
    /// Full Dep imports (zon_dep, direct, or named mod).
    deps: []const Dep = &.{},
    /// Shorthand: each string becomes an import of the module with
    /// that name from the registry.
    mod_imports: []const []const u8 = &.{},
    /// If true, import ALL registered modules by their registry name.
    import_all: bool = false,
    /// For `import_all` + `module()`: skip self-import by pointer.
    self_module: ?*std.Build.Module = null,
};

/// Options for `init`.
pub const InitOptions = struct {
    /// Project name. Used as the default executable name in `app` and
    /// the default release directory leaf in `releases`.
    name: []const u8,
    /// Optional pre-resolved target. If null, ziobuild calls
    /// `b.standardTargetOptions(.{})` once and reuses it.
    target: ?std.Build.ResolvedTarget = null,
    /// Optional pre-resolved optimize. If null, ziobuild calls
    /// `b.standardOptimizeOption(.{})` once and reuses it.
    optimize: ?std.builtin.OptimizeMode = null,
};

/// Bundle of build state passed to every helper.
pub const Context = struct {
    /// The user's `*std.Build`. Helpers all delegate here.
    b: *std.Build,
    /// Project name (defaults the exe name in `app` and the release
    /// dir leaf in `releases`).
    name: []const u8,
    /// Default resolved target for any artifact the caller does not
    /// override.
    target: std.Build.ResolvedTarget,
    /// Default optimize mode for any artifact the caller does not
    /// override.
    optimize: std.builtin.OptimizeMode,
    /// Internal module registry. Populated by `ctx.module()`.
    /// Heap-allocated so Context remains copyable.
    modules: *std.StringArrayHashMapUnmanaged(*std.Build.Module),
    /// Deferred import lists. Populated by `module()`, `app()`,
    /// `tests()`, `lib()`. Resolved by `ensureResolved()`.
    pending: *std.ArrayListUnmanaged(PendingImports),
    /// Index of the first unresolved pending entry. Allows incremental
    /// resolution so that calls to ensureResolved() before all
    /// registrations are complete don't skip later entries.
    resolved_up_to: *usize,

    /// Build an executable. See `app.zig` for options.
    pub const app = app_mod.app;
    /// Build a library. See `lib.zig` for options.
    pub const lib = lib_mod.lib;
    /// Declare a test step. See `tests.zig` for options.
    pub const tests = tests_mod.tests;
    /// Register one example per glob match. See `examples_glob.zig`.
    pub const examples = examples_mod.examples;
    /// Cross-compile release matrix. See `releases.zig` for options.
    pub const releases = releases_mod.releases;
    /// Print a tidy step listing. See `help.zig`.
    pub const help = help_mod.help;
    /// Register a named module. See `module.zig`.
    pub const module = module_mod.module;
    /// Test every registered module. See `modules.zig`.
    pub const testModules = modules_mod.testModules;

    /// Enqueue a pending import list for deferred resolution.
    pub fn addPending(ctx: Context, pending: PendingImports) void {
        ctx.pending.append(ctx.b.allocator, pending) catch @panic("OOM");
    }

    /// Ensure all deferred imports have been resolved. Incremental:
    /// each call processes only entries added since the last call.
    /// Called automatically by `help()`, `testModules()`, `releases()`,
    /// and `finalize()`.
    pub fn ensureResolved(ctx: Context) void {
        const start = ctx.resolved_up_to.*;
        const end = ctx.pending.items.len;
        if (start >= end) return;
        ctx.resolved_up_to.* = end;

        for (ctx.pending.items[start..end]) |p| {
            // 1. Resolve full Dep entries
            resolveDepsNow(ctx, p.consumer, p.deps);

            // 2. Resolve mod_imports shorthand
            for (p.mod_imports) |name| {
                const mod = ctx.modules.get(name) orelse {
                    std.debug.panic(
                        "ziobuild: module '{s}' not found in registry (via mod_imports). Registered modules: {s}",
                        .{ name, registeredModuleNames(ctx) },
                    );
                };
                p.consumer.addImport(name, mod);
            }

            // 3. Resolve import_all
            if (p.import_all) {
                for (ctx.modules.keys(), ctx.modules.values()) |name, mod| {
                    // Skip self-import (pointer comparison)
                    if (p.self_module != null and mod == p.self_module.?) continue;
                    p.consumer.addImport(name, mod);
                }
            }
        }
    }

    /// Explicit finalization. Resolves all deferred imports.
    /// Only needed if you don't call `help()` (which auto-resolves).
    pub fn finalize(ctx: Context) void {
        ctx.ensureResolved();
    }
};

/// Build a `Context`. Resolves target and optimize defaults from the
/// standard `-Dtarget` / `-Doptimize` flags if the caller did not
/// supply them.
pub fn init(b: *std.Build, options: InitOptions) Context {
    const modules = b.allocator.create(std.StringArrayHashMapUnmanaged(*std.Build.Module)) catch @panic("OOM");
    modules.* = .empty;

    const pending = b.allocator.create(std.ArrayListUnmanaged(PendingImports)) catch @panic("OOM");
    pending.* = .empty;

    const resolved_up_to = b.allocator.create(usize) catch @panic("OOM");
    resolved_up_to.* = 0;

    return .{
        .b = b,
        .name = options.name,
        .target = options.target orelse b.standardTargetOptions(.{}),
        .optimize = options.optimize orelse b.standardOptimizeOption(.{}),
        .modules = modules,
        .pending = pending,
        .resolved_up_to = resolved_up_to,
    };
}

/// Resolve a slice of Deps against the current registry state.
/// Used by `ensureResolved()` and `examplesWithImports()` after
/// the registry is finalized. Not part of the public API.
pub fn resolveDepsNow(
    ctx: Context,
    consumer: *std.Build.Module,
    deps: []const Dep,
) void {
    for (deps) |dep| {
        switch (dep) {
            .mod => |name| {
                const mod = ctx.modules.get(name) orelse {
                    std.debug.panic(
                        "ziobuild: module '{s}' not found in registry. Registered modules: {s}",
                        .{ name, registeredModuleNames(ctx) },
                    );
                };
                consumer.addImport(name, mod);
            },
            .zon_dep => |name| {
                deps_mod.resolveZonDep(
                    ctx.b,
                    consumer,
                    name,
                    consumer.resolved_target orelse ctx.target,
                    consumer.optimize orelse ctx.optimize,
                );
            },
            .direct => |d| {
                consumer.addImport(d.name, d.module);
            },
        }
    }
}

/// Comma-separated list of registered module names for diagnostics.
pub fn registeredModuleNames(ctx: Context) []const u8 {
    if (ctx.modules.count() == 0) return "(none)";
    var result: []const u8 = "";
    for (ctx.modules.keys(), 0..) |name, i| {
        if (i == 0) {
            result = ctx.b.fmt("'{s}'", .{name});
        } else {
            result = ctx.b.fmt("{s}, '{s}'", .{ result, name });
        }
    }
    return result;
}

test {
    _ = target_mod;
    _ = deps_mod;
    _ = module_mod;
    _ = modules_mod;
}
