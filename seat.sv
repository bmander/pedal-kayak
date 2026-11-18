// The recumbent seat and the pilot's leg, checked across 98% of adults: the 1st-percentile woman and
// the 99th-percentile man of ANSUR II, each with the seat slid to fit, each leg drawn at the
// pedal's far point (the knee straightest) and near point (the knee most bent).
//
// The leg is a two-link chain in the centreplane: the hip `h`, the knee `k` and the ball of the
// foot on the pedal spindle `f`. The thigh is 0.245 × stature (the usual segment proportion); the
// lower link, knee to the ball of the foot, is set by the leg's reach: at the far point the knee is
// `knee_far` short of straight and the ball of the foot `dims.reach_factor` × the functional leg
// length from the hip. The knee stands above the line from hip to pedal.
//
// The seat slides; the cranks stay put. Each pilot's hip is where `dims.sv` puts it for their leg.
// Drawn in `std.front`: its u is the hull's x (aft), its v the hull's z (up).
unit mm
use std
use std.sets
use dims
use std.solids

knee_far := 20deg                      // at the far point the knee is this far short of straight

// the lower link that reaches `reach` with the thigh `thigh` and the knee `knee_far` short of straight
component Leg(hip: point, pedal: point, thigh: Length, reach: Length) {
  lower := sqrt(reach^2 - thigh^2 * sin(knee_far)^2) - thigh * cos(knee_far)
  in std.front {
    k := point
    hip distance(thigh) k
    k distance(lower) pedal
    cw(hip, pedal, k)                  // the knee above the line from hip to pedal
    thigh_line := line(hip, k)
    shin_line := line(k, pedal)
  }
}

// One pilot: their hip on the seat, the pedal's far and near points, a leg at each.
component Pilot(stature: Length, fll: Length, hip_x: Length) {
  thigh := 0.245 * stature
  reach := dims.reach_factor * fll
  in std.front {
    bb := point
    fix((dims.bb_x, dims.bb_z)) bb
    h := point
    fix((hip_x, dims.hip_z)) h
    hbb := line(h, bb)                 // from the hip through the cranks' axle
    far := point                       // the pedal's far point: a crank beyond the axle
    far coincident hbb
    bb distance(dims.crank, along: hbb) far
    near := point                      // its near point: a crank short of it
    near coincident hbb
    bb distance(-dims.crank, along: hbb) near
  }
  out := Leg(h, far, thigh: thigh, reach: reach)
  bent := Leg(h, near, thigh: thigh, reach: reach)

  // the legs in space, for the picture: the extended one to starboard, the bent one to port, each
  // a thigh and a shin of rod, `leg_y` out from the centreline
  leg_y := 95mm
  hs := Out(h, d: leg_y)
  ks := Out(out.k, d: leg_y)
  fs := Out(far, d: leg_y)
  hp := Out(h, d: -leg_y)
  kp := Out(bent.k, d: -leg_y)
  fp := Out(near, d: -leg_y)
  s_thigh := line(hs.q, ks.q)
  s_shin := line(ks.q, fs.q)
  p_thigh := line(hp.q, kp.q)
  p_shin := line(kp.q, fp.q)
  starboard_thigh := solid(std.sets.Rod(s_thigh, r: 75mm))
  starboard_shin := solid(std.sets.Rod(s_shin, r: 50mm))
  port_thigh := solid(std.sets.Rod(p_thigh, r: 75mm))
  port_shin := solid(std.sets.Rod(p_shin, r: 50mm))
}

// a point `d` to starboard of `p`, in space
component Out(p: point, d: Length) {
  q := point
  p distance(d, along: std.y) q
  p distance(0mm, along: std.x) q
  p distance(0mm, along: std.z) q
}

// The seat at a hip station: the pan rising 12° forward of the hip, the back reclined 40° from
// upright behind it, each 12 mm plywood, `dims.seat_width` wide; its surface 90 under the hip joint.
component Seat(hip_x: Length) {
  pan_rise := 12deg
  recline := 40deg
  surface_z := dims.hip_z - 90mm
  pan_plane := plane
  fix(origin == (hip_x + 60mm, 0mm, surface_z)) pan_plane
  fix(dir == (0, 1, 0)) pan_plane.u
  fix(dir == (-cos(pan_rise), 0, sin(pan_rise))) pan_plane.v
  in pan_plane {
    a := point
    b := point
    c := point
    e := point
    fix((-dims.seat_width / 2, 0mm)) a
    fix((dims.seat_width / 2, 0mm)) b
    fix((dims.seat_width / 2, 420mm)) c
    fix((-dims.seat_width / 2, 420mm)) e
    pan_outline := line(a, b) -> line(b, c) -> line(c, e) -> line(e, a) -> close
  }
  pan := solid(std.solids.Prism(face(pan_outline), from: -12mm, to: 0mm))
  back_plane := plane
  fix(origin == (hip_x + 110mm, 0mm, surface_z)) back_plane
  fix(dir == (0, 1, 0)) back_plane.u
  fix(dir == (sin(recline), 0, cos(recline))) back_plane.v
  in back_plane {
    ka := point
    kb := point
    kc := point
    ke := point
    fix((-dims.seat_width / 2 + 20mm, 0mm)) ka
    fix((dims.seat_width / 2 - 20mm, 0mm)) kb
    fix((dims.seat_width / 2 - 20mm, 560mm)) kc
    fix((-dims.seat_width / 2 + 20mm, 560mm)) ke
    back_outline := line(ka, kb) -> line(kb, kc) -> line(kc, ke) -> line(ke, ka) -> close
  }
  back := solid(std.solids.Prism(face(back_outline), from: 0mm, to: 12mm))
}

// the two ends of the range, each with the seat where their leg puts it
small := Pilot(stature: 1483mm, fll: dims.fll_min, hip_x: dims.hip_x_min)
large := Pilot(stature: 1927mm, fll: dims.fll_max, hip_x: dims.hip_x_max)

// Each reaches the far point with the knee 20° short of straight, as the seat was set for.
claim distance(small.h, small.far) <= small.reach + 1mm and distance(small.h, small.far) >= small.reach - 1mm
claim distance(large.h, large.far) <= large.reach + 1mm and distance(large.h, large.far) >= large.reach - 1mm
// At the near point the knee bends no further than 110° from straight (70° inside): a recumbent's
// comfortable top of stroke.
claim angle(small.bent.thigh_line, small.bent.shin_line) <= 110deg
claim angle(large.bent.thigh_line, large.bent.shin_line) <= 110deg
