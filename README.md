# ziobuild

Declarative `build.zig` DSL. Comptime helpers that wrap `std.Build` and
collapse 80+ line build files into a dozen calls. Nothing is hidden:
every helper that produces an artifact returns the underlying
`*std.Build.Step.Compile` so you can drop down to raw `std.Build`
whenever you want.

## The pitch

A typical project has one app, tests, two examples, and a release
matrix. Vanilla `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const app = b.addExecutable(.{ .name = "myapp", .root_module = app_mod });
    b.installArtifact(app);
    const run_app = b.addRunArtifact(app);
    if (b.args) |args| run_app.addArgs(args);
    const run_step = b.step("run", "Run myapp");
    run_step.dependOn(&run_app.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    const hello_mod = b.createModule(.{
        .root_source_file = b.path("examples/hello/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const hello = b.addExecutable(.{ .name = "hello", .root_module = hello_mod });
    b.installArtifact(hello);
    const run_hello = b.addRunArtifact(hello);
    const run_hello_step = b.step("run-example-hello", "Run example hello");
    run_hello_step.dependOn(&run_hello.step);

    const world_mod = b.createModule(.{
        .root_source_file = b.path("examples/world/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const world = b.addExecutable(.{ .name = "world", .root_module = world_mod });
    b.installArtifact(world);
    const run_world = b.addRunArtifact(world);
    const run_world_step = b.step("run-example-world", "Run example world");
    run_world_step.dependOn(&run_world.step);

    const release_step = b.step("release", "Build release matrix");
    const targets = [_]std.Target.Query{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    };
    const dirs = [_][]const u8{ "linux-x86_64", "macos-aarch64", "windows-x86_64" };
    for (targets, dirs) |q, dir| {
        const m = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(q),
            .optimize = .ReleaseSafe,
            .strip = true,
        });
        const exe = b.addExecutable(.{ .name = "myapp", .root_module = m });
        const inst = b.addInstallArtifact(exe, .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("release/{s}", .{dir}) } },
        });
        release_step.dependOn(&inst.step);
    }
}
```

That's 80 lines. With ziobuild:

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });
    const app = ctx.app(.{ .root = "src/main.zig" });
    _ = ctx.tests(.{ .root = "src/main.zig" });
    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{ .linux_x64, .darwin_arm64, .windows_x64 },
    });
    ctx.help();
}
```

14 lines. Same artifacts, same step graph. Adding a third example is
a new file, no `build.zig` edit. Adding a fourth release target is
one enum variant.

## Install

`build.zig.zon`:

```zig
.dependencies = .{
    .ziobuild = .{
        .url = "https://github.com/deblasis/ziobuild/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...",  // zig prints the right value on first fetch
    },
},
```

`build.zig`:

```zig
const zb = @import("ziobuild");
```

Pin Zig 0.16 with `mlugg/setup-zig@v1` in CI; the build API is a
moving target.

## Quickstart

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });

    const app = ctx.app(.{
        .root = "src/main.zig",
        .deps = &.{ "ziosh", "zioarg" },  // resolved from build.zig.zon
    });

    _ = ctx.lib(.{
        .name = "mylib",
        .root = "src/lib.zig",
    });

    _ = ctx.tests(.{ .root = "src/main.zig" });
    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{ .linux_x64, .darwin_arm64, .windows_x64 },
    });
    ctx.help();
}
```

## API

### `zb.init(b, opts) -> Context`

Entry point. `opts.name` is the default executable name. `opts.target`
and `opts.optimize` default to `b.standardTargetOptions(.{})` /
`b.standardOptimizeOption(.{})` if you don't supply them.

### `ctx.app(opts) -> *Compile`

Build an executable. Installs it under `zig-out/bin` (default) and
registers a `run` step. Returns the underlying
`*std.Build.Step.Compile`.

### `ctx.lib(opts) -> *Compile`

Build a library. Static by default; pass `.linkage = .dynamic` for
shared.

### `ctx.tests(opts) -> *Compile`

Declare a test compile, register a top-level `test` step.

### `ctx.examples(pattern) -> []const *Compile`

Glob-walk the build root at build time. Pattern shape:
`<prefix>/*/<leaf>` (e.g. `examples/*/main.zig`). For each match,
register an executable named after the directory and a
`run-example-<name>` step. Aggregates them under `run-examples`.

### `ctx.releases(opts) -> []const *Compile`

Build one executable per release target. Installs each under
`zig-out/release/<target-dir>/`. `opts.targets` is a slice of `Target`
enum presets; `opts.custom_targets` is the escape hatch to
`std.Target.Query`.

Presets: `.linux_x64`, `.linux_arm64`, `.darwin_x64`, `.darwin_arm64`,
`.windows_x64`, `.windows_arm64`.

### `ctx.help()`

Adds a `help` step that prints a tidy table of every registered
top-level step plus its description. The default `zig build --help`
output is unreadable on real projects.

## Dependency resolution

`.deps = &.{ "ziosh", "zioarg" }` in any helper looks up the matching
`b.dependency()` results from `build.zig.zon` by string name and adds
the resolved module as an import on the consumer module. If a dep is
not declared in `build.zig.zon`, ziobuild aborts the build with a
diagnostic that names the missing dep AND lists every dep that IS
declared. No more deep `b.dependency` panics.

## Examples

### Smallest possible

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });
    _ = ctx.app(.{ .root = "src/main.zig" });
    _ = ctx.tests(.{ .root = "src/main.zig" });
    ctx.help();
}
```

### Custom target

```zig
_ = ctx.releases(.{
    .of = app,
    .targets = &.{.linux_x64},
    .custom_targets = &.{
        .{ .name = "freebsd-x86_64", .query = .{
            .cpu_arch = .x86_64, .os_tag = .freebsd,
        } },
    },
});
```

### Drop down to raw `std.Build`

Every helper returns the underlying `*Compile`. Use it.

```zig
const app = ctx.app(.{ .root = "src/main.zig" });
app.root_module.addCSourceFile(.{ .file = b.path("src/foo.c") });
app.linkLibC();
```

## FAQ

**Does ziobuild hide anything?**

No. Every artifact-producing helper returns the raw `*Compile`. Step
names and graph wiring are observable via `ctx.help()`.

**Why are there only six release presets?**

They cover the common shipping matrix. For anything else, use
`custom_targets` with a `std.Target.Query`.

**Does ziobuild support `--watch`?**

Not in v0.1. The watch story is a separate package.

**What Zig version?**

0.16.0. Pinned via `.zigversion`. The build API is a moving target.

## Compatibility

- **Zig**: 0.16.0 (tracked in CI; earlier versions are not supported).
- **Platforms**: tested on Linux (x86_64), macOS (x86_64, aarch64), Windows (x86_64).
- **Breaking changes**: pinned to the Zig 0.16 stable release cycle. A major-version bump in Zig may require a major-version bump here.


## License

MIT. Copyright Alessandro De Blasis.
