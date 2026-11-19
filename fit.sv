// Clearances between the drive's hardware and the hull, each pair that must not touch claimed clear
// by a margin. Building every solid takes about three minutes: `solventc fit.sv`.
unit mm
use std
use hull (Hull)
use drive (Drive)
use seat (Seat)
use dims
hull := Hull()
drive := Drive(teeth: 0)
seat := Seat(hip_x: dims.hip_x_min)
claim drive.mechanism.keel_box.housing clear(1mm) hull.port_garboard_panel
claim drive.mechanism.keel_box.housing clear(1mm) hull.starboard_garboard_panel
claim drive.mechanism.keel_box.housing clear(1mm) hull.floor_frame
claim drive.mechanism.keel_box.housing clear(0.5mm) hull.tunnel
claim drive.mechanism.strut.tube.body clear(5mm) hull.floor_frame
claim drive.mechanism.strut.clevis clear(1mm) hull.floor_frame
claim drive.mechanism.line_shaft.tube clear(3mm) hull.tunnel
claim drive.mechanism.line_shaft.tube clear(2mm) hull.stern_tube
claim drive.mechanism.line_shaft.tube clear(2mm) hull.port_garboard_panel
claim drive.mechanism.line_shaft.stub clear(2mm) hull.skeg
claim drive.mechanism.heel.bracket clear(0.5mm) hull.starboard_garboard_panel
claim drive.mechanism.line_shaft.bush_block clear(0.5mm) hull.tunnel
claim drive.mechanism.line_shaft.stub clear(2mm) hull.stern_tube
claim drive.mechanism.heel.bracket clear(0.5mm) hull.port_garboard_panel
claim drive.mechanism.heel.bracket clear(3mm) hull.transom
claim drive.mechanism.heel.fork clear(2mm) drive.mechanism.heel.bracket
claim drive.mechanism.heel.fork clear(3mm) hull.transom
claim drive.mechanism.tail.head clear(0.5mm) drive.mechanism.heel.fork
claim drive.mechanism.tail.tube.body clear(10mm) hull.transom
claim drive.mechanism.heel.upper_bracket clear(0.5mm) hull.aft_deck
claim drive.crank_gear_blank clear(2mm) drive.mechanism.upper_box.housing
claim drive.tower_pinion_blank clear(2mm) drive.mechanism.upper_box.housing
claim drive.tower_gear_blank clear(2mm) drive.mechanism.keel_box.housing
claim drive.tower_gear_blank clear(2mm) drive.mechanism.keel_box.lid
claim drive.line_pinion_blank clear(2mm) drive.mechanism.keel_box.housing
claim drive.starboard_crank clear(1mm) drive.mechanism.upper_box.cover
claim drive.port_crank clear(1mm) drive.mechanism.upper_box.housing
claim seat.pan clear(10mm) hull.tunnel
claim seat.back clear(10mm) hull.tunnel
