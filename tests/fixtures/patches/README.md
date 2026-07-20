# patches fixture

`dummy_dep/src/root.zig` is committed in its **pristine** (unpatched)
state on purpose.

`ctx.patch()` rewrites the dependency source in place, so a plain
`zig build` in this directory leaves the file transformed and the
working tree dirty. The integration tests restore the pristine text
before every build and put it back afterwards, which is what makes
the tests able to fail: if patching silently did nothing, the file
would still say `(unpatched)` and the assertions would trip.

Do not commit the patched text. It would turn the test back into a
tautology that passes whether or not the patch ran.
