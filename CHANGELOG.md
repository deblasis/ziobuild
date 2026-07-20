# Changelog

## v0.4.0

### Expressions & Conditional Patching

**`Expr` type** - composable build-time predicates for conditional logic:

```zig
const needs_fix = zb.Expr.zigVersion(.gte, "0.16.0")
    .andAlso(zb.Expr.targetOs(.linux), b.allocator);
```

Leaf constructors: `zigVersion`, `targetOs`, `targetArch`, `optimizeMode`, `envVar`, `literal`.
Combinators: `andAlso`, `orElse`, `not`.
Evaluate against current build state: `.evaluate(b, target, optimize)`.

**`ctx.patch()`** - conditionally apply `.patch` files to dependencies:

```zig
ctx.patch("my_dep", .{
    .file = "patches/my_dep/fix-zig-0.16.patch",
    .when = zb.Expr.zigVersion(.gte, "0.16.0"),
});
```

Patches are applied at dependency resolution time using `git apply`. Idempotent - already-applied patches are silently skipped. Conflicting patches fail with a clear error message. Requires `git` on `$PATH`.

### New public API

| Symbol | Type | Description |
|---|---|---|
| `zb.Expr` | `union(enum)` | Composable build-time expression |
| `zb.ExprCmp` | `enum` | Version comparison operator (`lt`, `lte`, `eq`, `gte`, `gt`, `neq`) |
| `zb.PatchOptions` | `struct` | Options for `ctx.patch()` |
| `zb.OverlayOptions` | `struct` | Options for `ctx.overlay()` |
| `ctx.patch()` | method | Register a conditional patch for a dependency |
| `ctx.overlay()` | method | Register a conditional file overlay for a dependency |

### Files added

- `src/expr.zig` - expression system
- `src/patch.zig` - patch application logic
- `tests/fixtures/patches/` - integration test fixture
- `examples/conditional_patching/` - working example with vendored dependency

## v0.3.0

- Deferred resolution: modules can be declared in any order.
- `Dep.mod` renamed from `module_registry`.
- `mod_imports` shorthand for importing modules by name.
- `import_all` flag to import all registered modules.
- `ctx.finalize()` for explicit resolution trigger.

## v0.2.0

- Initial public API: `init`, `Context`, `Dep`, `app`, `lib`, `tests`, `examples`, `releases`, `help`.
- Cross-compile presets: `Target.linux_x64`, `Target.darwin_arm64`, etc.
- Build option helpers: `boolOption`, `stringOption`, `enumOption`, `intOption`.

## v0.1.0

- Initial release.
