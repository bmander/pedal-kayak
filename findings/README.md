# Findings for solventc

## Cut spiral bevel pairs converge or diverge with an unrelated solid (v0.1.24)

`hypoid_converges.sv` and `hypoid_diverges.sv` are the same drawing, `drive.sv` with its gears cut
(`Drive(teeth: 1)`), except for one line. The diverging file lacks
`hub := solid(std.sets.Ball(prop_c, r: 28mm))`, a ball at the tail's end that nothing else reads.

```sh
solventc findings/hypoid_converges.sv   # solved, 624 params, ~70 s; its five claims theorems
solventc findings/hypoid_diverges.sv    # did not solve: trust region collapsed (NaN), ~6 min
```

Run from the repository root. `use dims` and `use spiral_bevel.hypoid` resolve from the parent
directory.

What the drawing does: it places two `HypoidPair`s (offset 0, so spiral bevels) far from the
origin, about 2.25 m out and turned. Each pair's frame origin is coincident with a fixed point, its
gear axis parallel to a fixed line, and its pinion axis perpendicular to another, with bounds
choosing the sides. Related observations:

- Seating the same pairs with `seats` on held datums diverged in every configuration tried.
- Inside a larger assembly (with the hull's developable panels), the converging drawing diverged
  too.
- With a face family's running parameter in the document, the outcome changed again.
