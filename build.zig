const std = @import("std");

// Re-exports: when a downstream `build.zig` writes
// `const zb = @import("ziobuild");`, the build runner resolves the
// import to THIS file's namespace (the dep's build.zig, treated as a
// struct). Re-exporting the public surface here lets callers reach
// `zb.init(...)`, `zb.Target`, etc. without a separate addImport hop.
pub const init = @import("src/context.zig").init;
pub const Context = @import("src/context.zig").Context;
pub const InitOptions = @import("src/context.zig").InitOptions;
pub const Dep = @import("src/context.zig").Dep;
pub const Target = @import("src/target.zig").Target;
pub const CustomTarget = @import("src/target.zig").CustomTarget;
pub const AppOptions = @import("src/app.zig").Options;
pub const LibOptions = @import("src/lib.zig").Options;
pub const TestsOptions = @import("src/tests.zig").Options;
pub const ReleasesOptions = @import("src/releases.zig").Options;
pub const ModuleOptions = @import("src/module.zig").Options;
pub const TestModulesOptions = @import("src/modules.zig").Options;
pub const boolOption = @import("src/options.zig").boolOption;
pub const stringOption = @import("src/options.zig").stringOption;
pub const enumOption = @import("src/options.zig").enumOption;
pub const intOption = @import("src/options.zig").intOption;
pub const Expr = @import("src/expr.zig").Expr;
pub const ExprCmp = @import("src/expr.zig").Cmp;
pub const PatchOptions = @import("src/patch.zig").Options;
pub const OverlayOptions = @import("src/patch.zig").OverlayOptions;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("ziobuild", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unit tests on src.
    const unit_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_unit = b.addRunArtifact(unit_tests);

    // Integration tests live under tests/. They spawn child `zig
    // build` against fixtures and assert artifacts on disk. Pass the
    // absolute fixture root and the zig exe path through Step.Options
    // so tests don't depend on the test runner's cwd.
    const opts = b.addOptions();
    opts.addOption([]const u8, "fixtures_dir", b.pathFromRoot("tests/fixtures"));
    opts.addOption([]const u8, "minimal_dir", b.pathFromRoot("examples/minimal"));
    opts.addOption([]const u8, "zig_exe", b.graph.zig_exe);

    const integ_mod = b.createModule(.{
        .root_source_file = b.path("tests/integration.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ziobuild", .module = mod },
            .{ .name = "test_options", .module = opts.createModule() },
        },
    });
    const integ_tests = b.addTest(.{
        .root_module = integ_mod,
    });
    const run_integ = b.addRunArtifact(integ_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_unit.step);
    test_step.dependOn(&run_integ.step);

    // Build the headline fixture as part of CI. Spawns child `zig
    // build` in examples/minimal and surfaces failure here.
    const fixture_run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    fixture_run.setCwd(b.path("examples/minimal"));
    fixture_run.has_side_effects = true;
    const fixture_step = b.step("fixture", "Build the minimal fixture (examples/minimal)");
    fixture_step.dependOn(&fixture_run.step);
}
