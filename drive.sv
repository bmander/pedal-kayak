// The pedal kayak's drive: the cranks, two spiral bevel stages, the line shaft, the CV joint and the
// hinged tail with its propeller. Every number is `dims.sv`'s. Coordinates are the hull's: x aft
// from the stem head, y to starboard, z up from the keel's lowest point.
//
// **The datums.** The cranks turn on `crank_axle`, athwartships through `bb`. The line shaft runs
// from `low`, over the keel at the foot of the pedal tower, to the CV joint `joint` at the skeg's
// heel. The tower shaft runs from `bb` down to `low`, square to the line shaft, so both bevel stages
// are square pairs whose axes meet: stage 1 at `bb`, stage 2 at `low`.
//
// **The pairs** are `spiral_bevel/hypoid.sv`'s `HypoidPair` with no offset: a spiral bevel pair,
// laid out on its pitch cones and cut by a generating crown. Each is placed by what it does, as
// geomsolver's bicycle shaft drive places its pairs: its frame's origin (the gear's apex) where
// the two shafts meet, its gear's axis along the driving shaft, its pinion's axis along the driven
// one. Bounds say which side each member stands on. With no offset, the face mill's pressure shift
// is found where the pinion's two flanks stand equally far from undercut.
//
// **The tail** hangs from the joint, `dims.tail_down` below level, its propeller's centre where
// `dims.prop_z` puts it: `dims.prop_cover` under the design waterline.
unit mm
use std
use std.sets
use std.solids (cut)
use dims
use mech
use spiral_bevel.hypoid (HypoidPair)
use drive_parts (Mechanism)

component Drive(teeth: Int) {
  // -- the datums: held, every one, so the pairs seated on them start where they stand ----------
  bb := point hint((2250, 0, 330))
  fix((dims.bb_x, 0mm, dims.bb_z)) bb
  bb_s := point hint((2250, 100, 330))           // a point along the crank axle, to starboard
  fix((dims.bb_x, 100mm, dims.bb_z)) bb_s
  crank_axle := line(bb, bb_s)
  joint := point hint((5798, 0, 30))
  fix((dims.joint_x, 0mm, dims.joint_z)) joint
  low := point hint((2247, 0, 72))               // the tower's foot on the line shaft
  fix((dims.low_x, 0mm, dims.lower_box_z)) low
  line_axis := line(low, joint)
  tower_axis := line(low, bb)
  claim tower_axis perpendicular line_axis

  // Each pair is placed by what it does: its frame's origin (the gear's apex) where its two shafts
  // meet, its gear's axis along the driving shaft, its pinion's axis square to the third datum
  // direction, so along the driven shaft; bounds say which side each member stands. (Seating the
  // pairs with `seats` on these datums diverged in v0.1.24; these relations converge.)

  // -- where each member's mean point stands: its mate's mean pitch radius from the apex ----------
  gear_1 := point hint((2250, 22.5, 330))        // the crank's gear, to starboard on the axle
  fix((dims.bb_x, dims.r_tower_pinion, dims.bb_z)) gear_1
  pinion_1 := point hint((2250, 0, 274))         // the tower's pinion, down the tower
  fix((dims.bb_x + dims.r_crank_gear * dims.down_x, 0mm, dims.bb_z + dims.r_crank_gear * dims.down_z)) pinion_1
  gear_2 := point hint((2247, 0, 87))            // the tower's gear, up the tower from the keel's box
  fix((dims.low_x - dims.r_line_pinion * dims.down_x, 0mm, dims.lower_box_z - dims.r_line_pinion * dims.down_z)) gear_2
  pinion_2 := point hint((2289, 0, 72))          // the line shaft's pinion, aft along it
  fix((dims.low_x + dims.r_tower_gear * dims.aft_x, 0mm, dims.lower_box_z + dims.r_tower_gear * dims.aft_z)) pinion_2

  // -- the gears: cut (teeth: 1), or blanks of their size for the assembly (teeth: 0) -------------
  when teeth == 1 {
    // -- stage 1: the crank's gear drives the tower's pinion, at the top of the tower --------------
    // the gear to starboard along the crank axle, the pinion down the tower. Which side the gear
  // stands decides which way the line shaft turns: here forward pedalling (the cranks turning
  // about −y, a bicycle's way seen from starboard) turns the tower about −z and the line shaft
  // about +x, aft: counter-clockwise seen from astern, so the propeller is left-handed (prop.sv).
    // Start both zero-offset pairs at their analytical pitch-cone values. The solver
    // still determines the module, radius and angle against the generating crown.
    stage_1 := HypoidPair(pinion_teeth: dims.z_tower_pinion, gear_teeth: dims.z_crank_gear,
      mn: hint(mech.mn_1), rp: hint(dims.r_tower_pinion), pa: hint(mech.pinion_angle_1),
      mean_module: dims.m_1, shaft_angle: 90deg, offset: 0mm, spiral_angle: 25deg,
      backlash: 0.06mm, tip_relief: 0.25mm, end_relief: 0.25mm, pressure_shift: hint(-1.3deg),
      cutter_radius: 94.515mm, least: hint(0.2))
    stage_1.margins.pinion_inner regular(stage_1.least, by: stage_1.margins.pinion_cut) within stage_1.margins.pinion
    stage_1.margins.pinion_outer regular(stage_1.least, by: stage_1.margins.pinion_cut) within stage_1.margins.pinion
    stage_1.std.origin coincident bb
    stage_1.gear_member.ax parallel crank_axle
    stage_1.pinion_member.ax perpendicular line_axis
    bb distance(>= 0mm, along: std.y) stage_1.gear_member.foot      // the gear to starboard
    bb distance(<= 0mm, along: std.z) stage_1.pinion_member.foot    // the pinion below

    // -- stage 2: the tower's gear drives the line shaft's pinion, over the keel ----------------------
    // the gear up the tower, the pinion aft along the line shaft
    stage_2 := HypoidPair(pinion_teeth: dims.z_line_pinion, gear_teeth: dims.z_tower_gear,
      mn: hint(mech.mn_2), rp: hint(dims.r_line_pinion), pa: hint(mech.pinion_angle_2),
      mean_module: dims.m_2, shaft_angle: 90deg, offset: 0mm, spiral_angle: 25deg,
      backlash: 0.05mm, tip_relief: 0.2mm, end_relief: 0.2mm, pressure_shift: hint(-1.3deg),
      cutter_radius: 75.6122mm, least: hint(0.2))
    stage_2.margins.pinion_inner regular(stage_2.least, by: stage_2.margins.pinion_cut) within stage_2.margins.pinion
    stage_2.margins.pinion_outer regular(stage_2.least, by: stage_2.margins.pinion_cut) within stage_2.margins.pinion
    stage_2.std.origin coincident low
    stage_2.gear_member.ax parallel tower_axis
    stage_2.pinion_member.ax perpendicular crank_axle
    low distance(>= 0mm, along: std.z) stage_2.gear_member.foot     // the gear above, on the tower
    low distance(>= 0mm, along: std.x) stage_2.pinion_member.foot   // the pinion aft, on the line shaft

    // the gears, as cut
    crank_gear := solid(stage_1.gear_member.body)
    tower_pinion := solid(stage_1.pinion_member.body)
    tower_gear := solid(stage_2.gear_member.body)
    line_pinion := solid(stage_2.pinion_member.body)
    claim gear_1 coincident stage_1.gear_member.foot
    claim pinion_1 coincident stage_1.pinion_member.foot
    claim gear_2 coincident stage_2.gear_member.foot
    claim pinion_2 coincident stage_2.pinion_member.foot
  }
  when teeth == 0 {
    // each member's envelope (mech.sv): a gear a ring from its toe's tip to its heel's back, a
    // pinion a solid of its tip radius over the same run, along its own axis from the apex
    g1a := point hint((2250, 18, 330))
    fix((dims.bb_x, mech.crank_gear_a0, dims.bb_z)) g1a
    g1b := point hint((2250, 33, 330))
    fix((dims.bb_x, mech.crank_gear_a1, dims.bb_z)) g1b
    g1 := line(g1a, g1b)
    crank_gear_blank := solid(std.sets.Rod(g1, r: mech.crank_gear_tip))
    construction g1_bore := solid(std.sets.Rod(g1, r: mech.crank_gear_rin))
    g1_bore cut crank_gear_blank
    p1a := point hint((2250, 0, 279))
    fix((dims.bb_x + mech.tower_pinion_a0 * dims.down_x, 0mm, dims.bb_z + mech.tower_pinion_a0 * dims.down_z)) p1a
    p1b := point hint((2250, 0, 265))
    fix((dims.bb_x + mech.tower_pinion_a1 * dims.down_x, 0mm, dims.bb_z + mech.tower_pinion_a1 * dims.down_z)) p1b
    p1 := line(p1a, p1b)
    tower_pinion_blank := solid(std.sets.Rod(p1, r: mech.tower_pinion_tip))
    g2a := point hint((2247, 0, 84))
    fix((dims.low_x - mech.tower_gear_a0 * dims.down_x, 0mm, dims.lower_box_z - mech.tower_gear_a0 * dims.down_z)) g2a
    g2b := point hint((2247, 0, 95))
    fix((dims.low_x - mech.tower_gear_a1 * dims.down_x, 0mm, dims.lower_box_z - mech.tower_gear_a1 * dims.down_z)) g2b
    g2 := line(g2a, g2b)
    tower_gear_blank := solid(std.sets.Rod(g2, r: mech.tower_gear_tip))
    construction g2_bore := solid(std.sets.Rod(g2, r: mech.tower_gear_rin))
    g2_bore cut tower_gear_blank
    p2a := point hint((2285, 0, 72))
    fix((dims.low_x + mech.line_pinion_a0 * dims.aft_x, 0mm, dims.lower_box_z + mech.line_pinion_a0 * dims.aft_z)) p2a
    p2b := point hint((2296, 0, 71))
    fix((dims.low_x + mech.line_pinion_a1 * dims.aft_x, 0mm, dims.lower_box_z + mech.line_pinion_a1 * dims.aft_z)) p2b
    p2 := line(p2a, p2b)
    line_pinion_blank := solid(std.sets.Rod(p2, r: mech.line_pinion_tip))
  }

  // -- the tail --------------------------------------------------------------------------------------
  prop_c := point hint((6308, 0, -72))
  std.origin distance(0mm, along: std.y) prop_c
  std.origin distance(dims.prop_z, along: std.z) prop_c
  joint distance(dims.tail) prop_c
  joint distance(>= 0mm, along: std.x) prop_c
  tail_axis := line(joint, prop_c)

  // -- the hardware: the boxes, shafts, strut, heel, gimbal and tail, drawn in drive_parts.sv -------
  mechanism := Mechanism()
  // a stand-in for the propeller's hub, which prop.sv draws. (In solventc v0.1.24 the cut pairs'
  // solve converged with this solid present and diverged without it: see findings/.)
  hub := solid(std.sets.Ball(prop_c, r: 28mm))

  // -- the cranks and pedals: arms in planes q_half each side, opposite, drawn along the line from
  // the drawn pilot's hip through the axle (`dims.crank_ux`, `dims.crank_uz`)
  ca := dims.crank * dims.crank_ux
  cz := dims.crank * dims.crank_uz
  s_root := point hint((2250, 70, 330))
  fix((dims.bb_x, dims.q_half, dims.bb_z)) s_root
  s_tip := point hint((2384, 70, 407))
  fix((dims.bb_x + ca, dims.q_half, dims.bb_z + cz)) s_tip
  s_pedal := point hint((2384, 160, 407))
  fix((dims.bb_x + ca, dims.q_half + dims.pedal_width, dims.bb_z + cz)) s_pedal
  p_root := point hint((2250, -70, 330))
  fix((dims.bb_x, -dims.q_half, dims.bb_z)) p_root
  p_tip := point hint((2116, -70, 252))
  fix((dims.bb_x - ca, -dims.q_half, dims.bb_z - cz)) p_tip
  p_pedal := point hint((2116, -160, 252))
  fix((dims.bb_x - ca, -dims.q_half - dims.pedal_width, dims.bb_z - cz)) p_pedal
  s_arm := line(s_root, s_tip)
  p_arm := line(p_root, p_tip)
  s_spindle := line(s_tip, s_pedal)
  p_spindle := line(p_tip, p_pedal)
  starboard_crank := solid(std.sets.Rod(s_arm, r: 8mm))
  port_crank := solid(std.sets.Rod(p_arm, r: 8mm))
  starboard_pedal := solid(std.sets.Rod(s_spindle, r: 16mm))
  port_pedal := solid(std.sets.Rod(p_spindle, r: 16mm))

}

// the teeth cut (1), or blanks (0): `solventc drive.sv --set teeth=0` draws the drive in a second
teeth := 1
drive := Drive(teeth: teeth)

// The propeller is drawn by prop.sv and placed with this drive in kayak.sv: its blades are a face
// family over a running number, which this file, cutting its gears, leaves out.
