// The pedal kayak's mechanical design table: where each shaft's bearings and seals stand, what each
// part is made of, the loads the drive and its frame carry, and the checks they are held to. The
// parts (`drive_parts.sv`) are drawn from these numbers, and `solventc mech.sv` judges every claim.
//
// **The arrangement.**
// - **The tower** lifts out. It is the upper box (stage 1, on the cranks' axle) on a neck, and it
//   stands on the keel box (stage 2), fixed in the hull. A spigot registers the neck on the keel
//   box's top, two draw latches hold it down, and a tang on the foot of the tower pinion's shaft
//   drops into a slot in the top of the tower gear's stub.
// - **The strut** runs from lugs under the upper box forward and down to a clevis on the drive bed.
//   Tower, strut and drive bed are a triangle: the pedals' push goes into the strut as compression,
//   and into the neck and latches as tension.
// - **The drive bed** is a laminated hardwood keelson on the keel seam. It runs from the strut's
//   clevis aft, under the keel box (bolted to it), to the shaft tunnel. The tunnel is a box girder
//   of 9 mm webs, and the seat's rails run on its sides. So the pedal thrust and the seat back's
//   reaction meet in one beam. The hull's skin carries neither.
// - **The line shaft** runs dry. A slot in the keel box's output takes a tang on its forward end.
//   It turns in a bush midway, then enters a GRP stern tube that leaves the hull through the keel
//   seam into the skeg. At the skeg's heel it ends in a 316 stub, carried by a bearing and two lip
//   seals in a cartridge in the heel bracket. That is the only place water meets the drive. With
//   the tail off and the cartridge unbolted, the whole shaft draws aft out of the boat.
// - **The tail** hangs from a gimbal at the heel. A fork turns with the steering stock, raked 12°,
//   78 mm aft of the transom in two bosses. The tail tilts on a pin across the fork. A stainless
//   double U-joint, its centre on both axes, drives the propeller shaft, so the drive is constant
//   velocity at any helm and tilt.
//
// **Load cases.**
// - **Sprint:** the crank's peak, `dims.crank_peak` (200 N·m): a standing start, one leg pushing
//   off the seat back.
// - **Design:** the propeller's design point, 160 W at 70 rpm, for bearing life.
// Every static check is at the sprint load.
//
// Coordinates, mm: x aft from the stem head, y to starboard, z up from the keel's lowest point.
// Along each shaft, `a` is the distance from its pair's cone apex.
unit mm
use dims

// -- materials ------------------------------------------------------------------------------------
yield_4140 := 655MPa                   // 4140, quenched and tempered to 28-32 HRC: shafts, pinions
fatigue_4140 := 300MPa                 // its endurance limit, reversed bending, machined finish
yield_6061 := 240MPa                   // 6061-T6: housings, brackets, strut
yield_6061_weld := 110MPa              // 6061-T6 in a weld's heat-affected zone, not re-aged
yield_316 := 205MPa                    // 316 stainless, annealed: stub, prop shaft, stock, pins
spiral := 25deg                        // both pairs' spiral angle at the mean point
pressure := 20deg

// -- the pairs' proportions, as hypoid.sv lays them out --------------------------------------------
// Mean cone distance, face width (0.2 of it), and each member's pitch angle.
cone_1 := dims.m_1 * sqrt(dims.z_crank_gear^2 + dims.z_tower_pinion^2) / 2      // 60.6
cone_2 := dims.m_2 * sqrt(dims.z_tower_gear^2 + dims.z_line_pinion^2) / 2       // 44.6
face_1 := 0.2 * cone_1                                                          // 12.1
face_2 := 0.2 * cone_2                                                          // 8.9
pinion_angle_1 := 90deg - dims.delta_1                                          // 21.8°
pinion_angle_2 := 90deg - dims.delta_2                                          // 19.7°
// Each member's reach: its outside radius at the heel (the pitch radius there plus an addendum).
mn_1 := dims.m_1 * cos(spiral)
mn_2 := dims.m_2 * cos(spiral)
crank_gear_tip := (cone_1 + face_1 / 2) * sin(dims.delta_1) + mn_1 * cos(dims.delta_1)     // 62.7
tower_gear_tip := (cone_2 + face_2 / 2) * sin(dims.delta_2) + mn_2 * cos(dims.delta_2)     // 46.8
tower_pinion_tip := (cone_1 + face_1 / 2) * sin(pinion_angle_1) + mn_1 * cos(pinion_angle_1)
line_pinion_tip := (cone_2 + face_2 / 2) * sin(pinion_angle_2) + mn_2 * cos(pinion_angle_2)
// Each member's envelope along its axis from the apex (toe tip to heel back, the blank's back
// 4 mn under the pitch cone) and a gear's inside radius at its toe: the blanks the assembly draws.
crank_gear_a0 := (cone_1 - face_1 / 2) * cos(dims.delta_1) - mn_1 * sin(dims.delta_1)
crank_gear_a1 := (cone_1 + face_1 / 2) * cos(dims.delta_1) + 4 * mn_1 * sin(dims.delta_1)
crank_gear_rin := (cone_1 - face_1 / 2) * sin(dims.delta_1) - 4 * mn_1 * cos(dims.delta_1)
tower_gear_a0 := (cone_2 - face_2 / 2) * cos(dims.delta_2) - mn_2 * sin(dims.delta_2)
tower_gear_a1 := (cone_2 + face_2 / 2) * cos(dims.delta_2) + 4 * mn_2 * sin(dims.delta_2)
tower_gear_rin := (cone_2 - face_2 / 2) * sin(dims.delta_2) - 4 * mn_2 * cos(dims.delta_2)
tower_pinion_a0 := (cone_1 - face_1 / 2) * cos(pinion_angle_1) - mn_1 * sin(pinion_angle_1)
tower_pinion_a1 := (cone_1 + face_1 / 2) * cos(pinion_angle_1) + 4 * mn_1 * sin(pinion_angle_1)
line_pinion_a0 := (cone_2 - face_2 / 2) * cos(pinion_angle_2) - mn_2 * sin(pinion_angle_2)
line_pinion_a1 := (cone_2 + face_2 / 2) * cos(pinion_angle_2) + 4 * mn_2 * sin(pinion_angle_2)

// -- the spiral hands -----------------------------------------------------------------------------
// Each pair is a speed increaser: the gear drives and the pinion is driven. The rule for a driven
// member is that its thrust runs along its turning vector if it is left-handed, and against it if
// right-handed.
// - Forward pedalling turns the tower pinion about −z, which points away from stage 1's apex.
// - It turns the line pinion about +x, which points away from stage 2's apex.
// So both pinions are LEFT-handed and both gears right-handed. Each pinion's thrust then pushes it
// out of mesh under forward drive, the safe way: the backlash opens rather than closing under load.
// Reverse pedalling reverses the spiral term (smaller torques). The tapered pairs locate both ways.

// -- the sprint's forces at each mesh, at the mean point ------------------------------------------
pedal_peak := dims.crank_peak / dims.crank                      // 1290 N on the pedal
wt_1 := dims.crank_peak / dims.r_crank_gear                     // stage 1 tangential, 3556 N
wt_2 := dims.tower_peak / dims.r_tower_gear                     // stage 2 tangential, 1905 N
// the pinion's thrust (away from the apex, the left-handed driven pinion) and its separating force;
// the gear's thrust is the pinion's separating force, and the gear's separating force the pinion's
// thrust (square shafts)
fa_p1 := wt_1 / cos(spiral) * (tan(pressure) * sin(pinion_angle_1) + sin(spiral) * cos(pinion_angle_1))
fr_p1 := wt_1 / cos(spiral) * (tan(pressure) * cos(pinion_angle_1) - sin(spiral) * sin(pinion_angle_1))
fa_p2 := wt_2 / cos(spiral) * (tan(pressure) * sin(pinion_angle_2) + sin(spiral) * cos(pinion_angle_2))
fr_p2 := wt_2 / cos(spiral) * (tan(pressure) * cos(pinion_angle_2) - sin(spiral) * sin(pinion_angle_2))
claim fa_p1 >= 0N and fa_p2 >= 0N                      // each pinion pushed out of mesh, driving forward

// -- the upper box: stage 1, the cranks' axle and the tower pinion -------------------------------
// The crank axle runs athwartships through `bb`, along y. Its parts by their y:
// - the crank gear's ring at 18-33, its web to 37, its hub to 41, keyed to the axle;
// - two 6204-2RS bearings, centred at −46 and +48;
// - lip seals 20 × 32 × 5 in the end caps, to ±60;
// - JIS square tapers (2° each flat, 15 mm long) from ±62 for stock 155 mm cranks, M8 bolts.
// The drum round the gear is Ø142 on its outside.
axle_d := 20mm
brg_port_y := -46mm
brg_stbd_y := 48mm
crank_taper_y := 62mm
drum_r := crank_gear_tip + 3mm + 5mm                    // the gear's tip, 3 clear, a 5 mm wall
drum_port_y := -58mm
drum_stbd_y := 60mm
// 6204-2RS: 20 × 47 × 14, C 13.5 kN, C0 6.55 kN (ISO 15; SKF's table)
c_6204 := 13500N
c0_6204 := 6550N
// The pedal's centre is `dims.q_half + dims.pedal_width / 2` out. Under the sprint, the bearing
// next to the loaded pedal takes it as a lever over the bearings' span.
pedal_y := dims.q_half + dims.pedal_width / 2           // 115
axle_span := brg_stbd_y - brg_port_y
axle_overhang := pedal_y + brg_port_y                   // the port pedal, past the port bearing: 69
axle_brg_load := pedal_peak * (axle_overhang + axle_span) / axle_span + fa_p1   // + the gear's separating force
claim c0_6204 / axle_brg_load >= 1.5                    // static, at the one-off sprint peak
// The axle at the port bearing: the pedal's moment and the crank's torque.
axle_m := pedal_peak * axle_overhang
axle_sigma := 32 * axle_m / (pi * axle_d^3)
axle_tau := 16 * dims.crank_peak / (pi * axle_d^3)
axle_vm := sqrt(axle_sigma^2 + 3 * axle_tau^2)
claim yield_4140 / axle_vm >= 2
// Fatigue at the design load: the pedal's force rises and falls with each stroke, about 2.5 times
// its mean at its peak; the bending reverses as the axle turns. The key's notch is Kt 2.
design_torque := 160W / (dims.cadence / 1rad)           // 21.8 N·m mean at the cranks
axle_sigma_design := 2 * 32 * (2.5 * design_torque / dims.crank * axle_overhang) / (pi * axle_d^3)
claim fatigue_4140 / axle_sigma_design >= 3

// The tower pinion is cut on its own shaft, 4140 carburised, overhung on two 30204 tapered rollers
// back to back, set by a nut. Down from stage 1's apex:
// - the teeth, mean point at `dims.r_crank_gear` (56);
// - bearing A centred at 80, bearing B at 140;
// - the nut to 156, then a lip seal 20 × 32 × 7;
// - the neck's spigot face at 196, with the shaft's tang below it.
p1_mean := dims.r_crank_gear
p1_brg_a := 80mm
p1_brg_b := 140mm
neck_face := 196mm                      // the neck's spigot face, down from stage 1's apex
// 30204: 20 × 47 × 15.25, C 27.5 kN, C0 28 kN, Y 1.7 (ISO 355)
c_30204 := 27500N
c0_30204 := 28000N
y_taper := 1.7
p1_span := p1_brg_b - p1_brg_a
p1_over := p1_brg_a - p1_mean
r_p1 := dims.r_tower_pinion
// bearing A carries the most. In the tangential plane it is the lever. In the radial plane it is
// the separating force's lever plus the thrust's moment at the pitch radius, taken whole.
p1_a_t := wt_1 * (p1_over + p1_span) / p1_span
p1_a_r := (fr_p1 * (p1_over + p1_span) + fa_p1 * r_p1) / p1_span
p1_a := sqrt(p1_a_t^2 + p1_a_r^2)
claim c0_30204 / (p1_a + fa_p1) >= 2                    // static, radial and thrust added
// life at the design load: forces in proportion to torque, the shaft at 2.5 × 70 rpm
design_share := design_torque / dims.crank_peak
p1_life := (c_30204 / (design_share * (p1_a + y_taper * fa_p1)))^(10 / 3) * 1e6 * turn / (dims.cadence * dims.step_1)
claim p1_life >= 20000 * 3600s                             // L10, hours of pedalling at 160 W

// -- the keel box: stage 2, the tower gear and the line pinion --------------------------------------
// The tower gear is straddled.
// - Up from stage 2's apex: its ring at 13-23, its web and hub up its stub, which turns in a 6005-2RS
//   centred at 40, under a 25 × 37 × 7 seal. The stub's top, at 62, is slotted for the tang: 6.2
//   wide, 12 deep.
// - Below the apex: a 6202-2RS, centred 9 down, in a boss rising from the box's floor. The line
//   pinion's toe stands 37 aft of the tower's axis, clear of it.
// The line pinion is cut on its own shaft, overhung on two 30203 tapered rollers back to back.
// - Aft from stage 2's apex: bearings centred at 62 and 112, the nut, a 17 × 28 × 7 seal.
// - The box's aft face at 130, the shaft's end at 140, slotted 6.2 wide and 10 deep for the line
//   shaft's tang.
tg_brg_top := 40mm
tg_brg_low := -9mm
tg_top := 62mm                          // the stub's top and the keel box's spigot face, up from stage 2's apex
p2_mean := dims.r_tower_gear
p2_brg_a := 62mm
p2_brg_b := 112mm
box_aft := 130mm
p2_end := 140mm
box_floor := -32mm                      // the keel box's floor, below stage 2's apex: z 40
// The tower is one height, apex to apex: the neck's spigot face meets the keel box's top.
claim neck_face + tg_top <= dims.tower_length + 0.5mm and neck_face + tg_top >= dims.tower_length - 0.5mm
// 30203: 17 × 40 × 13.25, C 22.4 kN, C0 20 kN
c_30203 := 22400N
c0_30203 := 20000N
p2_span := p2_brg_b - p2_brg_a
p2_over := p2_brg_a - p2_mean
r_p2 := dims.r_line_pinion
p2_a_t := wt_2 * (p2_over + p2_span) / p2_span
p2_a_r := (fr_p2 * (p2_over + p2_span) + fa_p2 * r_p2) / p2_span
p2_a := sqrt(p2_a_t^2 + p2_a_r^2)
claim c0_30203 / (p2_a + fa_p2) >= 2
p2_life := (c_30203 / (design_share * (p2_a + y_taper * fa_p2)))^(10 / 3) * 1e6 * turn / dims.prop_speed
claim p2_life >= 20000 * 3600s
// The tower gear's upper bearing, straddled: at most the whole of the mesh's force, a 6005.
c0_6005 := 6550N
claim c0_6005 / sqrt(wt_2^2 + fa_p2^2 + fr_p2^2) >= 2

// -- the shafts and the tangs between them ----------------------------------------------------------
// A tang on a shaft's end drops into a slot across its mate's. Each half flank bears at a quarter
// of the tang's width from the axis, so the flank pressure is 4 T / (h w²).
tang_t := 6mm
tower_tang_w := 20mm                    // the tower pinion's shaft end, Ø20
tower_tang_h := 12mm
line_tang_w := 16mm                     // the line shaft's forward plug
line_tang_h := 10mm
tower_tang_p := 4 * dims.tower_peak / (tower_tang_h * tower_tang_w^2)
line_tang_p := 4 * dims.line_peak / (line_tang_h * line_tang_w^2)
claim tower_tang_p <= 150MPa and line_tang_p <= 150MPa   // through-hardened 4140 and 17-4PH, no fretting at this pressure
// The tower pinion's shaft at its tang: 20 mm, in torsion.
claim yield_4140 / (16 * dims.tower_peak / (pi * (20mm)^3) * sqrt(3)) >= 3
// The line shaft's plugs (17-4PH forward, 316 aft) are bonded 40 mm into the tube with structural
// epoxy, and each is cross-pinned.
plug_l := 40mm
plug_shear := dims.line_peak / (2 * pi * (dims.line_id / 2)^2 * plug_l)
claim plug_shear <= 5MPa                                 // a quarter of a structural epoxy's lap shear

// -- the line shaft's route -------------------------------------------------------------------------
// The shaft is 6061-T6, hard anodised, so the midway bush runs on the anodising.
// - Forward, it starts at the keel box's output, `p2_end` aft of stage 2's apex.
// - Midway, an acetal bush, 25 × 35 × 30, sits in a block on rubber mounts on the tunnel's floor.
// - Aft, the GRP stern tube (ID 32, OD 38) begins in the tunnel at x 4380. It leaves the hull
//   through the keel seam between x 4400 and 5130, and runs in the skeg to its heel at x 5670.
// At the heel bracket the shaft's aft plug becomes the 20 mm stub. The stub turns in a 6004-2RS,
// under two 20 × 35 × 7 FKM lip seals: the inner holds the grease, the outer holds out the sea.
stern_id := 32mm
stern_od := 38mm
stern_fwd_x := 4380mm
skeg_heel_x := 5670mm
// The shaft's sag in the stern tube, midway bush to heel, under its own weight: well inside the
// tube's clearance.
sag := 5 * dims.line_mass * dims.g * dims.span^4 / (384 * dims.alu_E * dims.line_I)
claim sag <= (stern_id - dims.line_od) / 4
// The seal's head: the sea's depth over the stub at the full load. A lip seal holds 30 kPa or more.
seal_head := dims.rho_sea * dims.g * (dims.draft_full - dims.joint_z)
claim seal_head <= 5000Pa

// -- the tail: the double U-joint and the propeller's shaft ---------------------------------------
// Ruland UD24-20MM-15MM-SS: a stainless double U-joint, 20 and 15 mm bores, 38 OD, 166.7 long,
// rated 147 N·m, with its boot (UBOOT24). Its centre is the gimbal's.
uj_length := 166.7mm
uj_rated := 147Nm
claim uj_rated / dims.line_peak >= 4
// The propeller's shaft is 316, Ø15. It turns in two acetal bushes in the tail's tube, which is
// 6061-T6, 40 × 2, hard anodised. The propeller's hub is pinned to it by the 1.8 mm shear pin.
prop_shaft_d := 15mm
claim yield_316 / (16 * dims.line_peak / (pi * prop_shaft_d^3) * sqrt(3)) >= 2
tail_tube_start := uj_length / 2 + 8mm   // the tube begins past the joint's aft hub, along the tail

// -- the frame: tower, strut and drive bed ----------------------------------------------------------
// The strut is 6061-T6 tube, 25 × 2, with welded fork ends. It runs from lugs under the upper box
// (2215, 262) to a clevis on the drive bed (pin at 1900, 60), with a Ø8 ball-lock pin at its foot. The
// pedal's push, square to the tower at the axle, goes into the strut as compression, and its
// vertical part into the latches as tension.
strut_top_x := 2215mm
strut_top_z := 262mm
strut_foot_x := 1900mm
strut_foot_z := 60mm
strut_len := sqrt((strut_top_x - strut_foot_x)^2 + (strut_top_z - strut_foot_z)^2)
strut_rise := atan((strut_top_z - strut_foot_z) / (strut_top_x - strut_foot_x))
strut_od := 25mm
strut_id := 21mm
strut_force := pedal_peak / cos(strut_rise)
strut_I := pi * (strut_od^4 - strut_id^4) / 64
strut_A := pi * (strut_od^2 - strut_id^2) / 4
strut_euler := pi^2 * dims.alu_E * strut_I / strut_len^2
claim strut_euler / strut_force >= 5
claim yield_6061_weld / (strut_force / strut_A) >= 3     // at the welds
// The latches hold the strut's vertical share, and the moment of the pedal's push taken above the
// strut's lugs (330 - 262), across the 90 mm between the latches.
latch_pull := (pedal_peak * tan(strut_rise) + pedal_peak * (dims.bb_z - strut_top_z) / 90mm) / 2
latch_swl := 1500N                      // each stainless draw latch's safe working load
claim latch_swl / latch_pull >= 1.5
// The ball-lock pin at the strut's foot, in double shear.
pin_d := 8mm
claim 0.6 * yield_316 / (strut_force / (2 * pi * pin_d^2 / 4)) >= 3
// The drive bed's glue line to the keel seam carries the pedal's push to the tunnel: 60 wide, 500 long.
bed_shear := pedal_peak / (60mm * 500mm)
claim bed_shear <= 0.5MPa                              // a glued and glassed joint in okoumé is good for 2-3

// -- the seat ---------------------------------------------------------------------------------------
// The carriage runs on two 20 × 20 aluminium rails screwed along the tunnel's webs. It is locked
// by an Ø8 pin through holes 20 mm apart (19 stations over the travel), in double shear. The
// seat back's sprint reaction is the pedal's push.
seat_pin_d := 8mm
claim 0.6 * yield_316 / (pedal_peak / (2 * pi * seat_pin_d^2 / 4)) >= 3
tunnel_web := 9mm
tunnel_inner := 60mm                    // clear width inside the webs: the midway block and the shaft
claim tunnel_inner >= 2 * (dims.line_od / 2 + 10mm) + 15mm

// -- steering ---------------------------------------------------------------------------------------
// The stock is 316 tube, 25 × 3. It turns in two acetal-bushed bosses, 76 mm off the transom's aft
// face: one at its foot (z 120), one at its top (z 390). A yoke on its head takes two Ø1.5
// stainless pull-pull cables, in conduit, to a lever beside the seat. The raise line runs up the
// hollow stock, from a lug on the tail 120 mm aft of the joint to a cleat by the seat. A
// spring-loaded detent on the fork holds the tail down. It lets go to a strike, as a kick-up
// rudder does.
stock_od := 25mm
stock_id := 19mm
// a side load at the propeller (a grounding at full helm, the detent not yet gone), 200 N, its
// lever from the stock's foot boss down to the propeller's centre
side_load := 200N
stock_lever := 120mm - dims.prop_z
stock_Z := pi * (stock_od^4 - stock_id^4) / (32 * stock_od)
claim yield_316 / (side_load * stock_lever / stock_Z) >= 2
detent_release := 40Nm                  // about the tilt pin: 77 N at the propeller's centre
