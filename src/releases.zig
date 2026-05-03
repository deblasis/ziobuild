//! `Context.releases` builds one executable per release target and
//! installs each under `zig-out/release/<dir-name>/`. Aggregates them
//! all under a single top-level step (default `release`).
//!
//! Release artifacts inherit all imports from the template executable,
//! so cross-compiled binaries have the same import table as the
//! development build.

const std = @import("std");

const context_mod = @import("context.zig");
const target_mod = @import("target.zig");

/// Options for `Context.releases`.
pub const Options = struct {
    /// Template app: provides the root source path and the import
    /// set. Re-used as a recipe; ziobuild builds a fresh
    /// `addExecutable` per target with the same imports.
    of: *std.Build.Step.Compile,
    /// Additional imports for each release artifact, beyond what the
    /// template already carries.
    imports: []const context_mod.Dep = &.{},
    /// Preset targets.
    targets: []const target_mod.Target = &.{},
    /// Escape hatch: arbitrary target queries.
    custom_targets: []const target_mod.CustomTarget = &.{},
    /// Optimize mode used for every release artifact. Defaults to
    /// `.ReleaseSafe`.
    optimize: std.builtin.OptimizeMode = .ReleaseSafe,
    /// Strip debug info. Defaults to true.
    strip: bool = true,
    /// Top-level step name. Defaults to `release`.
    step_name: []const u8 = "release",
};

/// Build one artifact per requested target. Returns the slice of
/// compile steps; the i-th entry is the i-th preset target, then the
/// custom targets in order.
pub fn releases(
    ctx: context_mod.Context,
    options: Options,
) []const *std.Build.Step.Compile {
    const b = ctx.b;
    const arena = b.allocator;

    const aggregate = b.step(options.step_name, "Build release matrix");

    const total = options.targets.len + options.custom_targets.len;
    const out = arena.alloc(*std.Build.Step.Compile, total) catch @panic("OOM");

    const root_path = sourceRoot(options.of) orelse {
        std.debug.panic("ziobuild.releases: template app has no root source file", .{});
    };
    const exe_name = options.of.name;

    // Collect the import table from the template's root module so
    // each release build gets the same imports.
    const template_imports = &options.of.root_module.import_table;

    var idx: usize = 0;
    for (options.targets) |t| {
        out[idx] = buildOne(b, root_path, exe_name, t.query(), template_imports, options);
        aggregate.dependOn(&b.addInstallArtifact(out[idx], .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("release/{s}", .{t.dirName()}) } },
        }).step);
        idx += 1;
    }
    for (options.custom_targets) |t| {
        out[idx] = buildOne(b, root_path, exe_name, t.query, template_imports, options);
        aggregate.dependOn(&b.addInstallArtifact(out[idx], .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("release/{s}", .{t.name}) } },
        }).step);
        idx += 1;
    }
    return out;
}

fn buildOne(
    b: *std.Build,
    root_path: []const u8,
    exe_name: []const u8,
    query: std.Target.Query,
    template_imports: *const std.StringArrayHashMapUnmanaged(*std.Build.Module),
    options: Options,
) *std.Build.Step.Compile {
    const resolved = b.resolveTargetQuery(query);
    const mod = b.createModule(.{
        .root_source_file = b.path(root_path),
        .target = resolved,
        .optimize = options.optimize,
        .strip = options.strip,
    });

    // Copy all imports from the template module
    for (template_imports.keys(), template_imports.values()) |name, imp_mod| {
        mod.addImport(name, imp_mod);
    }

    return b.addExecutable(.{
        .name = exe_name,
        .root_module = mod,
    });
}

/// Recover the root source file path of the template `Compile`. The
/// `addExecutable` API consumes a Module; we read the module's root
/// source LazyPath back out.
fn sourceRoot(c: *std.Build.Step.Compile) ?[]const u8 {
    const lp = c.root_module.root_source_file orelse return null;
    return switch (lp) {
        .src_path => |sp| sp.sub_path,
        else => null,
    };
}

test "releases options struct compiles" {
    const _opts: Options = .{ .of = undefined };
    _ = _opts;
    try std.testing.expect(true);
}
