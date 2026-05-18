# ziobuild

Declarative `build.zig` DSL. Comptime helpers that wrap `std.Build` and collapse 80+ line build files into a dozen calls. Nothing is hidden: every helper that produces an artifact returns the underlying `*std.Build.Step.Compile` so you can drop down to raw `std.Build` whenever you want.

## The pitch

A typical project has one app, internal modules, tests, examples, and a release matrix. Vanilla `build.zig` for a multi-module project:

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
    // ... 40+ more lines for run, test, examples, releases
}
```

With ziobuild:

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });

    _ = ctx.module("mylib", .{ .root = "src/lib.zig" });

    const app = ctx.app(.{
        .root = "src/main.zig",
        .mod_imports = &.{"mylib"},
    });
    _ = ctx.tests(.{
        .root = "src/main.zig",
        .mod_imports = &.{"mylib"},
    });
    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{ .linux_x64, .darwin_arm64, .windows_x64 },
    });
    ctx.help();
}
```

14 lines. Same artifacts, same step graph.

## Install

`build.zig.zon`:

```zig
.dependencies = .{
    .ziobuild = .{
        .url = "https://github.com/deblasis/ziobuild/archive/refs/tags/v0.4.0.tar.gz",
        .hash = "...",  // zig prints the right value on first fetch
    },
},
```

`build.zig`:

```zig
const zb = @import("ziobuild");
```

## What's new in v0.4

- **`Expr` & `ctx.patch()`**: composable build-time expressions and conditional dependency patching.
- **`ctx.overlay()`**: replace files in a dependency's source tree without git.
- **`Expr.envVar()`**: branch on environment variables (e.g., `CI`, `TARGET`).

## What's new in v0.3

- **Deferred resolution**: modules can be declared in any order.
- **`Dep.mod`**: renamed from `module_registry` -- shorter, cleaner.
- **`mod_imports`**: shorthand `[]const []const u8` for the common case of importing modules by name.
- **`import_all`**: import ALL registered modules in one flag.
- **`ctx.finalize()`**: explicit resolution trigger (usually unnecessary since `help()` auto-finalizes).

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

### Multi-module project (order-independent)

```zig
const std = @import("std");
const zb = @import("ziobuild");

pub fn build(b: *std.Build) void {
    const ctx = zb.init(b, .{ .name = "myapp" });

    // Order doesn't matter -- deferred resolution
    _ = ctx.module("core", .{ .root = "src/core.zig" });
    _ = ctx.module("utils", .{
        .root = "src/utils.zig",
        .mod_imports = &.{"core"},
    });

    const app = ctx.app(.{
        .root = "src/main.zig",
        .mod_imports = &.{ "core", "utils" },
    });

    _ = ctx.testModules(.{});
    _ = ctx.examples("examples/*/main.zig");
    _ = ctx.releases(.{
        .of = app,
        .targets = &.{ .linux_x64, .darwin_arm64, .windows_x64 },
    });
    ctx.help();
}
```

### Aggregator module that imports everything

```zig
_ = ctx.module("cli", .{
    .root = "src/cli.zig",
    .import_all = true,  // gets core, utils, etc. automatically
});
```

## API

### `zb.init(b, opts) -> Context`

Entry point. `opts.name` is the default executable name.

### `ctx.module(name, opts) -> *Module`

Register a named module. **Order-independent** (deferred resolution).

Three ways to declare imports:

| Field | Type | Description |
|---|---|---|
| `imports` | `[]const Dep` | Full control -- `Dep.mod`, `Dep.zon_dep`, `Dep.direct` |
| `mod_imports` | `[]const []const u8` | Shorthand: each string imports that module by name |
| `import_all` | `bool` | Import ALL registered modules (self excluded) |

### `ctx.app(opts) -> *Compile`

Build an executable. Also supports `mod_imports` and `import_all`.

### `ctx.lib(opts) -> *Compile`

Build a library. Also supports `mod_imports` and `import_all`.

### `ctx.tests(opts) -> *Compile`

Declare a test compile. Also supports `mod_imports` and `import_all`.

### `ctx.testModules(opts) -> []const *Compile`

Create a test compile for every registered module and aggregate under a single step.

### `ctx.examples(pattern) -> []const *Compile`

Glob-walk and register one executable per match. Use `examplesWithImports` for imports.

### `ctx.releases(opts) -> []const *Compile`

Build one executable per release target. Presets: `.linux_x64`, `.linux_arm64`, `.darwin_x64`, `.darwin_arm64`, `.windows_x64`, `.windows_arm64`.

### `ctx.help()`

Print a tidy step table. Also triggers deferred import resolution -- call this last.

### `ctx.finalize()`

Explicit resolution trigger. Only needed if you don't call `help()`.

### `ctx.patch(dep_name, opts)`

Register a conditional patch for a dependency. `opts.file` is the patch path (relative to build root), `opts.when` is an `Expr`, and `opts.strip` is the `-p` level (defaults to 1). Requires `git`.

### `ctx.overlay(dep_name, opts)`

Register a conditional file overlay for a dependency. `opts.dir` is the overlay directory (relative to build root), `opts.when` is an `Expr`. Files from `dir` are copied into the dep's source tree. No git required.

### `Expr`

Composable build-time expression. See [Expressions & Conditional Patching](#expressions--conditional-patching).

## Dependency resolution: the `Dep` type

```zig
pub const Dep = union(enum) {
    mod: []const u8,       // resolved from ctx.module() registry
    zon_dep: []const u8,   // resolved from build.zig.zon
    direct: struct {       // a pre-built *Module
        name: []const u8,
        module: *std.Build.Module,
    },
};
```

### Deferred resolution

Imports are resolved lazily, not at registration time. **Modules can be declared in any order.** Resolution is incremental — calling `ensureResolved()` (via `help()`, `testModules()`, `releases()`, or `finalize()`) at any point only resolves entries registered so far; later registrations are processed on the next call. This means `testModules()` can safely be called before `app()` without skipping the app's imports.

### `mod_imports` shorthand

```zig
.mod_imports = &.{"core", "utils", "models"}
// equivalent to:
// .imports = &.{ .{ .mod = "core" }, .{ .mod = "utils" }, .{ .mod = "models" } }
```

### `import_all` flag

Import ALL registered modules by name. Self-import excluded for `ctx.module()`.

## Build option helpers

```zig
const emit_bench = zb.boolOption(b, "emit-bench", false, "Emit benchmark artifacts");
const mode = zb.enumOption(b, enum { native, wasm }, "runtime", .native, "App runtime mode");
const count = zb.intOption(b, u32, "count", 10, "Number of items");
const name = zb.stringOption(b, "name", null, "Override name");
```

## Expressions & Conditional Patching

ziobuild provides a composable `Expr` type for build-time predicates and a `ctx.patch()` API that conditionally applies `.patch` files to dependency source trees.

### The `Expr` type

Leaf constructors create primitive predicates:

| Constructor | Evaluates against |
|---|---|
| `Expr.zigVersion(.gte, "0.16.0")` | Zig compiler version |
| `Expr.targetOs(.linux)` | Resolved target OS |
| `Expr.targetArch(.x86_64)` | Resolved target arch |
| `Expr.optimizeMode(.ReleaseFast)` | Context optimize mode |
| `Expr.envVar("CI", "true")` | Environment variable |
| `Expr.literal(true)` | Always true/false (also useful with pre-resolved build options) |

Combinators compose them:

```zig
const needs_fix = Expr.zigVersion(.gte, "0.16.0")
    .andAlso(Expr.targetOs(.linux), b.allocator);

const is_dev = Expr.optimizeMode(.Debug)
    .orElse(Expr.optimizeMode(.ReleaseSafe), b.allocator);

const not_windows = Expr.targetOs(.windows).not(b.allocator);
```

Evaluate against the current build:

```zig
if (needs_fix.evaluate(b, ctx.target, ctx.optimize)) {
    // conditional build logic
}
```

Version comparison operators: `lt`, `lte`, `eq`, `gte`, `gt`, `neq`.

### Conditional patching

Apply `.patch` files to dependencies when a condition holds:

```zig
ctx.patch("my_dep", .{
    .file = "patches/my_dep/fix-zig-0.16.patch",
    .when = zb.Expr.zigVersion(.gte, "0.16.0"),
    .strip = 1,  // -p1 (default)
});
```

Multiple patches per dep — applied in registration order:

```zig
ctx.patch("my_dep", .{
    .file = "patches/my_dep/fix-zig-0.16.patch",
    .when = zb.Expr.zigVersion(.gte, "0.16.0"),
});
ctx.patch("my_dep", .{
    .file = "patches/my_dep/fix-linux.patch",
    .when = zb.Expr.targetOs(.linux),
});
```

Composed conditions:

```zig
ctx.patch("my_dep", .{
    .file = "patches/my_dep/fix-linux-0.16.patch",
    .when = zb.Expr.zigVersion(.gte, "0.16.0")
        .andAlso(zb.Expr.targetOs(.linux), b.allocator),
});
```

**How it works:** Patches are applied at dependency resolution time using `git apply`. The operation is idempotent — if a patch is already applied, it is silently skipped. If a patch conflicts with the source (neither forward nor reverse applies), the build fails with a clear error message. Requires `git` on `$PATH`.

### File overlays (no git)

Replace files in a dependency's source tree without `git`. Copy files from an overlay directory into the dep:

```zig
ctx.overlay("my_dep", .{
    .dir = "overlays/my_dep",
    .when = zb.Expr.targetOs(.windows),
});
```

The overlay directory structure mirrors the dependency's source tree. Every file in `overlays/my_dep/` overwrites the corresponding file in the dep. No git required — uses direct file copies.

```text
overlays/my_dep/
  src/root.zig        ← replaces dep's src/root.zig
  src/platform.zig    ← replaces dep's src/platform.zig
```

**Filesystem convention:** Store patches in `patches/<dep-name>/` at your project root. Patches are standard unified diffs.

See `examples/conditional_patching/` for a complete working example.

## Drop down to raw `std.Build`

Every helper returns the underlying `*Compile`. Use it.

```zig
const app = ctx.app(.{ .root = "src/main.zig" });
app.root_module.addCSourceFile(.{ .file = b.path("src/foo.c") });
app.linkLibC();
```

## Migration from v0.3 to v0.4

- New: `Expr` type for composable build-time predicates.
- New: `ctx.patch()` for conditional dependency patching (requires git).
- New: `ctx.overlay()` for conditional file overlays (no git needed).
- New: `Expr.envVar()` for environment-based conditions.
- Removed: `Expr.buildOptionBool` / `Expr.buildOptionString` (broken — use `Expr.literal(resolved_value)` or plain Zig conditionals).

## Migration from v0.2 to v0.3

- `Dep.module_registry` renamed to `Dep.mod`.
- Modules can now be declared in any order (deferred resolution).
- New: `mod_imports` and `import_all` fields on `module`, `app`, `tests`, `lib`.
- `ctx.resolveDeps()` removed from public API (internal, called automatically).
- New: `ctx.finalize()`.

## License

MIT. Copyright Alessandro De Blasis.
