// The pedal kayak, assembled: the hull and the drive in the hull's coordinates (x aft from the stem
// head, y to starboard, z up from the keel's lowest point).
unit mm
use std
use hull (Hull)
use drive (Drive)
use prop (Propeller, Hub, BladeSection)
use seat (Seat, Pilot)
use dims

hull := Hull()
drive := Drive(teeth: 0)        // gear blanks; drive.sv cuts the teeth
seat := Seat(hip_x: dims.hip_x_max)
pilot := Pilot(stature: 1927mm, fll: dims.fll_max, hip_x: dims.hip_x_max)   // 99th-percentile man

// the propeller (prop.sv): designed by tools/propeller.py for minimum induced loss
prop := Propeller()
hub := Hub()
param s: Scalar over (-0.06, 1)
blade_a := solid({ p | some s: p in BladeSection(prop.stack_a, prop.fwd).profile at s })
blade_b := solid({ p | some s: p in BladeSection(prop.stack_b, prop.fwd).profile at s })
