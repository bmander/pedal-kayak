// The pedal kayak, assembled: the hull and the drive in the hull's coordinates (x aft from the stem
// head, y to starboard, z up from the keel's lowest point).
unit mm
use std
use hull (Hull)
use drive (Drive)
use seat (Seat, Pilot)
use dims

hull := Hull()
drive := Drive(teeth: 0)        // gear blanks; drive.sv cuts the teeth
seat := Seat(hip_x: dims.hip_x_max)
pilot := Pilot(stature: 1927mm, fll: dims.fll_max, hip_x: dims.hip_x_max)   // 99th-percentile man
