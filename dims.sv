// The pedal kayak's numbers, stated once, each with its unit, and the claims they are held to.
// The models read them from here (`use dims`), and `solventc dims.sv` judges every claim.
//
// **The drive, from the pedals to the water.**
// 1. The cranks turn a spiral bevel gear (45) at the top of the pedal tower. It drives a pinion
//    (18) on the tower's shaft, which runs down to the keel square to the line shaft: 2.5 times as
//    fast.
// 2. At the keel a second spiral bevel pair, gear (42) on the tower shaft and pinion (15) on the
//    line shaft, steps up 2.8 times again. The line shaft turns 7 times as fast as the cranks.
// 3. The line shaft runs aft along the keel in a tunnel under the seat and the cargo well, on one
//    bearing midway. It passes through the hull bottom into the skeg.
// 4. At the skeg's heel a CV joint drives the hinged tail. The tail's shaft carries the propeller.
//    The tail tilts up for shallow water and swings side to side to steer.
//
// Stepping the speed up before the long shaft keeps its torque, and so its wind-up, small, the way
// a bicycle's shaft drive does (geomsolver's `shaft_drive/dims.sv`).
//
// Coordinates, mm: x aft from the stem head, y to starboard, z up from the keel's lowest point.
unit mm

// -- the people: ANSUR II (US Army, 2012), 1st-percentile woman to 99th-percentile man ------------
// Army personnel are leaner than the public, so the heaviest pilot designed for is beyond ANSUR's.
fll_min := 921mm                       // functional leg length: backrest to sole, leg extended
fll_max := 1267mm
hip_breadth_max := 462mm               // hip breadth, sitting
pilot_min := 47kg                      // ANSUR 1st-percentile woman, 46.7 kg
pilot_max := 136kg                     // ANSUR's 99th-percentile man is 124.2 kg; 300 lb designed for
passenger_max := 100kg

// -- what the boat weighs, and what it carries ------------------------------------------------------
hull_mass := 38kg                      // panels, transom, bulkheads, decks, glass and epoxy
drive_mass := 9kg                      // pedal tower, gears, shafts, tail, propeller
seat_mass := 4kg
boat_mass := hull_mass + drive_mass + seat_mass       // 51 kg on the cart
gear_mass := 15kg
cargo_mass := 25kg                     // a bicycle, front wheel off, or the equivalent
design_load := boat_mass + 90kg + gear_mass           // 156 kg
full_load := boat_mass + pilot_max + passenger_max + cargo_mass   // 312 kg

// -- the hull: tools/lines.py's hydrostatics, read at its three loads ---------------------------------
loa := 5800mm
beam := 824mm
depth := 380mm                         // keel to sheer at the widest station
draft_design := 123.4mm                // at 156 kg
draft_full := 180.9mm                  // at 320 kg
lwl := 5050mm                          // at the design load
bwl := 670mm
wetted := 2.67m * 1m                  // (a literal with ^ squares its unit and its number)
km_design := 530mm                     // the metacentre above the keel at the design load
km_full := 472mm
transom_keel_z := 112mm                // the transom's bottom corner
freeboard_full := depth - draft_full   // at the widest station

// The centre of gravity, height above the keel: a recumbent pilot's about 130 mm above the hip,
// the hip 200 mm up (on the seat over the shaft tunnel); a passenger sits on the floor.
hip_z := 200mm
pilot_kg_z := hip_z + 130mm
boat_kg_z := 190mm
low_kg_z := 150mm                      // gear, cargo
passenger_kg_z := 300mm
kg_design := (90kg * pilot_kg_z + boat_mass * boat_kg_z + gear_mass * low_kg_z) / design_load
full_moment := pilot_max * pilot_kg_z + passenger_max * passenger_kg_z + cargo_mass * low_kg_z
kg_full := (full_moment + boat_mass * boat_kg_z) / full_load
gm_design := km_design - kg_design     // ≈ 260 mm
gm_full := km_full - kg_full           // ≈ 175 mm

// -- speed and power ---------------------------------------------------------------------------------
// ITTC-57 friction on the wetted area at the design load, a form factor for the hull's shape, and
// a residuary allowance for wave-making at Froude number 0.29. An estimate, to be checked in the water.
rho_sea := 1025kg / 1m^3
nu_sea := 1.19e-6 * 1m * 1m / 1s
g := 9.81m / 1s^2
cruise := 2.06m / 1s                   // 4 knots
froude := cruise / sqrt(g * lwl)
reynolds := cruise * lwl / nu_sea
cf := 0.075 / (log(reynolds) - 2)^2
form := 1.12
residuary := 0.25                      // wave-making, as a share of the friction, at Fn 0.29
drag := 0.5 * rho_sea * cruise^2 * wetted * cf * form * (1 + residuary)
effective := drag * cruise             // ≈ 55 W delivered to the water

pedal_power := 100W                    // sustained, a fit adult on a recumbent
cadence := 70rpm
eta_prop := 0.75
eta_drive := 0.94                      // two spiral bevel meshes, a CV joint, seals and bearings
delivered := pedal_power * eta_drive * eta_prop

// -- the propeller -------------------------------------------------------------------------------------
prop_d := 270mm
prop_r := prop_d / 2
prop_pitch := 300mm
prop_blades := 2

// -- the train --------------------------------------------------------------------------------------
z_crank_gear := 45                     // stage 1, at the top of the pedal tower
z_tower_pinion := 18
z_tower_gear := 42                     // stage 2, at the keel
z_line_pinion := 15
step_1 := z_crank_gear / z_tower_pinion          // 2.5
step_2 := z_tower_gear / z_line_pinion           // 2.8
ratio := step_1 * step_2                         // 7
prop_speed := cadence * ratio                    // 490 rpm
slip := 1 - cruise / (prop_speed / turn * prop_pitch)
thrust_load := drag / (0.5 * rho_sea * cruise^2 * pi * prop_r^2)    // C_T: light, so efficient

crank := 155mm
crank_peak := 200Nm                    // 1290 N on the pedal: a hard start, pushing off the seat back
crank_cruise := pedal_power / (cadence / 1rad)   // 13.6 N·m mean
tower_peak := crank_peak / step_1                // 80 N·m in the tower shaft
line_peak := crank_peak / ratio                  // 28.6 N·m in the line shaft

// Lewis bending at each pinion's root, the sprint peak, the form factor at the virtual tooth count.
// Estimates, to be checked to ISO 10300 before tooling.
m_1 := 2.5mm                           // stage 1 mean module
b_1 := 18mm                            // face width
m_2 := 2mm
b_2 := 16mm
lewis_y := 0.30
force_1 := crank_peak / (z_crank_gear * m_1 / 2)
force_2 := tower_peak / (z_tower_gear * m_2 / 2)
sigma_1 := force_1 / (b_1 * m_1 * lewis_y)
sigma_2 := force_2 / (b_2 * m_2 * lewis_y)
case_steel := 450MPa                   // allowable bending, case-hardened 16MnCr5, reversed

// -- the shafts --------------------------------------------------------------------------------------
// The line shaft: a 6061-T6 tube from the lower bevel box to the CV joint, on a bearing midway.
line_od := 25mm
line_id := 22mm
alu_E := 69GPa
alu_G := 26GPa
alu_rho := 2700kg / 1m^3
bb_x := 2250mm                         // the cranks' axle, from the stem head
bb_z := 330mm
lower_box_z := 72mm                    // the line shaft's height at the lower bevel box
joint_x := 5798mm                      // the CV joint: 60 aft of the transom, at the skeg's heel
joint_z := 30mm
line_length := sqrt((joint_x - bb_x)^2 + (lower_box_z - joint_z)^2)
line_slope := atan((lower_box_z - joint_z) / (joint_x - bb_x))
span := line_length / 2                // between bearings
line_J := pi * (line_od^4 - line_id^4) / 32
line_I := line_J / 2
line_mass := alu_rho * pi * (line_od^2 - line_id^2) / 4
line_tau := line_peak * (line_od / 2) / line_J
// the first whirling speed of a span pinned at both ends
whirl := pi / 2 / span^2 * sqrt(alu_E * line_I / line_mass) * turn
whirl_unsupported := pi / 2 / line_length^2 * sqrt(alu_E * line_I / line_mass) * turn
wind := line_peak * line_length / (alu_G * line_J) * 1rad / ratio    // as the cranks feel it

// The tower shaft: steel, 20 mm, from the crank's bevel down to the keel's.
tower_d := 20mm
tower_tau := 16 * tower_peak / (pi * tower_d^3)

// -- the tail --------------------------------------------------------------------------------------
tail := 520mm                          // the CV joint to the propeller's centre
prop_cover := 60mm                     // the propeller's top tip below the design waterline
prop_z := draft_design - prop_cover - prop_r        // its centre's height: below the keel
tail_down := asin((joint_z - prop_z) / tail)        // running, below horizontal
joint_running := tail_down - line_slope
helm := 25deg
joint_helm := acos(cos(joint_running) * cos(helm))
raise := 32deg                         // raised, above horizontal
joint_raised := raise + line_slope
fin_below_tips := 25mm
tip_z := joint_z - tail * sin(tail_down) - prop_r * cos(tail_down)  // the lowest tip's height
deepest_running := draft_design - (tip_z - fin_below_tips)          // the fin, below the waterline

// -- the seat ---------------------------------------------------------------------------------------
// The pedal's far point is reach_factor of the functional leg length from the backrest: the ball
// of the foot on the spindle, the knee a little short of straight. The seat slides on rails; the
// cranks stay put.
reach_factor := 0.96
hip_to_bb_min := reach_factor * fll_min - crank
hip_to_bb_max := reach_factor * fll_max - crank
hip_x_min := bb_x + sqrt(hip_to_bb_min^2 - (bb_z - hip_z)^2)
hip_x_max := bb_x + sqrt(hip_to_bb_max^2 - (bb_z - hip_z)^2)
seat_travel_needed := hip_x_max - hip_x_min
seat_travel := 380mm
seat_width := 480mm

// -- claims ------------------------------------------------------------------------------------------
claim full_load <= 320kg               // inside lines.py's full-load hydrostatics
claim freeboard_full >= 180mm
claim gm_design >= 150mm and gm_full >= 120mm
claim froude <= 0.32
claim delivered >= effective           // 100 W makes 4 knots
claim ratio == 7
claim z_tower_pinion >= 15 and z_line_pinion >= 15
claim slip >= 0.1 and slip <= 0.3
claim thrust_load <= 0.5
claim sigma_1 <= case_steel and sigma_2 <= case_steel
claim line_tau <= 60MPa
claim tower_tau <= 120MPa
claim whirl >= 1.5 * prop_speed
claim whirl_unsupported < prop_speed   // why the midway bearing is there
claim wind <= 3deg
claim tail_down <= 12deg               // the thrust nearly level
claim joint_running <= 15deg and joint_helm <= 35deg and joint_raised <= 45deg
claim joint_z + tail * sin(raise) - prop_r * cos(raise) >= draft_design + 10mm   // raised: clear
claim seat_travel >= seat_travel_needed
claim seat_width >= hip_breadth_max
