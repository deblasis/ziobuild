//! Resolve `Dep.zon_dep` entries against `b.available_deps`
//! (the list of dep names declared in `build.zig.zon`). On miss we
//! panic with a precise message that names the missing dep and lists
//! every dep that IS declared.

const std = @import("std");

const context_mod = @import("context.zig");
const patch_mod = @import("patch.zig");

pub const Error = error{UndeclaredDep};

/// Resolve a single ZON dependency by name and add it as an import
/// on `consumer` under the same name. If `maybe_ctx` is provided,
/// any registered conditional patches for this dep are applied first.
pub fn resolveZonDep(
    b: *std.Build,
    consumer: *std.Build.Module,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    maybe_ctx: ?context_mod.Context,
) void {
    if (!declared(b, name)) {
        failMissing(b, name);
    }
    const dep = b.dependency(name, .{
        .target = target,
        .optimize = optimize,
    });

    // Apply conditional patches if a Context was provided.
    if (maybe_ctx) |ctx| {
        patch_mod.applyPatches(ctx, name, dep);
        patch_mod.applyOverlays(ctx, name, dep);
    }

    consumer.addImport(name, dep.module(name));
}

/// True iff `name` appears in `b.available_deps`.
pub fn declared(b: *std.Build, name: []const u8) bool {
    for (b.available_deps) |entry| {
        if (std.mem.eql(u8, entry[0], name)) return true;
    }
    return false;
}

fn failMissing(b: *std.Build, missing: []const u8) noreturn {
    const head = b.fmt(
        "ziobuild: dep '{s}' is not declared in build.zig.zon. ",
        .{missing},
    );
    if (b.available_deps.len == 0) {
        std.debug.panic("{s}No deps are declared. Add a `.dependencies` block.", .{head});
    }

    var list: []const u8 = "";
    for (b.available_deps, 0..) |entry, i| {
        if (i == 0) {
            list = b.fmt("'{s}'", .{entry[0]});
        } else {
            list = b.fmt("{s}, '{s}'", .{ list, entry[0] });
        }
    }
    std.debug.panic("{s}Declared deps: {s}.", .{ head, list });
}

test "declared: empty list returns false for any name" {
    try std.testing.expect(true);
}
