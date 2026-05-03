//! `Context.examples` walks the build root at build-script time and
//! registers one example executable per match. The pattern shape is
//! restricted to `<prefix>/*/<leaf>` (e.g. `examples/*/main.zig`):
//! one `*` segment in the middle, plain text on either side. That
//! covers the headline ergonomics without pulling in a full glob
//! engine.
//!
//! Per match `<prefix>/<dir>/<leaf>`:
//!   - builds an executable named `<dir>`,
//!   - registers a `run-example-<dir>` step,
//!   - depends an aggregate `run-examples` step on the run.
//!
//! If the prefix dir does not exist, returns an empty slice. That
//! way calling `examples("examples/*/main.zig")` on a project that
//! has no examples yet is a no-op rather than a build failure.

const std = @import("std");

const context_mod = @import("context.zig");

/// Build-script-side error raised internally for malformed patterns.
/// Surfaces as a panic with context.
pub const PatternError = error{
    /// The pattern has zero or two-or-more `*` segments.
    BadStarCount,
    /// The `*` is not a complete path segment.
    StarNotASegment,
};

/// Walk the build root for `pattern` and register one example per
/// match. Returns the slice of compile steps so callers can post-
/// process if needed. No imports are attached to examples.
pub fn examples(
    ctx: context_mod.Context,
    comptime pattern: []const u8,
) []const *std.Build.Step.Compile {
    return examplesWithImports(ctx, pattern, &.{});
}

/// Like `examples()` but attaches the given imports to every example
/// executable.
pub fn examplesWithImports(
    ctx: context_mod.Context,
    comptime pattern: []const u8,
    imports: []const context_mod.Dep,
) []const *std.Build.Step.Compile {
    const split = comptime parsePattern(pattern);
    const prefix = split.prefix;
    const leaf = split.leaf;

    const b = ctx.b;
    const arena = b.allocator;

    var compiles: std.array_list.Managed(*std.Build.Step.Compile) = .init(arena);
    // Caller doesn't free; `b.allocator` is an arena tied to the build.

    const io = std.Io.Threaded.global_single_threaded.io();
    const root = b.build_root.handle;

    var dir = root.openDir(io, prefix, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return compiles.toOwnedSlice() catch &.{},
        else => std.debug.panic("ziobuild.examples: open '{s}' failed: {s}", .{ prefix, @errorName(err) }),
    };
    defer dir.close(io);

    // Collect names first so we can sort for determinism.
    var names: std.array_list.Managed([]const u8) = .init(arena);
    var it = dir.iterate();
    while (it.next(io) catch |err| std.debug.panic(
        "ziobuild.examples: iterate '{s}' failed: {s}",
        .{ prefix, @errorName(err) },
    )) |entry| {
        if (entry.kind != .directory) continue;
        // Make sure `<prefix>/<entry>/<leaf>` actually exists before
        // we register it. We open the candidate dir to verify
        // existence; statFile would require io, openDir already does.
        var sub = dir.openDir(io, entry.name, .{}) catch continue;
        defer sub.close(io);
        const f = sub.openFile(io, leaf, .{}) catch continue;
        f.close(io);
        names.append(b.dupe(entry.name)) catch @panic("OOM");
    }

    std.mem.sort([]const u8, names.items, {}, lessThan);

    const aggregate = b.step("run-examples", "Run all examples");

    for (names.items) |name| {
        const root_path = b.fmt("{s}/{s}/{s}", .{ prefix, name, leaf });
        const mod = b.createModule(.{
            .root_source_file = b.path(root_path),
            .target = ctx.target,
            .optimize = ctx.optimize,
        });
        ctx.resolveDeps(mod, imports);
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = mod,
        });
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        const step_name = b.fmt("run-example-{s}", .{name});
        const step_desc = b.fmt("Run example '{s}'", .{name});
        const step = b.step(step_name, step_desc);
        step.dependOn(&run.step);
        aggregate.dependOn(&run.step);
        compiles.append(exe) catch @panic("OOM");
    }

    return compiles.toOwnedSlice() catch &.{};
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

const Split = struct {
    prefix: []const u8,
    leaf: []const u8,
};

/// Comptime: split `<prefix>/*/<leaf>` into its two halves.
fn parsePattern(comptime pattern: []const u8) Split {
    comptime {
        var star_count: usize = 0;
        for (pattern) |c| if (c == '*') {
            star_count += 1;
        };
        if (star_count != 1) {
            @compileError(
                "ziobuild.examples: pattern must contain exactly one '*'; " ++
                    "expected '<prefix>/*/<leaf>', got '" ++ pattern ++ "'",
            );
        }
        const star_idx = std.mem.indexOfScalar(u8, pattern, '*').?;
        if (star_idx == 0 or star_idx == pattern.len - 1) {
            @compileError(
                "ziobuild.examples: '*' must be a full path segment; " ++
                    "got '" ++ pattern ++ "'",
            );
        }
        if (pattern[star_idx - 1] != '/' or pattern[star_idx + 1] != '/') {
            @compileError(
                "ziobuild.examples: '*' must be a full path segment surrounded by '/'; " ++
                    "got '" ++ pattern ++ "'",
            );
        }
        return .{
            .prefix = pattern[0 .. star_idx - 1],
            .leaf = pattern[star_idx + 2 ..],
        };
    }
}

test "parsePattern: examples/*/main.zig splits cleanly" {
    const s = comptime parsePattern("examples/*/main.zig");
    try std.testing.expectEqualStrings("examples", s.prefix);
    try std.testing.expectEqualStrings("main.zig", s.leaf);
}

test "parsePattern: deeper prefix" {
    const s = comptime parsePattern("a/b/c/*/main.zig");
    try std.testing.expectEqualStrings("a/b/c", s.prefix);
    try std.testing.expectEqualStrings("main.zig", s.leaf);
}

test "parsePattern: deeper leaf" {
    const s = comptime parsePattern("examples/*/sub/main.zig");
    try std.testing.expectEqualStrings("examples", s.prefix);
    try std.testing.expectEqualStrings("sub/main.zig", s.leaf);
}
