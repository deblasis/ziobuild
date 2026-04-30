# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
