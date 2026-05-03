# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-05-03

### Added

- **Deferred resolution**: modules can be declared in any order. Imports are resolved lazily when the build graph is finalized (via `help()`, `testModules()`, `releases()`, or `finalize()`).
- **`Dep.mod`**: renamed from `Dep.module_registry` — shorter, cleaner.
- **`mod_imports`**: new field on `module`, `app`, `tests`, `lib` options — shorthand `[]const []const u8` for the common case of importing modules by name.
- **`import_all`**: new field on `module`, `app`, `tests`, `lib` options — import ALL registered modules in one flag (self-import excluded for `ctx.module()`).
- **`ctx.finalize()`**: explicit resolution trigger. Usually unnecessary since `help()` auto-finalizes.
- **New test fixtures**: `modules_reverse` (order independence), `mod_imports` (shorthand), `import_all` (bulk import).

### Changed

- **Breaking**: `Dep.module_registry` renamed to `Dep.mod`.
- **Breaking**: `ctx.resolveDeps()` removed from public API (now internal, called automatically during deferred resolution).
- All helpers (`app`, `lib`, `tests`, `module`) now defer import resolution instead of resolving eagerly.
- `ctx.help()` now calls `ensureResolved()` before registering the help step.
- `ctx.testModules()` now calls `ensureResolved()` before iterating the module registry.
- `ctx.releases()` now calls `ensureResolved()` before reading the template's import table.
- **Fixed**: `ensureResolved()` is incremental — calling it before all registrations are complete (e.g. `testModules()` before `app()`) no longer skips later pending imports. Safe to call at any point.
- `resolveDepsNow()` shared helper eliminates Dep resolution code duplication.

## [0.2.0] - 2026-05-03

### Added

- **Module registry**: `ctx.module(name, opts)` registers internal modules that can be referenced by name in `imports`.
- **Unified `Dep` type**: `Dep` union with `.module_registry`, `.zon_dep`, `.direct` variants replaces the old string-only `deps`.
- **`ctx.testModules(opts)`**: creates a test compile for every registered module and aggregates them under a single step.
- **`ctx.examplesWithImports(pattern, imports)`**: like `examples()` but attaches imports to each example.
- **Named run steps**: `ctx.app(.{ .step_name = "run-tool", ... })` avoids collisions when building multiple executables.
- **Build option helpers**: `zb.boolOption()`, `zb.stringOption()`, `zb.enumOption()`, `zb.intOption()` wrap `b.option()` with defaults.
- **`releases()` carries imports**: release artifacts now inherit all imports from the template module.
- **Field rename**: `deps` → `imports` across all helpers for clarity.
- **New test fixtures**: `modules` (module registry + cross-module imports), `multi_exe` (named run steps + build options).

### Changed

- **Breaking**: `.deps` field renamed to `.imports` on `app`, `lib`, `tests` options.
- **Breaking**: `.deps`/`.imports` now accepts `[]const Dep` instead of `[]const []const u8`.
- `releases()` now correctly propagates imports from the template executable to all cross-compiled artifacts.

## [0.1.0] - 2025-04-30

### Added

- Declarative `build.zig` DSL: `init`, `app`, `lib`, `tests`, `examples`, `releases`.
- `Context` with comptime options for name, version, license.
- `examples()` glob-based discovery: `examples/*/main.zig` pattern.
- `releases()` cross-compile matrix with preset `Target` enum and `CustomTarget` escape hatch.
- Automatic `run-example-*` and aggregate `run-examples` steps.
- `help()` step listing all available top-level steps.
- `Target` presets: linux_x64, darwin_arm64, windows_x64, and more.
- Doc comments on all public symbols.
- CI workflow (fmt, test) for Linux, Windows, macOS.
- AGENTS.md for LLM-assisted development.
- CONTRIBUTING.md and FUNDING.yml.
