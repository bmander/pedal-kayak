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
use dims
use spiral_bevel.hypoid (HypoidPair)

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
    stage_1 := HypoidPair(pinion_teeth: dims.z_tower_pinion, gear_teeth: dims.z_crank_gear,
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
    // each a disc on its shaft, its face width about its mean point, out to its mean tip
    g1a := point hint((2250, 13.5, 330))
    fix((dims.bb_x, dims.r_tower_pinion - dims.b_1 / 2, dims.bb_z)) g1a
    g1b := point hint((2250, 31.5, 330))
    fix((dims.bb_x, dims.r_tower_pinion + dims.b_1 / 2, dims.bb_z)) g1b
    g1 := line(g1a, g1b)
    crank_gear_blank := solid(std.sets.Rod(g1, r: dims.r_crank_gear + dims.m_1))
    p1 := line(pinion_1, bb)
    tower_pinion_blank := solid(std.sets.Rod(p1, r: dims.r_tower_pinion + dims.m_1))
    g2 := line(low, gear_2)
    tower_gear_blank := solid(std.sets.Rod(g2, r: dims.r_tower_gear + dims.m_2))
    p2 := line(low, pinion_2)
    line_pinion_blank := solid(std.sets.Rod(p2, r: dims.r_line_pinion + dims.m_2))
  }

  // -- the tail --------------------------------------------------------------------------------------
  prop_c := point hint((6308, 0, -72))
  std.origin distance(0mm, along: std.y) prop_c
  std.origin distance(dims.prop_z, along: std.z) prop_c
  joint distance(dims.tail) prop_c
  joint distance(>= 0mm, along: std.x) prop_c
  tail_axis := line(joint, prop_c)

  // -- the parts -------------------------------------------------------------------------------------
  // the shafts, each a rod between the feet of the members it carries
  axle_p := point hint((2250, -90, 330))
  bb distance(-90mm, along: std.y) axle_p
  bb distance(0mm, along: std.x) axle_p
  bb distance(0mm, along: std.z) axle_p
  axle_s := point hint((2250, 90, 330))
  bb distance(90mm, along: std.y) axle_s
  bb distance(0mm, along: std.x) axle_s
  bb distance(0mm, along: std.z) axle_s
  axle_line := line(axle_p, axle_s)
  axle := solid(std.sets.Rod(axle_line, r: 10mm))
  tower_line := line(gear_2, pinion_1)
  tower_shaft := solid(std.sets.Rod(tower_line, r: dims.tower_d / 2))
  line_seg := line(pinion_2, joint)
  line_shaft := solid(std.sets.Rod(line_seg, r: dims.line_od / 2))

  // the midway bearing: a pillow block on the tunnel's top, at the middle of the shaft's run
  run := dims.r_tower_gear + (dims.line_length - dims.r_tower_gear) / 2
  mb_a := point hint((4020, 0, 51))
  fix((dims.low_x + (run - 15mm) * dims.aft_x, 0mm, dims.lower_box_z + (run - 15mm) * dims.aft_z)) mb_a
  mb_b := point hint((4050, 0, 51))
  fix((dims.low_x + (run + 15mm) * dims.aft_x, 0mm, dims.lower_box_z + (run + 15mm) * dims.aft_z)) mb_b
  mb_line := line(mb_a, mb_b)
  midway_bearing := solid(std.sets.Rod(mb_line, r: 26mm))

  // the CV joint, and the tail's tube to the propeller's hub
  cv := solid(std.sets.Ball(joint, r: 30mm))
  tube_line := line(joint, prop_c)
  tail_tube := solid(std.sets.Rod(tube_line, r: 20mm))
  // a stand-in for the propeller's hub, which prop.sv draws. (In solventc v0.1.24 the cut pairs'
  // solve converged with this solid present and diverged without it: see the README.)

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
  starboard_crank := solid(std.sets.Rod(s_arm, r: 11mm))
  port_crank := solid(std.sets.Rod(p_arm, r: 11mm))
  starboard_pedal := solid(std.sets.Rod(s_spindle, r: 16mm))
  port_pedal := solid(std.sets.Rod(p_spindle, r: 16mm))

  // -- the housings: the crank's pod round stage 1, the tower's column, the keel's box round stage 2
  pod_p := point hint((2250, -45, 330))
  fix((dims.bb_x, -45mm, dims.bb_z)) pod_p
  pod_s := point hint((2250, 50, 330))
  fix((dims.bb_x, 50mm, dims.bb_z)) pod_s
  pod_line := line(pod_p, pod_s)
  crank_pod := solid(std.sets.Rod(pod_line, r: dims.r_crank_gear + dims.m_1 + 8mm))
  column_line := line(gear_2, pinion_1)
  tower_column := solid(std.sets.Rod(column_line, r: 24mm))
  box_low := point hint((2247, 0, 40))
  fix((dims.low_x, 0mm, dims.lower_box_z - 32mm)) box_low
  box_high := point hint((2246, 0, 112))
  fix((dims.low_x + 40mm * dims.down_x * -1, 0mm, dims.lower_box_z + 40mm)) box_high
  box_line := line(box_low, box_high)
  keel_box := solid(std.sets.Rod(box_line, r: dims.r_tower_gear + dims.m_2 + 8mm))

  // -- the boom: from the forward bulkhead to the crank's pod, on the centreline between the feet
  boom_fwd := point hint((1606, 0, 330))
  fix((dims.boom_x, 0mm, dims.bb_z)) boom_fwd
  boom_aft := point hint((2180, 0, 330))
  fix((dims.bb_x - dims.r_crank_gear - dims.m_1, 0mm, dims.bb_z)) boom_aft
  boom_line := line(boom_fwd, boom_aft)
  boom := solid(std.sets.Rod(boom_line, r: 22mm))

  // -- the gimbal: the tilt pin athwartships through the joint, the steering stock through it too,
  // raked aft with the transom, up to a tiller head above the deck
  pin_p := point hint((5798, -40, 30))
  fix((dims.joint_x, -40mm, dims.joint_z)) pin_p
  pin_s := point hint((5798, 40, 30))
  fix((dims.joint_x, 40mm, dims.joint_z)) pin_s
  tilt_line := line(pin_p, pin_s)
  tilt_pin := solid(std.sets.Rod(tilt_line, r: 8mm))
  stock_top := point hint((5893, 0, 470))
  fix((dims.joint_x + (dims.stock_top_z - dims.joint_z) * tan(dims.transom_rake), 0mm, dims.stock_top_z)) stock_top
  stock_line := line(joint, stock_top)
  steering_stock := solid(std.sets.Rod(stock_line, r: 12mm))
}

drive := Drive(teeth: 1)

// The propeller is drawn by prop.sv and placed with this drive in kayak.sv: its blades are a face
// family over a running number, which this file, cutting its gears, leaves out.
