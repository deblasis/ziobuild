const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- Build options (mirrors ghostty's Config.zig) ----
    const app_runtime = b.option(
        enum { native, none, wasm },
        "runtime",
        "App runtime mode (default: native)",
    ) orelse .native;

    const emit_bench = b.option(
        bool,
        "emit-bench",
        "Emit benchmark artifacts",
    ) orelse false;

    // ---- Shared deps (mirrors ghostty's SharedDeps) ----
    const simdns = b.dependency("simdns", .{
        .target = target,
        .optimize = optimize,
    });
    const unicode_tables = b.dependency("unicode_tables", .{
        .target = target,
        .optimize = optimize,
    });

    // ---- Config module (importable by lib and exe) ----
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    config_mod.addImport("simdns", simdns.module("simdns"));
    config_mod.addImport("unicode_tables", unicode_tables.module("unicode_tables"));

    // ---- App executable (mirrors ghostty's GhosttyExe) ----
    if (app_runtime == .native) {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("config", config_mod);
        exe_mod.addImport("simdns", simdns.module("simdns"));
        exe_mod.addImport("unicode_tables", unicode_tables.module("unicode_tables"));

        const exe = b.addExecutable(.{
            .name = "ghostty-mini",
            .root_module = exe_mod,
        });
        b.installArtifact(exe);

        // Run step
        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| run_cmd.addArgs(args);
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        // Bench step
        if (emit_bench) {
            const bench_mod = b.createModule(.{
                .root_source_file = b.path("bench/main.zig"),
                .target = target,
                .optimize = .ReleaseFast,
            });
            const bench_exe = b.addExecutable(.{
                .name = "ghostty-mini-bench",
                .root_module = bench_mod,
            });
            b.installArtifact(bench_exe);
        }
    }

    // ---- Library (static, mirrors ghostty's libghostty-vt) ----
    {
        const lib_mod = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });
        lib_mod.addImport("config", config_mod);

        const lib = b.addLibrary(.{
            .name = "ghostty-mini",
            .root_module = lib_mod,
        });
        b.installArtifact(lib);
    }

    // ---- Unit tests (mirrors ghostty's test step) ----
    {
        const test_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        test_mod.addImport("config", config_mod);
        test_mod.addImport("simdns", simdns.module("simdns"));
        test_mod.addImport("unicode_tables", unicode_tables.module("unicode_tables"));

        const unit_tests = b.addTest(.{
            .root_module = test_mod,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }

    // ---- Library tests (mirrors ghostty's test-lib-vt) ----
    {
        const lib_test_mod = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });
        lib_test_mod.addImport("config", config_mod);
        const lib_tests = b.addTest(.{
            .root_module = lib_test_mod,
        });
        const run_lib_tests = b.addRunArtifact(lib_tests);
        const test_lib_step = b.step("test-lib", "Run library tests");
        test_lib_step.dependOn(&run_lib_tests.step);
    }

    // ---- Examples (mirrors ghostty's example discovery) ----
    {
        const examples_step = b.step("examples", "Build all examples");

        const example_dirs = .{"basic"} ++ .{"daemon"};

        inline for (example_dirs) |dir| {
            const example_mod = b.createModule(.{
                .root_source_file = b.path("examples/" ++ dir ++ "/main.zig"),
                .target = target,
                .optimize = optimize,
            });
            const example_exe = b.addExecutable(.{
                .name = "example-" ++ dir,
                .root_module = example_mod,
            });
            b.installArtifact(example_exe);

            const run_cmd = b.addRunArtifact(example_exe);
            if (b.args) |args| run_cmd.addArgs(args);
            const run_step = b.step("run-example-" ++ dir, "Run " ++ dir ++ " example");
            run_step.dependOn(&run_cmd.step);

            examples_step.dependOn(&example_exe.step);
        }
    }

    // ---- Release matrix (mirrors ghostty's dist step) ----
    {
        const release_step = b.step("release", "Build release matrix");

        const release_targets = .{
            .{ "linux-x86_64", std.Target.Query{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu } },
            .{ "linux-aarch64", std.Target.Query{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu } },
            .{ "macos-aarch64", std.Target.Query{ .cpu_arch = .aarch64, .os_tag = .macos } },
            .{ "windows-x86_64", std.Target.Query{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu } },
        };

        inline for (release_targets) |entry| {
            const dir_name = entry[0];
            const query = entry[1];

            const rel_mod = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(query),
                .optimize = .ReleaseSafe,
                .strip = true,
            });
            rel_mod.addImport("config", config_mod);
            rel_mod.addImport("simdns", simdns.module("simdns"));
            rel_mod.addImport("unicode_tables", unicode_tables.module("unicode_tables"));

            const rel = b.addExecutable(.{
                .name = "ghostty-mini",
                .root_module = rel_mod,
            });
            const install = b.addInstallArtifact(rel, .{
                .dest_dir = .{ .override = .{ .custom = b.fmt("release/{s}", .{dir_name}) } },
            });
            release_step.dependOn(&install.step);
        }
    }
}
