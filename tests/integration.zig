//! Integration tests for ziobuild. End-to-end tests that spawn a
//! child `zig build` in each fixture and assert the expected
//! artifacts exist on disk. The fixtures live under
//! `tests/fixtures/<name>/`. The headline `examples/minimal/` is
//! also exercised here so the README pitch can never bit-rot.

const std = @import("std");
const opts = @import("test_options");

const T = std.testing;
const builtin = @import("builtin");

const exe_suffix = if (builtin.os.tag == .windows) ".exe" else "";

/// Spawn `zig build [args...]` in `cwd_path` and return stdout, stderr,
/// and the term. Caller frees `stdout` and `stderr` with `T.allocator`.
fn runZigBuild(cwd_path: []const u8, extra_args: []const []const u8) !std.process.RunResult {
    var argv: std.array_list.Managed([]const u8) = .init(T.allocator);
    defer argv.deinit();
    try argv.append(opts.zig_exe);
    try argv.append("build");
    for (extra_args) |a| try argv.append(a);

    // `T.io` is the test runner's Io, initialized with the parent
    // process environ. Leaving `environ_map = null` makes spawn fall
    // back to that environ, so the child inherits PATH, APPDATA, etc.
    return std.process.run(T.allocator, T.io, .{
        .argv = argv.items,
        .cwd = .{ .path = cwd_path },
    });
}

fn freeRun(r: *std.process.RunResult) void {
    T.allocator.free(r.stdout);
    T.allocator.free(r.stderr);
}

fn expectFileExists(path: []const u8) !void {
    const f = std.Io.Dir.cwd().openFile(T.io, path, .{}) catch |err| {
        std.debug.print("expected file '{s}' to exist, got {s}\n", .{ path, @errorName(err) });
        return error.MissingArtifact;
    };
    f.close(T.io);
}

fn expectExited(r: std.process.RunResult, code: u8) !void {
    switch (r.term) {
        .exited => |c| if (c != code) {
            std.debug.print(
                "child exited {d} (expected {d})\nstdout: {s}\nstderr: {s}\n",
                .{ c, code, r.stdout, r.stderr },
            );
            return error.UnexpectedExit;
        },
        else => {
            std.debug.print(
                "child terminated abnormally\nstdout: {s}\nstderr: {s}\n",
                .{ r.stdout, r.stderr },
            );
            return error.UnexpectedExit;
        },
    }
}

fn fixturePath(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    return std.fs.path.join(arena, &.{ opts.fixtures_dir, name });
}

fn fixtureFile(arena: std.mem.Allocator, name: []const u8, sub: []const u8) ![]const u8 {
    return std.fs.path.join(arena, &.{ opts.fixtures_dir, name, sub });
}

test "smoke fixture: zig build produces zig-out/bin/smoke" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "smoke");

    var r = try runZigBuild(cwd, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    const exe = try fixtureFile(a, "smoke", "zig-out/bin/smoke" ++ exe_suffix);
    try expectFileExists(exe);
}

test "smoke fixture: zig build test runs unit tests" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "smoke");

    var r = try runZigBuild(cwd, &.{"test"});
    defer freeRun(&r);
    try expectExited(r, 0);
}

test "smoke fixture: zig build help exits clean" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "smoke");

    var r = try runZigBuild(cwd, &.{"help"});
    defer freeRun(&r);
    try expectExited(r, 0);
    try T.expect(std.mem.indexOf(u8, r.stderr, "test") != null);
    try T.expect(std.mem.indexOf(u8, r.stderr, "help") != null);
}

test "kitchen_sink fixture: zig build produces app, lib, examples" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "kitchen_sink");

    var r = try runZigBuild(cwd, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    try expectFileExists(try fixtureFile(a, "kitchen_sink", "zig-out/bin/kitchen" ++ exe_suffix));
    try expectFileExists(try fixtureFile(a, "kitchen_sink", "zig-out/bin/a" ++ exe_suffix));
    try expectFileExists(try fixtureFile(a, "kitchen_sink", "zig-out/bin/b" ++ exe_suffix));
}

test "kitchen_sink fixture: release step installs per-target binaries" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "kitchen_sink");

    var r = try runZigBuild(cwd, &.{"release"});
    defer freeRun(&r);
    try expectExited(r, 0);

    // We don't assert the file extension because the release artifact
    // name comes from cross-compile output naming, not the host.
    try expectFileExists(try fixtureFile(a, "kitchen_sink", "zig-out/release/linux-x86_64/kitchen"));
}

test "kitchen_sink fixture: examples glob discovers a and b" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "kitchen_sink");

    var r = try runZigBuild(cwd, &.{"help"});
    defer freeRun(&r);
    try expectExited(r, 0);
    try T.expect(std.mem.indexOf(u8, r.stderr, "run-example-a") != null);
    try T.expect(std.mem.indexOf(u8, r.stderr, "run-example-b") != null);
}

test "minimal headline fixture: zig build succeeds" {
    var r = try runZigBuild(opts.minimal_dir, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try expectFileExists(try std.fs.path.join(a, &.{ opts.minimal_dir, "zig-out/bin/minimal" ++ exe_suffix }));
    try expectFileExists(try std.fs.path.join(a, &.{ opts.minimal_dir, "zig-out/bin/hello" ++ exe_suffix }));
    try expectFileExists(try std.fs.path.join(a, &.{ opts.minimal_dir, "zig-out/bin/world" ++ exe_suffix }));
}

test "minimal headline fixture: release matrix builds three targets" {
    var r = try runZigBuild(opts.minimal_dir, &.{"release"});
    defer freeRun(&r);
    try expectExited(r, 0);

    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try expectFileExists(try std.fs.path.join(a, &.{ opts.minimal_dir, "zig-out/release/linux-x86_64/minimal" }));
    try expectFileExists(try std.fs.path.join(a, &.{ opts.minimal_dir, "zig-out/release/macos-aarch64/minimal" }));
    try expectFileExists(try std.fs.path.join(a, &.{ opts.minimal_dir, "zig-out/release/windows-x86_64/minimal.exe" }));
}

test "smoke fixture: built binary runs and exits 0" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "smoke");

    // Build first
    var build_r = try runZigBuild(cwd, &.{});
    defer freeRun(&build_r);
    try expectExited(build_r, 0);

    // Run the built binary
    const exe_path = try fixtureFile(a, "smoke", "zig-out/bin/smoke" ++ exe_suffix);
    const run_r = try std.process.run(T.allocator, T.io, .{
        .argv = &.{exe_path},
    });
    defer {
        T.allocator.free(run_r.stdout);
        T.allocator.free(run_r.stderr);
    }
    try expectExited(run_r, 0);
}

test "kitchen_sink fixture: test step passes" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "kitchen_sink");

    var r = try runZigBuild(cwd, &.{"test"});
    defer freeRun(&r);
    try expectExited(r, 0);
}

test "kitchen_sink fixture: individual example steps exist" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "kitchen_sink");

    // Build example a
    var r = try runZigBuild(cwd, &.{"run-example-a"});
    defer freeRun(&r);
    // The example may exit non-zero if it has no args, we just
    // check the step compiled and the binary exists.
    try expectFileExists(try fixtureFile(a, "kitchen_sink", "zig-out/bin/a" ++ exe_suffix));
}

test "comparison: plain build.zig produces a runnable binary" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "comparison_plain");

    var r = try runZigBuild(cwd, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    const exe = try fixtureFile(a, "comparison_plain", "zig-out/bin/comparison-plain" ++ exe_suffix);
    try expectFileExists(exe);

    // Run it and capture output
    const run_r = try std.process.run(T.allocator, T.io, .{
        .argv = &.{exe},
    });
    defer {
        T.allocator.free(run_r.stdout);
        T.allocator.free(run_r.stderr);
    }
    try expectExited(run_r, 0);
}

test "comparison: ziobuild produces a runnable binary" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "comparison_zb");

    var r = try runZigBuild(cwd, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    const exe = try fixtureFile(a, "comparison_zb", "zig-out/bin/comparison-zb" ++ exe_suffix);
    try expectFileExists(exe);

    // Run it and capture output
    const run_r = try std.process.run(T.allocator, T.io, .{
        .argv = &.{exe},
    });
    defer {
        T.allocator.free(run_r.stdout);
        T.allocator.free(run_r.stderr);
    }
    try expectExited(run_r, 0);
}

test "comparison: plain and ziobuild produce identical runtime output" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // Build and run plain
    const plain_cwd = try fixturePath(a, "comparison_plain");
    var plain_build = try runZigBuild(plain_cwd, &.{});
    defer freeRun(&plain_build);
    try expectExited(plain_build, 0);

    const plain_exe = try fixtureFile(a, "comparison_plain", "zig-out/bin/comparison-plain" ++ exe_suffix);
    const plain_run = try std.process.run(T.allocator, T.io, .{
        .argv = &.{plain_exe},
    });
    defer {
        T.allocator.free(plain_run.stdout);
        T.allocator.free(plain_run.stderr);
    }
    try expectExited(plain_run, 0);

    // Build and run ziobuild
    const zb_cwd = try fixturePath(a, "comparison_zb");
    var zb_build = try runZigBuild(zb_cwd, &.{});
    defer freeRun(&zb_build);
    try expectExited(zb_build, 0);

    const zb_exe = try fixtureFile(a, "comparison_zb", "zig-out/bin/comparison-zb" ++ exe_suffix);
    const zb_run = try std.process.run(T.allocator, T.io, .{
        .argv = &.{zb_exe},
    });
    defer {
        T.allocator.free(zb_run.stdout);
        T.allocator.free(zb_run.stderr);
    }
    try expectExited(zb_run, 0);

    // Both should produce the same output since they compile the same source
    try T.expectEqualStrings(plain_run.stdout, zb_run.stdout);
}

test "custom_target fixture: zig build succeeds" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "custom_target");

    var r = try runZigBuild(cwd, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    try expectFileExists(try fixtureFile(a, "custom_target", "zig-out/bin/ct" ++ exe_suffix));
}

test "custom_target fixture: release step builds custom target" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "custom_target");

    var r = try runZigBuild(cwd, &.{"release"});
    defer freeRun(&r);
    try expectExited(r, 0);

    // The custom target was freestanding-x86_64, which installs under
    // zig-out/release/freestanding-x86_64/
    try expectFileExists(try fixtureFile(a, "custom_target", "zig-out/release/freestanding-x86_64/ct"));
}

test "no_examples fixture: zig build succeeds despite missing examples dir" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "no_examples");

    var r = try runZigBuild(cwd, &.{});
    defer freeRun(&r);
    try expectExited(r, 0);

    try expectFileExists(try fixtureFile(a, "no_examples", "zig-out/bin/noex" ++ exe_suffix));
}

test "no_examples fixture: run-examples step is absent from help" {
    var arena = std.heap.ArenaAllocator.init(T.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cwd = try fixturePath(a, "no_examples");

    var r = try runZigBuild(cwd, &.{"help"});
    defer freeRun(&r);
    try expectExited(r, 0);
    // When examples() finds nothing, no run-example-* or run-examples
    // steps should appear.
    try T.expect(std.mem.indexOf(u8, r.stderr, "run-example") == null);
    try T.expect(std.mem.indexOf(u8, r.stderr, "run-examples") == null);
}
