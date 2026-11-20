// The hull's hydrostatics, read off the hull as drawn: `Hull.enclosed`, the body its six panels,
// its transom and the sheet between its sheers enclose (hull.sv). At each load the hull is kept
// within the water up to its waterline, and each claim is an equation of integrals over the body
// in the water and its waterplane, read exactly off their B-reps: nothing is meshed, and the
// report gives each value with no error beside it.
//
//   - Draft: what the hull displaces at its stated waterline (dims.sv) floats the load, and is
//     no more than 1 % over it, so the waterline stands within about a millimetre of where it
//     floats.
//   - Stability: KM, the metacentre's height over the keel, is KB + BM: the centre of buoyancy's
//     height (the body's first moment in z over its volume) and the metacentric radius (the
//     waterplane's second moment about the centreline over the volume). The claim holds KM at
//     least KG plus the GM the boat needs at that load. The report prints KM in mm.
//
// `solventc --where immersed_design hydrostatics.sv` reads the waterplane's length and breadth
// (its bounds) and the wetted area (every face's area but the waterplane's) that dims.sv states.
//
// Coordinates, mm: x aft from the stem head, y to starboard, z up from the keel's datum.
unit mm
use std
use std.sets
use std.measures (volume)
use dims
use hull (Hull)

h := Hull()
keel := point
fix((0mm, 0mm, 0mm)) keel

// -- the design load: pilot, boat and gear, 156 kg ------------------------------------------------
water_design := std.sets.HalfSpace(keel, std.z, d: dims.draft_design)
immersed_design := solid({ p | p in h.enclosed; p in water_design })
claim volume(>= dims.design_load / dims.rho_sea) immersed_design
claim volume(<= 1.01 * dims.design_load / dims.rho_sea) immersed_design
claim integral(distance(keel, p, along: std.z) over p in immersed_design) / integral(1 over p in immersed_design) + integral(distance(p, h.centre)^2 over p in immersed_design.water_design) / integral(1 over p in immersed_design) >= dims.kg_design + dims.gm_design_min

// -- the full load: pilot, passenger and cargo, 312 kg ---------------------------------------------
water_full := std.sets.HalfSpace(keel, std.z, d: dims.draft_full)
immersed_full := solid({ p | p in h.enclosed; p in water_full })
claim volume(>= dims.full_load / dims.rho_sea) immersed_full
claim volume(<= 1.01 * dims.full_load / dims.rho_sea) immersed_full
claim integral(distance(keel, p, along: std.z) over p in immersed_full) / integral(1 over p in immersed_full) + integral(distance(p, h.centre)^2 over p in immersed_full.water_full) / integral(1 over p in immersed_full) >= dims.kg_full + dims.gm_full_min
