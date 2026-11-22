// The drive's hardware: the two gearboxes, the line shaft with its bush and heel cartridge, the
// heel bracket, the gimbal and steering stock, the tail, and the strut. Every number is mech.sv's
// or dims.sv's.
//
// **Making them.** The parts are drawn to be made in a small machine shop: a CNC mill, a manual
// mill, a lathe and a welder.
// - The housings, the heel bracket, the gimbal fork and the tail's head are CNC-milled from 6061-T6
//   billet and hard anodised.
// - Shafts, plugs, the stub and the pins are turned: 4140 (QT) inside the boxes; 316 or 17-4PH
//   where they meet the sea.
// - The strut, the stock's bracket and the yoke are welded, then their bores are finished.
// - Bearings, seals, the double U-joint, the latches and the bushes are bought.
//
// **How each part is drawn.** Each gearbox is drawn in its own frame, placed by `drive.sv`:
// - its origin is its pair's cone apex;
// - x runs aft along the line shaft, y to starboard, z up the tower.
// The upper box's shafts are the crank axle (along y) and the tower pinion's (down −z). The keel
// box's are the tower gear's (up z) and the line pinion's (aft +x). The line shaft is drawn in the
// keel box's frame, x being the distance aft along it from stage 2's apex. The tail is drawn in its
// own frame: origin at the joint, x aft along the tail. The heel's fixed parts are drawn in the
// hull's coordinates.
unit mm
use std
use std.sets
use std.solids
use std.solids (cut, union)
use dims
use mech

// -- primitives, drawn in the frame of the part that calls them --------------------------------------
interface P3 { x: Length, y: Length, z: Length }

// a cylinder from `a` to `b`
component Cyl(a: P3, b: P3, r: Length) {
  p := point
  fix((a.x, a.y, a.z)) p
  q := point
  fix((b.x, b.y, b.z)) q
  ax := line(p, q)
  body := solid(std.sets.Rod(ax, r: r))
}

// a tube from `a` to `b`
component Pipe(a: P3, b: P3, ro: Length, ri: Length) {
  outer := Cyl(a, b, r: ro)
  construction inner := Cyl(a, b, r: ri)
  body := solid(outer.body)
  inner.body cut body
}

// a box, square to the frame, between two corners
component Block(lo: P3, hi: P3) {
  in std.top {
    a := point
    b := point
    c := point
    d := point
    fix((lo.x, lo.y)) a
    fix((hi.x, lo.y)) b
    fix((hi.x, hi.y)) c
    fix((lo.x, hi.y)) d
    rect := line(a, b) -> line(b, c) -> line(c, d) -> line(d, a) -> close
  }
  body := solid(std.solids.Prism(face(rect), from: lo.z, to: hi.z))
}

// on the frame's axes: a cylinder or a ring between two stations
component OnX(a0: Length, a1: Length, ro: Length, ri: Length) {
  ring := Pipe({x: a0, y: 0mm, z: 0mm}, {x: a1, y: 0mm, z: 0mm}, ro: ro, ri: ri)
  body := solid(ring.body)
}
component OnY(a0: Length, a1: Length, ro: Length, ri: Length) {
  ring := Pipe({x: 0mm, y: a0, z: 0mm}, {x: 0mm, y: a1, z: 0mm}, ro: ro, ri: ri)
  body := solid(ring.body)
}
component OnZ(a0: Length, a1: Length, ro: Length, ri: Length) {
  ring := Pipe({x: 0mm, y: 0mm, z: a0}, {x: 0mm, y: 0mm, z: a1}, ro: ro, ri: ri)
  body := solid(ring.body)
}
component RodX(a0: Length, a1: Length, r: Length) {
  c := Cyl({x: a0, y: 0mm, z: 0mm}, {x: a1, y: 0mm, z: 0mm}, r: r)
  body := solid(c.body)
}
component RodY(a0: Length, a1: Length, r: Length) {
  c := Cyl({x: 0mm, y: a0, z: 0mm}, {x: 0mm, y: a1, z: 0mm}, r: r)
  body := solid(c.body)
}
component RodZ(a0: Length, a1: Length, r: Length) {
  c := Cyl({x: 0mm, y: 0mm, z: a0}, {x: 0mm, y: 0mm, z: a1}, r: r)
  body := solid(c.body)
}

// -- the upper box: stage 1 ---------------------------------------------------------------------------
// A drum round the crank gear on the crank axle, closed to port and by a bolted cover to starboard
// (the gear goes in that way), on a neck down the tower that carries the pinion's tapered pair.
// The neck ends in a flange: its spigot registers in the keel box's top, its keepers take the
// latches, and two lugs under the drum take the strut's fork.
component UpperBox() {
  r := mech.drum_r
  rin := mech.drum_r - 5mm
  // -- the housing: drum, port bearing boss, neck, flange, spigot, keepers, lugs
  construction drum := RodY(a0: mech.drum_port_y, a1: 56mm, r: r)
  construction neck := RodZ(a0: -60mm, a1: -mech.neck_face + 10mm, r: 31mm)
  construction flange := RodZ(a0: -mech.neck_face + 10mm, a1: -mech.neck_face, r: 52mm)
  construction spigot := RodZ(a0: -mech.neck_face, a1: -mech.neck_face - 6mm, r: 34mm)
  construction keeper_f := Block({x: -60mm, y: -8mm, z: -mech.neck_face + 4mm}, {x: -50mm, y: 8mm, z: -mech.neck_face + 12mm})
  construction keeper_a := Block({x: 50mm, y: -8mm, z: -mech.neck_face + 4mm}, {x: 60mm, y: 8mm, z: -mech.neck_face + 12mm})
  construction lug_p := Block({x: -47mm, y: -16mm, z: -80mm}, {x: -23mm, y: -10mm, z: -55mm})
  construction lug_s := Block({x: -47mm, y: 10mm, z: -80mm}, {x: -23mm, y: 16mm, z: -55mm})
  housing := solid(drum.body)
  neck.body union housing
  flange.body union housing
  spigot.body union housing
  keeper_f.body union housing
  keeper_a.body union housing
  lug_p.body union housing
  lug_s.body union housing
  // the bores: the drum's inside (open to starboard), the port bearing and seal, the neck's
  // bearings, nut and seal, the tang's clearance, the strut's pin
  // Mill the deep annular pocket around the port boss, leaving its stock intact.
  construction port_pocket := OnY(a0: -54mm, a1: mech.port_bearing_face, ro: rin, ri: 30mm)
  construction cavity := RodY(a0: mech.port_bearing_face, a1: 61mm, r: rin)
  construction brg_port := RodY(a0: mech.port_bearing_back, a1: mech.port_bearing_face, r: 23.5mm)
  construction brg_shoulder := RodY(a0: mech.port_bearing_back - 1mm, a1: mech.port_bearing_back, r: 20mm)
  construction port_passage := RodY(a0: mech.port_seal_back, a1: mech.port_bearing_back, r: 13mm)
  construction seal_port := RodY(a0: mech.drum_port_y - 1mm, a1: mech.port_seal_back, r: 16mm)
  construction neck_bore := RodZ(a0: -55mm, a1: -150mm, r: 23.5mm)
  construction pinion_pocket := RodZ(a0: -45mm, a1: -mech.tower_pinion_a1 - 3mm, r: mech.tower_pinion_tip + 3mm)
  construction nut_bore := RodZ(a0: -150mm, a1: -158mm, r: 17mm)
  construction seal_bore := RodZ(a0: -158mm, a1: -165mm, r: 16mm)
  construction tang_bore := RodZ(a0: -165mm, a1: -mech.neck_face - 7mm, r: 12mm)
  construction strut_pin := Cyl({x: -35mm, y: -20mm, z: -68mm}, {x: -35mm, y: 20mm, z: -68mm}, r: 4mm)
  cavity.body cut housing
  port_pocket.body cut housing
  brg_shoulder.body cut housing
  port_passage.body cut housing
  brg_port.body cut housing
  seal_port.body cut housing
  neck_bore.body cut housing
  pinion_pocket.body cut housing
  nut_bore.body cut housing
  seal_bore.body cut housing
  tang_bore.body cut housing
  strut_pin.body cut housing
  // the starboard cover, with its bearing boss and seal
  construction cover_disc := RodY(a0: 56mm, a1: 60mm, r: r)
  construction cover_boss := RodY(a0: 41mm, a1: 56mm, r: 30mm)
  construction cover_brg := RodY(a0: 40mm, a1: 55mm, r: 23.5mm)
  construction cover_seal := RodY(a0: 55mm, a1: 61mm, r: 16mm)
  cover := solid(cover_disc.body)
  cover_boss.body union cover
  cover_brg.body cut cover
  cover_seal.body cut cover
  // -- the crank axle: Ø20 between the bearings, a JIS square taper each end (drawn round)
  construction axle_mid := RodY(a0: -mech.crank_taper_y, a1: mech.crank_taper_y, r: mech.axle_d / 2)
  construction taper_p := RodY(a0: -mech.crank_taper_y - 15mm, a1: -mech.crank_taper_y, r: 8mm)
  construction taper_s := RodY(a0: mech.crank_taper_y, a1: mech.crank_taper_y + 15mm, r: 8mm)
  crank_axle := solid(axle_mid.body)
  taper_p.body union crank_axle
  taper_s.body union crank_axle
  // the 6204-2RS pair, and the seals
  bearing_port := OnY(a0: mech.brg_port_y - 7mm, a1: mech.brg_port_y + 7mm, ro: 23.5mm, ri: 10mm)
  bearing_stbd := OnY(a0: mech.brg_stbd_y - 7mm, a1: mech.brg_stbd_y + 7mm, ro: 23.5mm, ri: 10mm)
  seal_p := OnY(a0: mech.drum_port_y, a1: mech.port_seal_back, ro: 16mm, ri: 10mm)
  seal_s := OnY(a0: 55mm, a1: 60mm, ro: 16mm, ri: 10mm)
  // the crank gear's web and hub, behind its ring (the ring is the pair's, in drive.sv), keyed
  construction web_disc := OnY(a0: 33mm, a1: 37mm, ro: 50mm, ri: 10mm)
  construction hub_ring := OnY(a0: 33mm, a1: 41mm, ro: 17mm, ri: 10mm)
  gear_web := solid(web_disc.body)
  hub_ring.body union gear_web
  // -- the tower pinion's shaft: from the pinion's back down through its tapered pair to the tang
  construction pin_shaft := RodZ(a0: -62mm, a1: -mech.neck_face, r: 10mm)
  construction tang := Block({x: -10mm, y: -3mm, z: -mech.neck_face - mech.tower_tang_h}, {x: 10mm, y: 3mm, z: -mech.neck_face})
  pinion_shaft := solid(pin_shaft.body)
  tang.body union pinion_shaft
  // the 30204 pair, back to back, the nut and the seal
  taper_a := OnZ(a0: -mech.p1_brg_a + 7.6mm, a1: -mech.p1_brg_a - 7.6mm, ro: 23.5mm, ri: 10mm)
  taper_b := OnZ(a0: -mech.p1_brg_b + 7.6mm, a1: -mech.p1_brg_b - 7.6mm, ro: 23.5mm, ri: 10mm)
  nut := OnZ(a0: -150mm, a1: -156mm, ro: 15mm, ri: 10mm)
  pinion_seal := OnZ(a0: -158mm, a1: -165mm, ro: 16mm, ri: 10mm)
}

// -- the keel box: stage 2 -------------------------------------------------------------------------------
// A chamber round the tower gear, with a lid that carries the gear's upper bearing and the tower's
// spigot recess. A boss in its floor takes the gear's lower bearing, straddling the gear. A barrel
// aft carries the line pinion's tapered pair. Its floor is a flange bolted to the drive bed with
// four M8 studs. The draw latches stand on the lid's boss, fore and aft.
component KeelBox() {
  bottom := mech.box_floor
  construction chamber := RodZ(a0: bottom, a1: 30mm, r: 55mm)
  construction barrel := RodX(a0: 30mm, a1: mech.box_aft, r: 26mm)
  // An 8 mm foot overlaps the barrel by 2 mm at its lowest point.
  construction base := Block({x: -55mm, y: -30mm, z: bottom}, {x: mech.box_aft, y: 30mm, z: bottom + 8mm})
  housing := solid(chamber.body)
  barrel.body union housing
  base.body union housing
  // Pocket around an integral island for the 6202, then bore its seat from above.
  construction lower_pocket := OnZ(a0: bottom + 4mm, a1: -2mm, ro: 51mm, ri: 21.5mm)
  construction cavity := RodZ(a0: -2mm, a1: 31mm, r: 51mm)
  lower_pocket.body cut housing
  cavity.body cut housing
  construction shaft_relief := RodZ(a0: mech.tg_brg_low - 7mm, a1: mech.tg_brg_low - 5.5mm, r: 14mm)
  shaft_relief.body cut housing
  construction low_seat := RodZ(a0: mech.tg_brg_low - 5.5mm, a1: 0mm, r: 17.5mm)
  construction barrel_bore := RodX(a0: 30mm, a1: 120mm, r: 20mm)
  construction barrel_mouth := RodX(a0: 30mm, a1: mech.line_pinion_a1 + 3mm, r: mech.line_pinion_tip + 4mm)
  construction out_seal := RodX(a0: 120mm, a1: 127mm, r: 14mm)
  construction out_hole := RodX(a0: 127mm, a1: mech.box_aft + 1mm, r: 9.5mm)
  low_seat.body cut housing
  barrel_bore.body cut housing
  barrel_mouth.body cut housing
  out_seal.body cut housing
  out_hole.body cut housing
  // the lid: a disc over the chamber and a boss up to the spigot face, with the gear's 6005 and seal
  construction lid_disc := RodZ(a0: 30mm, a1: 34mm, r: 55mm)
  construction lid_boss := RodZ(a0: 34mm, a1: mech.tg_top, r: 52mm)
  construction latch_f := Block({x: -62mm, y: -9mm, z: 40mm}, {x: -52mm, y: 9mm, z: mech.tg_top})
  construction latch_a := Block({x: 52mm, y: -9mm, z: 40mm}, {x: 62mm, y: 9mm, z: mech.tg_top})
  lid := solid(lid_disc.body)
  lid_boss.body union lid
  construction lid_brg := RodZ(a0: mech.tg_brg_top - 6mm, a1: mech.tg_brg_top + 6mm, r: 23.5mm)
  construction lid_seal := RodZ(a0: 48mm, a1: 55mm, r: 18.5mm)
  construction lid_hole := RodZ(a0: 29mm, a1: mech.tg_top + 1mm, r: 13mm)
  construction recess := RodZ(a0: mech.tg_top - 6mm, a1: mech.tg_top + 1mm, r: 34.3mm)
  lid_brg.body cut lid
  lid_seal.body cut lid
  lid_hole.body cut lid
  recess.body cut lid
  latches := solid(latch_f.body)
  latch_a.body union latches
  // -- the tower gear's stub: in the 6202 below, the 6005 above; slotted at its top for the tang
  construction stub_low := RodZ(a0: mech.tg_brg_low - 5.5mm, a1: -2mm, r: 7.5mm)
  construction stub_up := RodZ(a0: -2mm, a1: mech.tg_top, r: 12.5mm)
  construction slot := Block({x: -13mm, y: -3.1mm, z: mech.tg_top - mech.tower_tang_h}, {x: 13mm, y: 3.1mm, z: mech.tg_top + 1mm})
  gear_stub := solid(stub_up.body)
  stub_low.body union gear_stub
  slot.body cut gear_stub
  // the gear's web and hub, behind its ring (the pair's, in drive.sv)
  construction web_disc := OnZ(a0: 22mm, a1: 27mm, ro: 40mm, ri: 12.5mm)
  construction hub_ring := OnZ(a0: 10mm, a1: 30mm, ro: 17mm, ri: 12.5mm)
  gear_web := solid(web_disc.body)
  hub_ring.body union gear_web
  bearing_low := OnZ(a0: mech.tg_brg_low - 5.5mm, a1: mech.tg_brg_low + 5.5mm, ro: 17.5mm, ri: 7.5mm)
  bearing_top := OnZ(a0: mech.tg_brg_top - 6mm, a1: mech.tg_brg_top + 6mm, ro: 23.5mm, ri: 12.5mm)
  stub_seal := OnZ(a0: 48mm, a1: 55mm, ro: 18.5mm, ri: 12.5mm)
  // -- the line pinion's shaft: from the pinion's back aft through its tapered pair, slotted at
  // its end for the line shaft's tang
  construction out_shaft := RodX(a0: 49mm, a1: mech.p2_end, r: 8.5mm)
  construction out_slot := Block({x: mech.p2_end - mech.line_tang_h, y: -10mm, z: -3.1mm}, {x: mech.p2_end + 1mm, y: 10mm, z: 3.1mm})
  pinion_shaft := solid(out_shaft.body)
  out_slot.body cut pinion_shaft
  taper_a := OnX(a0: mech.p2_brg_a - 6.6mm, a1: mech.p2_brg_a + 6.6mm, ro: 20mm, ri: 8.5mm)
  taper_b := OnX(a0: mech.p2_brg_b - 6.6mm, a1: mech.p2_brg_b + 6.6mm, ro: 20mm, ri: 8.5mm)
  nut := OnX(a0: 119mm, a1: 120mm, ro: 13mm, ri: 8.5mm)
  out_seal_ring := OnX(a0: 120mm, a1: 127mm, ro: 14mm, ri: 8.5mm)
}

// -- the line shaft, drawn in the keel box's frame: x is the distance aft of stage 2's apex -------------
// The tube, hard anodised, runs from just past the keel box's output to inside the stern tube. Its
// forward plug, 17-4PH, carries the tang. Its aft plug, 316, runs on as the 20 mm stub through the
// heel cartridge into the double U-joint's forward hub. The midway bush's block stands on the
// tunnel's floor on four rubber mounts.
component LineShaft() {
  heel := (mech.skeg_heel_x - dims.low_x) / dims.aft_x          // the skeg's heel, along the shaft
  stub_end := dims.line_length - mech.uj_length / 2 + 30mm        // 30 into the joint's hub
  tube_end := heel - 20mm
  construction tube_ring := OnX(a0: mech.p2_end + 2mm, a1: tube_end, ro: dims.line_od / 2, ri: dims.line_id / 2)
  tube := solid(tube_ring.body)
  construction fwd_tang := Block({x: mech.p2_end - mech.line_tang_h + 0.5mm, y: -mech.line_tang_w / 2, z: -3mm}, {x: mech.p2_end + 2mm, y: mech.line_tang_w / 2, z: 3mm})
  construction fwd_body := RodX(a0: mech.p2_end + 2mm, a1: mech.p2_end + 2mm + mech.plug_l, r: dims.line_id / 2)
  forward_plug := solid(fwd_body.body)
  fwd_tang.body union forward_plug
  construction aft_body := RodX(a0: tube_end - mech.plug_l, a1: tube_end, r: dims.line_id / 2)
  construction stub_body := RodX(a0: tube_end, a1: stub_end, r: 10mm)
  stub := solid(aft_body.body)
  stub_body.body union stub
  // the midway bush, its block and its rubber-mounted foot, on the tunnel's floor (z 14 there)
  run := dims.r_tower_gear + (dims.line_length - dims.r_tower_gear) / 2
  floor_z := 14mm - (dims.lower_box_z + run * dims.aft_z)
  bush := OnX(a0: run - 15mm, a1: run + 15mm, ro: 17.5mm, ri: dims.line_od / 2)
  construction block_body := Block({x: run - 20mm, y: -28mm, z: floor_z + 6mm}, {x: run + 20mm, y: 28mm, z: 24mm})
  construction block_bore := RodX(a0: run - 21mm, a1: run + 21mm, r: 17.5mm)
  bush_block := solid(block_body.body)
  block_bore.body cut bush_block
  block_mounts := Block({x: run - 20mm, y: -28mm, z: floor_z}, {x: run + 20mm, y: 28mm, z: floor_z + 6mm})
  // the heel cartridge: the 6004-2RS seats in the heel bracket; the cartridge bolted on its aft
  // face carries the two lip seals, the inner lip in, the outer out, grease between
  bearing := OnX(a0: heel, a1: heel + 12mm, ro: 21mm, ri: 10mm)
  construction cart_flange := OnX(a0: heel + 12mm, a1: heel + 18mm, ro: 30mm, ri: 10.5mm)
  construction cart_boss := OnX(a0: heel + 18mm, a1: heel + 30mm, ro: 24mm, ri: 10.5mm)
  cartridge := solid(cart_flange.body)
  cart_boss.body union cartridge
  seal_in := OnX(a0: heel + 14mm, a1: heel + 21mm, ro: 17.5mm, ri: 10mm)
  seal_out := OnX(a0: heel + 22mm, a1: heel + 29mm, ro: 17.5mm, ri: 10mm)
  // the double U-joint's forward half, to its centre at the joint
  construction uj_hub := RodX(a0: dims.line_length - mech.uj_length / 2, a1: dims.line_length - 14mm, r: 19mm)
  uj_fwd := solid(uj_hub.body)
}

// Identical port and starboard pins. The eccentric flange screws to the tail ear.
component TiltPin(side: Int) {
  face_y := side * mech.ear_out
  tip_y := side * (mech.ear_out - mech.pivot_length)
  head_y := side * (mech.ear_out + mech.pivot_flange)
  construction journal := RodY(a0: tip_y, a1: face_y, r: mech.pivot_d / 2)
  construction flange := Cyl({x: 4.5mm, y: face_y, z: 0mm}, {x: 4.5mm, y: head_y, z: 0mm}, r: 12mm)
  construction hole := Cyl({x: mech.keeper_pitch, y: face_y, z: 0mm}, {x: mech.keeper_pitch, y: head_y, z: 0mm}, r: 2.25mm)
  body := solid(journal.body)
  flange.body union body
  hole.body cut body
  // ISO 4762 M4 × 10. Thread features are represented by the tap-drill cylinder.
  construction thread := Cyl({x: mech.keeper_pitch, y: head_y, z: 0mm}, {x: mech.keeper_pitch, y: head_y - side * 10mm, z: 0mm}, r: 1.65mm)
  construction cap := Cyl({x: mech.keeper_pitch, y: head_y, z: 0mm}, {x: mech.keeper_pitch, y: head_y + side * 4mm, z: 0mm}, r: 3.5mm)
  screw := solid(thread.body)
  cap.body union screw
}

component TiltBush(side: Int) {
  a := side * mech.fork_in
  b := side * mech.fork_out
  c := side * (mech.fork_out + mech.bush_flange)
  construction sleeve := Cyl({x: dims.joint_x, y: a, z: dims.joint_z}, {x: dims.joint_x, y: b, z: dims.joint_z}, r: 8mm)
  construction lip := Cyl({x: dims.joint_x, y: b, z: dims.joint_z}, {x: dims.joint_x, y: c, z: dims.joint_z}, r: 10mm)
  construction bore := Cyl({x: dims.joint_x, y: a, z: dims.joint_z}, {x: dims.joint_x, y: c, z: dims.joint_z}, r: mech.bush_bore / 2)
  body := solid(sleeve.body)
  lip.body union body
  bore.body cut body
}

// Tail frame: origin at the joint, x aft along the shaft, y to starboard.
component Tail() {
  o := point
  fix((0mm, 0mm, 0mm)) o
  // the double U-joint's aft half, and its centre under the boot
  construction uj_hub := RodX(a0: 14mm, a1: mech.uj_length / 2, r: 19mm)
  uj_aft := solid(uj_hub.body)
  uj_centre := solid(std.sets.Ball(o, r: 21mm))
  // the head: a collar on the tube, a bar across, and an ear each side on the tilt pin
  construction collar := OnX(a0: 75mm, a1: 105mm, ro: 26mm, ri: 20mm)
  construction bar := Block({x: 78mm, y: -44mm, z: -8mm}, {x: 100mm, y: 44mm, z: 8mm})
  construction ear_p := Block({x: 0mm, y: -mech.ear_out, z: -14mm}, {x: 95mm, y: -mech.ear_in, z: 14mm})
  construction ear_s := Block({x: 0mm, y: mech.ear_in, z: -14mm}, {x: 95mm, y: mech.ear_out, z: 14mm})
  construction boss_p := Cyl({x: 0mm, y: -mech.ear_out, z: 0mm}, {x: 0mm, y: -mech.ear_in, z: 0mm}, r: 14mm)
  construction boss_s := Cyl({x: 0mm, y: mech.ear_in, z: 0mm}, {x: 0mm, y: mech.ear_out, z: 0mm}, r: 14mm)
  head := solid(collar.body)
  bar.body union head
  ear_p.body union head
  ear_s.body union head
  boss_p.body union head
  boss_s.body union head
  construction head_bore := RodX(a0: 70mm, a1: 110mm, r: 20mm)
  construction pin_hole := Cyl({x: 0mm, y: -50mm, z: 0mm}, {x: 0mm, y: 50mm, z: 0mm}, r: mech.pivot_d / 2)
  head_bore.body cut head
  pin_hole.body cut head
  // The clearance bore and tapping drill run through both cheeks in one setup.
  construction keeper_drill := Cyl({x: mech.keeper_pitch, y: -mech.ear_out - 1mm, z: 0mm}, {x: mech.keeper_pitch, y: mech.ear_out + 1mm, z: 0mm}, r: 1.65mm)
  keeper_drill.body cut head
  pin_port := TiltPin(side: -1)
  pin_stbd := TiltPin(side: 1)
  // the tube, its bushes, the propeller's shaft
  tube := OnX(a0: mech.tail_tube_start, a1: 498mm, ro: 20mm, ri: 18mm)
  bush_fwd := OnX(a0: 100mm, a1: 125mm, ro: 18mm, ri: mech.prop_shaft_d / 2)
  bush_aft := OnX(a0: 470mm, a1: 495mm, ro: 18mm, ri: mech.prop_shaft_d / 2)
  prop_shaft := RodX(a0: 60mm, a1: 535mm, r: mech.prop_shaft_d / 2)
  // the raise line's lug, on top of the tube
  construction lug_plate := Block({x: 115mm, y: -4mm, z: 18mm}, {x: 135mm, y: 4mm, z: 32mm})
  construction lug_hole := Cyl({x: 125mm, y: -5mm, z: 26mm}, {x: 125mm, y: 5mm, z: 26mm}, r: 3mm)
  raise_lug := solid(lug_plate.body)
  lug_hole.body cut raise_lug
  // the guard fin: 6 mm 316 plate welded under the tube, its foot `dims.fin_below_tips` below
  // the blades' tips, ending forward of the blades' sweep
  in std.front {
    f0 := point
    f1 := point
    f2 := point
    f3 := point
    fix((250mm, -18mm)) f0
    fix((470mm, -18mm)) f1
    fix((470mm, -dims.prop_r - dims.fin_below_tips)) f2
    fix((420mm, -dims.prop_r - dims.fin_below_tips)) f3
    fin_outline := line(f0, f1) -> line(f1, f2) -> line(f2, f3) -> line(f3, f0) -> close
  }
  guard_fin := solid(std.solids.Prism(face(fin_outline), from: -3mm, to: 3mm))
}

// -- the heel: bracket, gimbal, stock and steering, in the hull's coordinates -----------------------
// The heel bracket is one CNC-milled 6061 part.
// - Its plate bolts to the skeg's heel with four M8 studs set in epoxy. The shaft's 6004 seats in
//   the plate.
// - Its knee web runs under the hull's bottom (bedded to it) to a plate on the transom's aft face,
//   bedded 3.5 mm off it (the planking's ends are trimmed flush with the transom there), through-bolted
//   with a 9 mm okoumé pad inside.
// - At the web's aft end is the stock's lower boss.
// A welded bracket on the transom near its top holds the upper boss. Both bosses are bushed in
// acetal.
//
// The gimbal fork is clamped to the stock's foot. Its arms reach down either side of the joint to
// two flanged bushes. The tail ears carry the removable Ø12 journals.
// - The stock is 316 tube, 25 × 3, its axis raked with the transom through the joint.
// - On its head, above the deck, the yoke takes the pull-pull cables.
// - The tail's raise line runs up inside the stock.
component Heel() {
  zl := dims.lower_box_z
  sl := (dims.joint_z - dims.lower_box_z) / (dims.joint_x - dims.low_x)
  rake := tan(dims.transom_rake)
  jx := dims.joint_x
  jz := dims.joint_z
  hx := mech.skeg_heel_x
  // -- the bracket
  construction plate := Block({x: hx, y: -25mm, z: 4mm}, {x: hx + 12mm, y: 25mm, z: 83mm})
  construction seat := Cyl({x: hx - 1mm, y: 0mm, z: zl + (hx - 1mm - dims.low_x) * sl}, {x: hx + 13mm, y: 0mm, z: zl + (hx + 13mm - dims.low_x) * sl}, r: 21mm)
  bracket := solid(plate.body)
  centre := plane
  fix(origin == (0mm, 0mm, 0mm)) centre
  fix(dir == (1, 0, 0)) centre.u
  fix(dir == (0, 0, 1)) centre.v
  in centre {
    k0 := point
    k1 := point
    k2 := point
    k3 := point
    k4 := point
    k5 := point
    k6 := point
    k7 := point
    fix((hx + 12mm, 64mm)) k0
    fix((hx + 54mm, 64mm)) k1
    fix((jx - 8mm, 100mm)) k2
    fix((jx + (100mm - jz) * rake + 24mm, 100mm)) k3
    fix((jx + (150mm - jz) * rake + 24mm, 150mm)) k4
    fix((5800mm - (405mm - 170mm) * rake + 3.5mm, 170mm)) k5
    fix((5800mm - (405mm - 90mm) * rake + 3.5mm, 90mm)) k6
    fix((hx + 12mm, 83mm)) k7
    knee_outline := line(k0, k1) -> line(k1, k2) -> line(k2, k3) -> line(k3, k4) -> line(k4, k5) -> line(k5, k6) -> line(k6, k7) -> line(k7, k0) -> close
  }
  construction knee := solid(std.solids.Prism(face(knee_outline), from: -5mm, to: 5mm))
  knee union bracket
  // the transom plate, on the transom's aft face from its bottom up 60
  tp := plane
  fix(origin == (5800mm - (405mm - 112mm) * rake, 0mm, 112mm)) tp
  fix(dir == (0, 1, 0)) tp.u
  fix(dir == (sin(dims.transom_rake), 0, cos(dims.transom_rake))) tp.v
  in tp {
    t0 := point
    t1 := point
    t2 := point
    t3 := point
    fix((-40mm, 0mm)) t0
    fix((40mm, 0mm)) t1
    fix((40mm, 60mm)) t2
    fix((-40mm, 60mm)) t3
    tp_outline := line(t0, t1) -> line(t1, t2) -> line(t2, t3) -> line(t3, t0) -> close
  }
  construction tplate := solid(std.solids.Prism(face(tp_outline), from: 3.5mm, to: 9.5mm))
  tplate.body union bracket
  construction low_boss := Cyl({x: jx + (100mm - jz) * rake, y: 0mm, z: 100mm}, {x: jx + (150mm - jz) * rake, y: 0mm, z: 150mm}, r: 22mm)
  low_boss.body union bracket
  construction low_bore := Cyl({x: jx + (95mm - jz) * rake, y: 0mm, z: 95mm}, {x: jx + (155mm - jz) * rake, y: 0mm, z: 155mm}, r: 15mm)
  low_bore.body cut bracket
  seat.body cut bracket
  // the upper bracket: a plate on the transom, a web out to the boss
  in tp {
    u0 := point
    u1 := point
    u2 := point
    u3 := point
    fix((-35mm, 235mm)) u0
    fix((35mm, 235mm)) u1
    fix((35mm, 285mm)) u2
    fix((-35mm, 285mm)) u3
    up_outline := line(u0, u1) -> line(u1, u2) -> line(u2, u3) -> line(u3, u0) -> close
  }
  upper_bracket := solid(std.solids.Prism(face(up_outline), from: 0mm, to: 6mm))
  construction up_web := Block({x: 5800mm - (405mm - 365mm) * rake, y: -5mm, z: 352mm}, {x: jx + (370mm - jz) * rake, y: 5mm, z: 392mm})
  construction up_boss := Cyl({x: jx + (350mm - jz) * rake, y: 0mm, z: 350mm}, {x: jx + (395mm - jz) * rake, y: 0mm, z: 395mm}, r: 22mm)
  construction up_bore := Cyl({x: jx + (345mm - jz) * rake, y: 0mm, z: 345mm}, {x: jx + (400mm - jz) * rake, y: 0mm, z: 400mm}, r: 15mm)
  up_web.body union upper_bracket
  up_boss.body union upper_bracket
  up_bore.body cut upper_bracket
  // -- the gimbal fork: a crown clamped to the stock's foot, two arms to the tilt pin
  construction crown_hub := Cyl({x: jx + (68mm - jz) * rake, y: 0mm, z: 68mm}, {x: jx + (92mm - jz) * rake, y: 0mm, z: 92mm}, r: 22mm)
  construction crown_bar := Block({x: jx - 12mm, y: -37mm, z: 68mm}, {x: jx + 24mm, y: 37mm, z: 80mm})
  construction arm_p := Block({x: jx - 12mm, y: -mech.fork_out, z: jz - 14mm}, {x: jx + 12mm, y: -mech.fork_in, z: 80mm})
  construction arm_s := Block({x: jx - 12mm, y: mech.fork_in, z: jz - 14mm}, {x: jx + 12mm, y: mech.fork_out, z: 80mm})
  construction eye_p := Cyl({x: jx, y: -mech.fork_out, z: jz}, {x: jx, y: -mech.fork_in, z: jz}, r: 14mm)
  construction eye_s := Cyl({x: jx, y: mech.fork_in, z: jz}, {x: jx, y: mech.fork_out, z: jz}, r: 14mm)
  fork := solid(crown_hub.body)
  crown_bar.body union fork
  arm_p.body union fork
  arm_s.body union fork
  eye_p.body union fork
  eye_s.body union fork
  construction fork_pin := Cyl({x: jx, y: -40mm, z: jz}, {x: jx, y: 40mm, z: jz}, r: 8mm)
  construction stock_hole := Cyl({x: jx + (75mm - jz) * rake, y: 0mm, z: 75mm}, {x: jx + (100mm - jz) * rake, y: 0mm, z: 100mm}, r: 12.5mm)
  fork_pin.body cut fork
  stock_hole.body cut fork
  bush_port := TiltBush(side: -1)
  bush_stbd := TiltBush(side: 1)
  // -- the stock and its yoke
  stock := Pipe({x: jx + (75mm - jz) * rake, y: 0mm, z: 75mm}, {x: jx + (dims.stock_top_z - jz) * rake, y: 0mm, z: dims.stock_top_z}, ro: mech.stock_od / 2, ri: mech.stock_id / 2)
  construction yoke_bar := Cyl({x: jx + (dims.stock_top_z - 12mm - jz) * rake, y: -60mm, z: dims.stock_top_z - 12mm}, {x: jx + (dims.stock_top_z - 12mm - jz) * rake, y: 60mm, z: dims.stock_top_z - 12mm}, r: 7mm)
  construction yoke_hub := Cyl({x: jx + (dims.stock_top_z - 25mm - jz) * rake, y: 0mm, z: dims.stock_top_z - 25mm}, {x: jx + (dims.stock_top_z - jz) * rake, y: 0mm, z: dims.stock_top_z}, r: 18mm)
  yoke := solid(yoke_bar.body)
  yoke_hub.body union yoke
}

// -- the strut: tower to drive bed ------------------------------------------------------------------
// 6061-T6 tube, 25 × 2, with an eye welded to each end. The top eye pins between the upper box's
// lugs. The foot eye pins with an Ø8 ball-lock pin in a clevis, which is screwed and bonded to the
// drive bed.
component Strut() {
  // the lugs' pin, in the upper box's frame at (−35, 0, −68)
  tx := dims.bb_x - 35mm * dims.aft_x + 68mm * dims.down_x
  tz := dims.bb_z - 35mm * dims.aft_z + 68mm * dims.down_z
  fx := mech.strut_foot_x
  fz := mech.strut_foot_z
  tube := Pipe({x: tx, y: 0mm, z: tz}, {x: fx, y: 0mm, z: fz}, ro: mech.strut_od / 2, ri: mech.strut_id / 2)
  top_eye := Pipe({x: tx, y: -9mm, z: tz}, {x: tx, y: 9mm, z: tz}, ro: 10mm, ri: 4mm)
  foot_eye := Pipe({x: fx, y: -9mm, z: fz}, {x: fx, y: 9mm, z: fz}, ro: 10mm, ri: 4mm)
  construction base := Block({x: fx - 35mm, y: -25mm, z: 45mm}, {x: fx + 35mm, y: 25mm, z: 51mm})
  construction ear_p := Block({x: fx - 12mm, y: -16mm, z: 51mm}, {x: fx + 12mm, y: -10mm, z: fz + 12mm})
  construction ear_s := Block({x: fx - 12mm, y: 10mm, z: 51mm}, {x: fx + 12mm, y: 16mm, z: fz + 12mm})
  clevis := solid(base.body)
  ear_p.body union clevis
  ear_s.body union clevis
  construction clevis_hole := Cyl({x: fx, y: -20mm, z: fz}, {x: fx, y: 20mm, z: fz}, r: 4mm)
  clevis_hole.body cut clevis
  foot_pin := Cyl({x: fx, y: -22mm, z: fz}, {x: fx, y: 22mm, z: fz}, r: 4mm)
  top_pin := Cyl({x: tx, y: -20mm, z: tz}, {x: tx, y: 20mm, z: tz}, r: 4mm)
}

// -- the whole, each part where it stands ------------------------------------------------------------
// the frames: the upper box's at stage 1's apex, the keel box's at stage 2's, the tail's at the
// joint, running
component Mechanism() {
  upper_frame := frame
  fix(dir == (dims.aft_x, 0, dims.aft_z)) upper_frame.u
  fix(dir == (0, 1, 0)) upper_frame.v
  fix(origin == (dims.bb_x, 0mm, dims.bb_z)) upper_frame
  keel_frame := frame
  fix(dir == (dims.aft_x, 0, dims.aft_z)) keel_frame.u
  fix(dir == (0, 1, 0)) keel_frame.v
  fix(origin == (dims.low_x, 0mm, dims.lower_box_z)) keel_frame
  tail_frame := frame
  fix(dir == (cos(dims.tail_down), 0, -sin(dims.tail_down))) tail_frame.u
  fix(dir == (0, 1, 0)) tail_frame.v
  fix(origin == (dims.joint_x, 0mm, dims.joint_z)) tail_frame
  in upper_frame {
    upper_box := UpperBox()
  }
  in keel_frame {
    keel_box := KeelBox()
    line_shaft := LineShaft()
  }
  in tail_frame {
    tail := Tail()
  }
  heel := Heel()
  strut := Strut()
}

mechanism := Mechanism()
