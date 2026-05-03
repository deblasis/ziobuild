//! `Context` is the entry point. It bundles a `*std.Build`, a default
//! resolved target, a default optimize mode, the project name, and
//! an internal module registry. Every helper (`app`, `lib`, `tests`,
//! `examples`, `releases`, `help`, `module`, `testModules`) hangs off
//! it.
//!
//! The Context is small and copyable. It does not own anything that
//! needs explicit teardown — the module registry is heap-allocated
//! via the build allocator (an arena).

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
///   - `.module_registry` — resolved by name from the Context's
///     internal module registry (registered via `ctx.module()`).
///   - `.zon_dep` — resolved by name from `build.zig.zon` via
///     `b.dependency()`.
///   - `.direct` — a pre-built `*Module` with an explicit import name.
pub const Dep = union(enum) {
    module_registry: []const u8,
    zon_dep: []const u8,
    direct: struct { name: []const u8, module: *std.Build.Module },
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
    /// Resolve a slice of Deps into imports on a module.
    pub const resolveDeps = resolveDepsFn;
};

/// Build a `Context`. Resolves target and optimize defaults from the
/// standard `-Dtarget` / `-Doptimize` flags if the caller did not
/// supply them.
pub fn init(b: *std.Build, options: InitOptions) Context {
    const modules = b.allocator.create(std.StringArrayHashMapUnmanaged(*std.Build.Module)) catch @panic("OOM");
    modules.* = .empty;
    return .{
        .b = b,
        .name = options.name,
        .target = options.target orelse b.standardTargetOptions(.{}),
        .optimize = options.optimize orelse b.standardOptimizeOption(.{}),
        .modules = modules,
    };
}

/// Resolve a slice of `Dep`s into actual imports on `consumer`.
pub fn resolveDepsFn(
    ctx: Context,
    consumer: *std.Build.Module,
    deps: []const Dep,
) void {
    for (deps) |dep| {
        switch (dep) {
            .module_registry => |name| {
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
