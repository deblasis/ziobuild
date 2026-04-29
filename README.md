# ziobuild

Declarative `build.zig` DSL. Comptime helpers that wrap `std.Build` and collapse 80+ line build files into a dozen calls.

> Status: scaffolding. The library is not yet implemented.

## What it will do

`build.zig` is the single biggest friction point in Zig. Even a small project (one binary, tests, two examples, three deps) needs 80+ lines of `addExecutable` / `addRunArtifact` / `b.step` / `dependOn` / `addImport` boilerplate. ziobuild offers thin helpers (`zb.app`, `zb.tests`, `zb.examples`, `zb.releases`, `zb.help`) that compose around raw `std.Build` steps. Nothing is hidden; each helper returns the underlying `*std.Build.Step.Compile` so callers can drop down at any time.

## Status

- [ ] Brainstorm and lock API
- [ ] Plan
- [ ] TDD implementation
- [ ] Functional example
- [ ] CI on Linux, Windows, macOS
- [ ] v0.1.0 release

## License

MIT. Copyright Alessandro De Blasis.
