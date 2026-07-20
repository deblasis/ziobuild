# overlay fixture

`dummy_dep/src/root.zig` is committed in its **pristine** (original)
state on purpose, and it must differ from
`overlays/dummy_dep/src/root.zig`.

`ctx.overlay()` copies over the dependency source in place, so a plain
`zig build` in this directory leaves the file transformed and the
working tree dirty. The integration tests restore the pristine text
before every build and put it back afterwards, which is what makes
the tests able to fail: if the overlay silently did nothing, the file
would still say `(original)` and the assertions would trip.

Do not commit the overlaid text. It would turn the test back into a
tautology that passes whether or not the overlay ran.
