// Detail view in the boat's coordinates. All displayed parts come from the assembled mechanism.
unit mm
use drive_parts (Mechanism)
construction drive := Mechanism()
fork := solid(drive.heel.fork)
head := solid(drive.tail.head)
port_bush := solid(drive.heel.bush_port.body)
starboard_bush := solid(drive.heel.bush_stbd.body)
port_pin := solid(drive.tail.pin_port.body)
starboard_pin := solid(drive.tail.pin_stbd.body)
port_screw := solid(drive.tail.pin_port.screw)
starboard_screw := solid(drive.tail.pin_stbd.screw)
joint_centre := solid(drive.tail.uj_centre)
