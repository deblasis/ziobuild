//! `Context` is the entry point. It bundles a `*std.Build`, a default
//! resolved target, a default optimize mode, and the project name.
//! Every helper (`app`, `lib`, `tests`, `examples`, `releases`,
//! `help`) hangs off it.
//!
//! The Context is small and copyable. It does not own anything that
//! needs explicit teardown.

const std = @import("std");

const target_mod = @import("target.zig");
const deps_mod = @import("deps.zig");
const app_mod = @import("app.zig");
const lib_mod = @import("lib.zig");
const tests_mod = @import("tests.zig");
const examples_mod = @import("examples_glob.zig");
const releases_mod = @import("releases.zig");
const help_mod = @import("help.zig");

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

    pub const app = app_mod.app;
    pub const lib = lib_mod.lib;
    pub const tests = tests_mod.tests;
    pub const examples = examples_mod.examples;
    pub const releases = releases_mod.releases;
    pub const help = help_mod.help;
};

/// Build a `Context`. Resolves target and optimize defaults from the
/// standard `-Dtarget` / `-Doptimize` flags if the caller did not
/// supply them.
pub fn init(b: *std.Build, options: InitOptions) Context {
    return .{
        .b = b,
        .name = options.name,
        .target = options.target orelse b.standardTargetOptions(.{}),
        .optimize = options.optimize orelse b.standardOptimizeOption(.{}),
    };
}

/// Internal: build a module with deps resolved. Shared by `app`,
/// `lib`, and `tests`.
pub fn buildModule(
    ctx: Context,
    root: []const u8,
    dep_names: []const []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = ctx.b.createModule(.{
        .root_source_file = ctx.b.path(root),
        .target = target,
        .optimize = optimize,
    });
    if (dep_names.len != 0) {
        deps_mod.addDeps(ctx.b, mod, dep_names, target, optimize);
    }
    return mod;
}

test {
    _ = target_mod;
    _ = deps_mod;
}
