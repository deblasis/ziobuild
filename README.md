# ziobuild

Declarative `build.zig` DSL. Comptime helpers that wrap `std.Build` and
collapse 80+ line build files into a dozen calls. Nothing is hidden:
every helper that produces an artifact returns the underlying
`*std.Build.Step.Compile` so you can drop down to raw `std.Build`
whenever you want.

## The pitch

A typical project has one app, internal modules, tests, examples, and a
release matrix. Vanilla `build.zig` for a multi-module project:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mylib_mod = b.addModule("mylib", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("mylib", mylib_mod);

    const exe = b.addExecutable(.{ .name = "myapp", .root_module = exe_mod });
    b.installArtifact(exe);
    const run_app = b.addRunArtifact(exe);
    if (b.args) |args| run_app.addArgs(args);
    const run_step = b.step("run", "Run myapp");
    run_step.dependOn(&run_app.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("mylib", mylib_mod);
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
    // ... repeat for each example and release target
}
```

That's 40+ lines and we haven't added examples or releases. With
ziobuild:

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });

    _ = ctx.module("mylib", .{ .root = "src/lib.zig" });

    const app = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .module_registry = "mylib" },
        },
    });
    _ = ctx.tests(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .module_registry = "mylib" },
        },
    });
    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{ .linux_x64, .darwin_arm64, .windows_x64 },
    });
    ctx.help();
}
```

14 lines. Same artifacts, same step graph. Adding a module is one
`ctx.module()` call. Adding a third example is a new file, no
`build.zig` edit.

## Install

`build.zig.zon`:

```zig
.dependencies = .{
    .ziobuild = .{
        .url = "https://github.com/deblasis/ziobuild/archive/refs/tags/v0.2.0.tar.gz",
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

### Simple project

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

### Multi-module project

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });

    // Register internal modules
    _ = ctx.module("core", .{ .root = "src/core.zig" });
    _ = ctx.module("utils", .{
        .root = "src/utils.zig",
        .imports = &.{
            .{ .module_registry = "core" },
        },
    });

    // App depends on both modules
    const app = ctx.app(.{
        .root = "src/main.zig",
        .imports = &.{
            .{ .module_registry = "core" },
            .{ .module_registry = "utils" },
        },
    });

    // Test all registered modules at once
    _ = ctx.testModules(.{});

    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{ .linux_x64, .darwin_arm64, .windows_x64 },
    });
    ctx.help();
}
```

### Multiple executables with named run steps

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });

    _ = ctx.app(.{ .root = "src/main.zig" });  // "run" step

    const emit_tool = zb.boolOption(b, "emit-tool", true, "Build the tool");
    if (emit_tool) {
        _ = ctx.app(.{
            .name = "mytool",
            .root = "src/tool.zig",
            .step_name = "run-tool",
            .step_description = "Run the tool",
        });
    }

    ctx.help();
}
```

## API

### `zb.init(b, opts) -> Context`

Entry point. `opts.name` is the default executable name. `opts.target`
and `opts.optimize` default to `b.standardTargetOptions(.{})` /
`b.standardOptimizeOption(.{})` if you don't supply them.

### `ctx.module(name, opts) -> *Module`

Register a named module in the internal registry. Other helpers can
then reference it by name via `Dep.module_registry`.

```zig
_ = ctx.module("mylib", .{
    .root = "src/lib.zig",
    .imports = &.{
        .{ .module_registry = "other_mod" },
        .{ .zon_dep = "some_dep" },
        .{ .direct = .{ .name = "custom", .module = some_module } },
    },
});
```

### `ctx.app(opts) -> *Compile`

Build an executable. Installs it under `zig-out/bin` (default) and
registers a `run` step. Returns the underlying
`*std.Build.Step.Compile`.

```zig
const app = ctx.app(.{
    .root = "src/main.zig",
    .name = "myapp",            // defaults to ctx.name
    .step_name = "run",         // defaults to "run"
    .install = true,
    .register_run = true,
    .imports = &.{
        .{ .module_registry = "mylib" },
        .{ .zon_dep = "ziosh" },
    },
});
```

### `ctx.lib(opts) -> *Compile`

Build a library. Static by default; pass `.linkage = .dynamic` for
shared.

### `ctx.tests(opts) -> *Compile`

Declare a test compile, register a top-level test step.

```zig
_ = ctx.tests(.{
    .root = "src/main.zig",
    .step_name = "test",        // default
    .imports = &.{
        .{ .module_registry = "mylib" },
    },
});
```

### `ctx.testModules(opts) -> []const *Compile`

Create a test compile for every registered module and aggregate under
a single step.

```zig
_ = ctx.testModules(.{
    .step_name = "test",        // default
});
```

### `ctx.examples(pattern) -> []const *Compile`

Glob-walk the build root at build time. Pattern shape:
`<prefix>/*/<leaf>` (e.g. `examples/*/main.zig`). For each match,
register an executable named after the directory and a
`run-example-<name>` step. Aggregates them under `run-examples`.

For examples that need imports, use `ctx.examplesWithImports`:

```zig
_ = ctx.examplesWithImports("examples/*/main.zig", &.{
    .{ .module_registry = "mylib" },
});
```

### `ctx.releases(opts) -> []const *Compile`

Build one executable per release target. Installs each under
`zig-out/release/<target-dir>/`. `opts.targets` is a slice of `Target`
enum presets; `opts.custom_targets` is the escape hatch to
`std.Target.Query`. Release artifacts inherit all imports from the
template executable.

Presets: `.linux_x64`, `.linux_arm64`, `.darwin_x64`, `.darwin_arm64`,
`.windows_x64`, `.windows_arm64`.

### `ctx.help()`

Adds a `help` step that prints a tidy table of every registered
top-level step plus its description.

## Dependency resolution: the `Dep` type

Every helper that accepts imports uses a `[]const Dep`. `Dep` is a
union with three variants:

```zig
pub const Dep = union(enum) {
    module_registry: []const u8,  // resolved from ctx.module() registry
    zon_dep: []const u8,          // resolved from build.zig.zon
    direct: struct {              // a pre-built *Module
        name: []const u8,
        module: *std.Build.Module,
    },
};
```

Usage:

```zig
.imports = &.{
    .{ .module_registry = "mylib" },      // internal module
    .{ .zon_dep = "ziosh" },              // from build.zig.zon
    .{ .direct = .{ .name = "config", .module = config_mod } },  // explicit
},
```

## Build option helpers

Typed wrappers around `b.option()` with defaults. Top-level namespace
functions (not Context methods):

```zig
const emit_bench = zb.boolOption(b, "emit-bench", false, "Emit benchmark artifacts");
const mode = zb.enumOption(b, enum { native, wasm }, "runtime", .native, "App runtime mode");
const count = zb.intOption(b, u32, "count", 10, "Number of items");
const name = zb.stringOption(b, "name", null, "Override name");
```

## Drop down to raw `std.Build`

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

**What about module ordering?**

Modules must be registered with `ctx.module()` before they're
referenced. ziobuild will panic with a clear diagnostic if you
reference a module name that hasn't been registered yet.

**Why are there only six release presets?**

They cover the common shipping matrix. For anything else, use
`custom_targets` with a `std.Target.Query`.

**Does ziobuild support `--watch`?**

Not in v0.2. The watch story is a separate package.

**What Zig version?**

0.16.0. Pinned via `.zigversion`. The build API is a moving target.

## Compatibility

- **Zig**: 0.16.0 (tracked in CI; earlier versions are not supported).
- **Platforms**: tested on Linux (x86_64), macOS (x86_64, aarch64), Windows (x86_64).
- **Breaking changes**: pinned to the Zig 0.16 stable release cycle. A major-version bump in Zig may require a major-version bump here.

## Migration from v0.1 to v0.2

- `.deps` field renamed to `.imports` on `app`, `lib`, `tests` options.
- `.deps` type changed from `[]const []const u8` to `[]const Dep`. Use `.{ .zon_dep = "name" }` instead of `"name"`.
- New: `ctx.module()`, `ctx.testModules()`, `zb.boolOption()`, etc.

## License

MIT. Copyright Alessandro De Blasis.
