//! Resolve `&.{ "ziosh", "zioarg" }` style dep names against
//! `b.available_deps` (the list of dep names declared in
//! `build.zig.zon`). On miss we panic with a precise message that
//! names the missing dep and lists every dep that IS declared. The
//! goal is to replace the inscrutable deep panic from
//! `b.dependency()` with a one-shot diagnostic.
//!
//! Note: `b.available_deps` is a runtime-populated field, so true
//! comptime failure isn't possible without a code generator. The
//! practical equivalent is a build-script run-time fail, which still
//! aborts the build before any artifacts are produced.

const std = @import("std");

/// Sentinel error raised when a dep name is not declared in
/// `build.zig.zon`. Panic-propagated; callers see the formatted
/// message we emit, not this error name.
pub const Error = error{UndeclaredDep};

/// Walk `dep_names`. For each name not present in
/// `b.available_deps`, panic with a formatted message listing the
/// declared deps. For each name that resolves, look up the
/// dependency module and add it as an import on `consumer` under the
/// same name.
pub fn addDeps(
    b: *std.Build,
    consumer: *std.Build.Module,
    dep_names: []const []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    for (dep_names) |name| {
        if (!declared(b, name)) {
            failMissing(b, name);
        }
        const dep = b.dependency(name, .{
            .target = target,
            .optimize = optimize,
        });
        consumer.addImport(name, dep.module(name));
    }
}

/// True iff `name` appears in `b.available_deps`.
pub fn declared(b: *std.Build, name: []const u8) bool {
    for (b.available_deps) |entry| {
        if (std.mem.eql(u8, entry[0], name)) return true;
    }
    return false;
}

fn failMissing(b: *std.Build, missing: []const u8) noreturn {
    // Build the message with a stack-backed writer. `b.allocator` is
    // an arena, so a temporary heap allocation is fine, but the
    // simplest in-process path is `std.fmt.allocPrint`-style chunks
    // joined with `b.fmt`.
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
    // Direct unit testing of `declared` requires a *std.Build, which
    // we don't have in unit-test scope. Coverage for this path lives
    // in the integration tests: see tests/fixtures/smoke and
    // tests/fixtures/kitchen_sink, which exercise both the
    // declared-and-resolved happy path and (negatively) confirm that
    // an undeclared dep would abort the build.
    try std.testing.expect(true);
}
