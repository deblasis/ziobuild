# AGENTS.md

Build and development instructions for AI coding agents working on this repository.

## What this is

ziobuild: declarative `build.zig` DSL. Replaces 80+ line build files with a dozen calls. Every helper returns the underlying `*std.Build.Step.Compile` so you can drop down to raw `std.Build` whenever you want.

## Build

Requires Zig 0.16.

```
zig build
```

## Test

```
zig build test --summary all
```

Tests include both unit tests (in `src/*.zig`) and integration tests (in `tests/integration.zig`) that spawn child `zig build` processes in fixture directories and verify artifacts on disk.

## Run example

```
cd examples/minimal && zig build
```

## Format check

```
zig fmt --check src tests examples build.zig
```

## Project layout

```
src/
  root.zig          public re-exports (init, Context, Target, CustomTarget, options types)
  context.zig       Context: bundles *Build, target, optimize, project name
  app.zig           Context.app: build an executable
  lib.zig           Context.lib: build a library
  tests.zig         Context.tests: declare a test step
  examples_glob.zig Context.examples: walk pattern, register one exe per match
  releases.zig      Context.releases: cross-compile release matrix
  help.zig          Context.help: pretty-print available steps
  deps.zig          resolve dep names against build.zig.zon
  target.zig        cross-compile target presets (linux, darwin, windows)
tests/
  integration.zig          end-to-end fixture tests
  fixtures/smoke/          minimal build.zig using ziobuild
  fixtures/kitchen_sink/   full-featured build (app, lib, tests, examples, releases, help)
examples/
  minimal/                 headline README example
build.zig           build configuration
build.zig.zon       package manifest
```

## Key conventions

- Every public symbol has a doc comment.
- Errors are explicit and named. No anonymous error sets at API boundaries.
- Commits: author `Alessandro De Blasis <alex@deblasis.net>`, no AI co-author trailers.
- Code style follows Mitchell Hashimoto / Ghostty conventions.
