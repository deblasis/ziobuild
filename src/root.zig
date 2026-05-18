//! ziobuild: declarative `build.zig` DSL.
//!
//! Replaces 80+ line build files with a dozen calls. The API is
//! layered: every helper that produces an artifact returns the
//! underlying `*std.Build.Step.Compile`, so callers can drop down to
//! raw `std.Build` whenever they want. Nothing is hidden.
//!
//! v0.4 highlights:
//!   - **`Expr` & `ctx.patch()`**: composable build-time expressions
//!     and conditional dependency patching. Apply `.patch` files to
//!     dependencies based on zig version, target OS, or any composable
//!     predicate.
//!   - **`ctx.overlay()`**: replace files in a dependency's source tree
//!     without git — direct file copies conditioned on `Expr`.
//!
//! v0.3 highlights:
//!   - **Deferred resolution**: modules can be declared in any order.
//!     Imports are resolved lazily when the build graph is finalized
//!     (via `help()`, `testModules()`, `releases()`, or `finalize()`).
//!   - **`Dep.mod`**: renamed from `module_registry` -- shorter, cleaner.
//!   - **`mod_imports`**: shorthand `[]const []const u8` for the common
//!     case of importing modules by name.
//!   - **`import_all`**: import ALL registered modules in one flag.
//!
//! Quickstart:
//!
//!     const std = @import("std");
//!     const zb = @import("ziobuild");
//!
//!     pub fn build(b: *std.Build) void {
//!         const ctx = zb.init(b, .{ .name = "myapp" });
//!
//!         _ = ctx.module("mylib", .{ .root = "src/lib.zig" });
//!
//!         const app = ctx.app(.{
//!             .root = "src/main.zig",
//!             .mod_imports = &.{"mylib"},
//!         });
//!         _ = ctx.testModules(.{});
//!         ctx.help();
//!     }

const std = @import("std");

const context_mod = @import("context.zig");
const target_mod = @import("target.zig");
const app_mod = @import("app.zig");
const lib_mod = @import("lib.zig");
const tests_mod = @import("tests.zig");
const examples_mod = @import("examples_glob.zig");
const releases_mod = @import("releases.zig");
const help_mod = @import("help.zig");
const deps_mod = @import("deps.zig");
const module_mod = @import("module.zig");
const modules_mod = @import("modules.zig");
const options_mod = @import("options.zig");
const expr_mod = @import("expr.zig");
const patch_mod = @import("patch.zig");

/// Build a `Context` from a `*std.Build`. Entry point.
pub const init = context_mod.init;

/// Bundle of build state passed to every helper.
pub const Context = context_mod.Context;

/// Options for `init`.
pub const InitOptions = context_mod.InitOptions;

/// Import descriptor for all helpers that accept deps.
pub const Dep = context_mod.Dep;

/// Cross-compile preset for `releases`.
pub const Target = target_mod.Target;

/// Escape hatch for arbitrary targets.
pub const CustomTarget = target_mod.CustomTarget;

/// Options for `Context.app`.
pub const AppOptions = app_mod.Options;

/// Options for `Context.lib`.
pub const LibOptions = lib_mod.Options;

/// Options for `Context.tests`.
pub const TestsOptions = tests_mod.Options;

/// Options for `Context.releases`.
pub const ReleasesOptions = releases_mod.Options;

/// Options for `Context.module`.
pub const ModuleOptions = module_mod.Options;

/// Options for `Context.testModules`.
pub const TestModulesOptions = modules_mod.Options;

/// Declare a boolean build option with a default.
pub const boolOption = options_mod.boolOption;

/// Declare a string build option with a default.
pub const stringOption = options_mod.stringOption;

/// Declare an enum build option with a default.
pub const enumOption = options_mod.enumOption;

/// Declare an integer build option with a default.
pub const intOption = options_mod.intOption;

/// Composable build-time expression for conditional logic.
pub const Expr = expr_mod.Expr;

/// Comparison operator for `Expr.zigVersion`.
pub const ExprCmp = expr_mod.Cmp;

/// Options for `Context.patch`.
pub const PatchOptions = patch_mod.Options;
pub const OverlayOptions = patch_mod.OverlayOptions;

test {
    _ = context_mod;
    _ = target_mod;
    _ = app_mod;
    _ = lib_mod;
    _ = tests_mod;
    _ = examples_mod;
    _ = releases_mod;
    _ = help_mod;
    _ = deps_mod;
    _ = module_mod;
    _ = modules_mod;
    _ = options_mod;
    _ = expr_mod;
    _ = patch_mod;
}
