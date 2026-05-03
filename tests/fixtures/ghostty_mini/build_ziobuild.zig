const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "ghostty-mini" });

    // ---- Shared deps (mirrors ghostty's SharedDeps) ----
    const simdns = b.dependency("simdns", .{
        .target = ctx.target,
        .optimize = ctx.optimize,
    });
    const unicode_tables = b.dependency("unicode_tables", .{
        .target = ctx.target,
        .optimize = ctx.optimize,
    });

    // ---- Config module (importable by lib and exe) ----
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config/root.zig"),
        .target = ctx.target,
        .optimize = ctx.optimize,
    });
    config_mod.addImport("simdns", simdns.module("simdns"));
    config_mod.addImport("unicode_tables", unicode_tables.module("unicode_tables"));

    // ---- App executable ----
    const app = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .direct = .{ .name = "config", .module = config_mod } },
            .{ .direct = .{ .name = "simdns", .module = simdns.module("simdns") } },
            .{ .direct = .{ .name = "unicode_tables", .module = unicode_tables.module("unicode_tables") } },
        },
    });

    // ---- Library (shared + static) ----
    _ = ctx.lib(.{
        .name = "ghostty-mini",
        .root = "src/lib.zig",
        .imports = &.{
            .{ .direct = .{ .name = "config", .module = config_mod } },
        },
    });

    // ---- Tests ----
    _ = ctx.tests(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .direct = .{ .name = "config", .module = config_mod } },
            .{ .direct = .{ .name = "simdns", .module = simdns.module("simdns") } },
            .{ .direct = .{ .name = "unicode_tables", .module = unicode_tables.module("unicode_tables") } },
        },
    });

    // ---- Examples ----
    _ = ctx.examples("examples/*/main.zig");

    // ---- Release matrix ----
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{
            .linux_x64,
            .linux_arm64,
            .darwin_arm64,
            .windows_x64,
        },
    });

    ctx.help();
}
