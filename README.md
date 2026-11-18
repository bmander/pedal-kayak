# Pedal kayak

A plywood stitch-and-glue pedal kayak for open water in the San Juan Islands. A recumbent pilot
drives a propeller through a geared line shaft that pierces the hull. The hull follows the
Duckling (Sam Devlin's 14′ skiff): six developable hull panels, three a side, plus a transom and
assorted pieces. Every part is drawn in [Solvent](https://github.com/bmander/geomsolver) and
checked with `solventc` v0.1.24.

This file is the design brief. It records what is decided, what is proposed and what is still open.
The `.sv` models will follow it.

## Mission

- **Water:** San Juan Islands. Open water and coastal chop, tidal currents of 2–4 kn in the passes,
  ferry wakes, and water around 10 °C, so the boat must be self-rescuable.
- **Launch:** from a cart, in shallow water. The propeller must not ground while launching or landing.
- **Load:** a pilot alone, with a passenger, or with moderate luggage such as a bicycle.
- **Fit:** adjustable for 98% of adults, from the 1st to the 99th percentile.
- **Speed:** as fast as one person's sustained output allows (about 75–150 W), without giving up the
  load cases above.

## Decided

| Item | Decision |
|---|---|
| Construction | Stitch and glue, with six developable hull panels, a transom, bulkheads, decks and seat parts |
| Propulsion | Pedals and gears driving a propeller shaft that passes through the hull |
| Gears | Designed in full in Solvent, not bought in as an envelope |
| Tooling | `solventc` v0.1.24, using `std.panels` for the hull panels and the spiral bevel and planetary work in `geomsolver/rust/examples/shaft_drive` |

## Proposed (v0): to confirm

### Hull

| Parameter | Value | Reasoning |
|---|---|---|
| LOA | ~5.8 m (19′) | At 4–5 kn a 4.3 m hull runs at Froude number 0.33–0.41, where wave drag climbs steeply. 5.8 m runs at 0.28–0.35. Friction drag rises only ~17% from 4.3 to 5.8 m (ITTC-57 estimate: 18.8 N vs 16.0 N at 4 kn). Length also gives room for a pilot, a cargo well and buoyancy at each end. |
| Beam, sheer / waterline | ~820 mm / ~680 mm at design load | Stability with a raised recumbent seat and a passenger, in chop |
| Depth amidships | ~380 mm | Freeboard for chop at full load |
| Displacement | design ~180 kg (pilot and gear); maximum ~320 kg (pilot, passenger and cargo) | |
| Panels | 6 mm okoumé sides; 9 mm garboards and transom | The garboards carry the shaft fitting, the strut and grounding loads. Each panel needs about three sheets, scarfed. |
| Transom | Immersed at most a little at design load | A transom dragging under water costs speed at kayak speeds |
| Buoyancy | Sealed bulkheads fore and aft; foredeck over the drive; aft deck | Self-rescue in cold water |
| Steering | The propeller tail swings to steer (see below), worked by a hand lever | |

`solventc` refuses a panel whose rails turn back on themselves. Each chine and sheer is therefore
drawn in a plane and kept convex within it.

### Layout, bow to stern (rough)

Bow buoyancy → pedals and gearbox under the foredeck → pilot's seat on rails → cargo well
(passenger or bicycle, ~1.8 m) → shaft exit and strut → transom and rudder → stern buoyancy.

### Ergonomics

- **Fixed crank, sliding seat.** The pedal axle stays put, because the gearbox and the shaft line
  hang from it. The seat slides about 300 mm on rails to cover leg reach from the 1st to the 99th
  percentile. This range is to be confirmed against anthropometric tables.
- Crank length ~155 mm, swappable.
- The seat-back angle is adjustable.
- The passenger sits low in the cargo well, to keep the centre of gravity down.

### Drive

| Parameter | Value |
|---|---|
| Cadence | ~70 rpm |
| Propeller | 2 blades, ~270 mm diameter, ~350 mm pitch, ~420 rpm |
| Overall ratio | ~1 : 6 |
| Train (proposed) | Stage 1: helical planetary, × 3, in the crank housing. Stage 2: spiral bevel, × 2, onto the line shaft. Both adapted from `shaft_drive`. |
| Line shaft | Straight from the gearbox to the stern, down at ~5°, in a tunnel along the keel that doubles as a keelson. One intermediate bearing: an unsupported 3.8 m aluminium tube has its first critical speed near 280 rpm, below the operating speed. |
| Reverse | Pedal backward. No freewheel. |

### Propeller lift for shallow water: hinged tail (sketch 1)

A fixed propeller of this size adds ~250 mm of draft. The proposed answer is a **hinged tail**,
sketched interactively in [`docs/hinged-tail.html`](docs/hinged-tail.html):

- The line shaft runs about 2° down aft. It leaves the hull through the transom in a stern tube
  with a lip seal, about 30 mm below the waterline.
- Just aft of the transom, a constant-velocity (CV) joint drives a 520 mm tail carrying the
  propeller. The tail hangs from a gimbal. Its tilt pin and its steering pin both pass through the
  joint's centre.
- **Running:** the tail sits 24° down on a stop, held there by its weight and a light spring.
  Thrust, ahead or astern, runs through the joint, so it neither deploys nor lifts the tail.
- **Grounding:** a fin about 25 mm below the propeller tips touches first. It kicks the tail up
  and aft.
- **Launching:** a line to a cockpit cleat raises the propeller clear of the water, leaving only
  the hull's ~150 mm draft.
- **Steering:** the tail swings ±25° and steers by aiming the thrust. There is no separate rudder.
- **CV joint angles:** 22° running, ~33° at full helm, 42° raised (drive idle).

An earlier idea put the pivot above the shaft line, so that thrust would hold the tail down. That
needs a second joint and a sliding spline, and the joint angles pass 70° as the tail rises, so it
is dropped. If thrust-held deployment is wanted, the alternative is a leg with bevel gears at the
hinge and at the propeller, like an outboard's lower unit.

## Decided since v0

- **Passenger:** faces forward, sitting low in the cargo well.
- **Bicycle:** lies in the cargo well with its front wheel off. The cockpit opening must therefore
  run the length of the well, about 1.8 m.

## Open questions

1. Hinged tail (sketch 1) vs. the geared leg.
2. Weight budget for cart handling.

## Layout of this repository (planned)

| File | What it is |
|---|---|
| `dims.sv` | The design table: the numbers above, with claims that check them |
| `hull.sv` | Rails, the six panels, the transom, bulkheads, decks and their developments |
| `drive.sv` | Gear train, line shaft, bearings, stern tube, hinged tail and propeller |
| `seat.sv` | Recumbent seat, rails and adjustment, crank and pedal geometry |
| `kayak.sv` | The assembly |
| `*.svd` | Drawings and cut sheets |
