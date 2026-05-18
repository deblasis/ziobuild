//! Conditional dependency patching. `patch()` registers a pending
//! patch (condition + file). `applyPatches()` runs `git apply` for
//! all matching patches on a given dependency's source directory.
//!
//! Patches are applied eagerly at build configuration time (when
//! `resolveZonDep` is called), not as build graph steps. This
//! ensures the patched sources are visible to the compiler.
//!
//! Idempotency: if a patch is already applied (reverse check
//! succeeds), it is silently skipped. If a patch conflicts with
//! the source (both forward and reverse check fail), the build
//! fails with a clear error message.

const std = @import("std");

const context_mod = @import("context.zig");
const expr_mod = @import("expr.zig");

/// Options for `ctx.patch()`.
pub const Options = struct {
    /// Path to the .patch file, relative to the build root.
    file: []const u8,
    /// Condition that must be true for the patch to apply.
    when: expr_mod.Expr,
    /// Strip depth for `git apply` (like -p<N>). Defaults to 1.
    strip: u16 = 1,
};

/// Options for `ctx.overlay()`.
pub const OverlayOptions = struct {
    /// Path to the overlay directory, relative to the build root.
    /// The directory structure mirrors the dependency's source tree.
    /// Every file in this directory is copied over the corresponding
    /// file in the dependency's source.
    dir: []const u8,
    /// Condition that must be true for the overlay to apply.
    when: expr_mod.Expr,
};

/// A pending patch registered via `ctx.patch()`. Stored on Context
/// and consumed during dependency resolution.
pub const PendingPatch = struct {
    dep_name: []const u8,
    file: []const u8,
    when: expr_mod.Expr,
    strip: u16,
};

/// A pending overlay registered via `ctx.overlay()`. Stored on Context
/// and consumed during dependency resolution.
pub const PendingOverlay = struct {
    dep_name: []const u8,
    dir: []const u8,
    when: expr_mod.Expr,
};

/// Register a conditional patch for a dependency. The patch will be
/// applied during dependency resolution if the `when` expression
/// evaluates to true.
pub fn patch(ctx: context_mod.Context, dep_name: []const u8, options: Options) void {
    ctx.patches.append(ctx.b.allocator, .{
        .dep_name = dep_name,
        .file = options.file,
        .when = options.when,
        .strip = options.strip,
    }) catch @panic("OOM");
}

/// Register a conditional file overlay for a dependency. Files from
/// `dir` are copied over the dependency's source tree at resolution
/// time. No git required — uses direct file copies.
pub fn overlay(ctx: context_mod.Context, dep_name: []const u8, options: OverlayOptions) void {
    ctx.overlays.append(ctx.b.allocator, .{
        .dep_name = dep_name,
        .dir = options.dir,
        .when = options.when,
    }) catch @panic("OOM");
}

/// Apply all registered patches for `dep_name` to the dependency at
/// `dep`'s root directory. Only applies patches whose `when`
/// expression evaluates to true.
///
/// Patches are applied eagerly at build configuration time using
/// `git apply`. Idempotent: if a patch is already applied, it is
/// silently skipped. If a patch conflicts, the build panics with
/// a clear error message.
pub fn applyPatches(
    ctx: context_mod.Context,
    dep_name: []const u8,
    dep: *std.Build.Dependency,
) void {
    for (ctx.patches.items) |p| {
        if (!std.mem.eql(u8, p.dep_name, dep_name)) continue;
        if (!p.when.evaluate(ctx.b, ctx.target, ctx.optimize)) continue;

        const patch_path = ctx.b.pathFromRoot(p.file);
        const dep_root = dep.builder.pathFromRoot(".");
        const strip_arg = ctx.b.fmt("-p{d}", .{p.strip});

        applyPatch(ctx.b, dep_root, strip_arg, patch_path);
    }
}

/// Apply a single patch. Uses a three-step approach:
///
///   1. `git apply --check` — can the patch be applied cleanly?
///   2. If yes: `git apply` for real.
///   3. If no: `git apply --reverse --check` — is it already applied?
///      - If already applied: skip silently (idempotent).
///      - If not: the patch conflicts. Panic with a clear message.
fn applyPatch(
    b: *std.Build,
    dep_root: []const u8,
    strip_arg: []const u8,
    patch_path: []const u8,
) void {
    const argv_check = &.{ "git", "-C", dep_root, "apply", "--check", strip_arg, patch_path };
    const argv_reverse_check = &.{ "git", "-C", dep_root, "apply", "--check", "--reverse", strip_arg, patch_path };
    const argv_apply = &.{ "git", "-C", dep_root, "apply", strip_arg, patch_path };

    // Step 1: Can the patch be applied cleanly?
    var code: u8 = undefined;
    _ = b.runAllowFail(argv_check, &code, .ignore) catch {
        // Step 3a: Is it already applied? (reverse check)
        var rev_code: u8 = undefined;
        _ = b.runAllowFail(argv_reverse_check, &rev_code, .ignore) catch {
            // Step 3b: Neither forward nor reverse applies — conflict.
            std.debug.panic(
                "ziobuild: patch '{s}' conflicts with dependency source in '{s}'. " ++
                    "The patch does not apply cleanly and is not already applied. " ++
                    "Fix the patch or remove the ctx.patch() call.\n",
                .{ patch_path, dep_root },
            );
        };
        // Reverse check succeeded — patch is already applied. Skip.
        return;
    };

    // Step 2: Apply for real.
    _ = b.runAllowFail(argv_apply, &code, .ignore) catch {
        // Unlikely: --check passed but apply failed. Report it.
        std.debug.panic(
            "ziobuild: patch '{s}' passed --check but failed to apply in '{s}'.\n",
            .{ patch_path, dep_root },
        );
    };
}

/// Apply all registered overlays for `dep_name` to the dependency at
/// `dep`'s root directory. Copies files from overlay directories into
/// the dep's source tree.
pub fn applyOverlays(
    ctx: context_mod.Context,
    dep_name: []const u8,
    dep: *std.Build.Dependency,
) void {
    for (ctx.overlays.items) |o| {
        if (!std.mem.eql(u8, o.dep_name, dep_name)) continue;
        if (!o.when.evaluate(ctx.b, ctx.target, ctx.optimize)) continue;

        const overlay_dir = ctx.b.pathFromRoot(o.dir);
        const dep_root = dep.builder.pathFromRoot(".");

        copyOverlayDir(ctx.b, overlay_dir, dep_root);
    }
}

/// Recursively copy files from `src_dir` to `dst_dir`. Uses `xcopy`
/// on Windows and `cp -r` on other platforms for simplicity.
fn copyOverlayDir(b: *std.Build, src_dir: []const u8, dst_dir: []const u8) void {
    const argv = switch (builtin.os.tag) {
        .windows => &.{ "xcopy", src_dir, dst_dir, "/E", "/Y", "/Q" },
        else => &.{ "cp", "-r", src_dir ++ "/.", dst_dir },
    };
    var code: u8 = undefined;
    _ = b.runAllowFail(argv, &code, .ignore) catch {
        std.debug.panic(
            "ziobuild: overlay directory '{s}' could not be copied to '{s}'." ++
                " Ensure the overlay directory exists.\n",
            .{ src_dir, dst_dir },
        );
    };
}

const builtin = @import("builtin");

test "Options struct compiles" {
    const _opts: Options = .{
        .file = "patches/foo/fix.patch",
        .when = expr_mod.Expr.literal(true),
    };
    _ = _opts;

    const _overlay_opts: OverlayOptions = .{
        .dir = "overlays/foo",
        .when = expr_mod.Expr.literal(true),
    };
    _ = _overlay_opts;

    try std.testing.expect(true);
}
