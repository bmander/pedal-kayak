#!/usr/bin/env python3
"""Write kayak.svd: the general arrangement, its views listed solid by solid.

A drawing's view draws one solid, so each view below is repeated for every part it shows. Edit
the part lists here and run `python3 tools/sheets.py`.
"""
import pathlib

HULL = ["starboard_garboard_panel", "starboard_middle_panel", "starboard_sheer_panel", "transom",
        "skeg", "stern_tube", "forward_bulkhead", "floor_frame", "drive_bed", "aft_bulkhead",
        "tunnel", "foredeck", "aft_deck"]
HULL_PLAN = ["port_garboard_panel", "starboard_garboard_panel", "port_middle_panel",
             "starboard_middle_panel", "port_sheer_panel", "starboard_sheer_panel", "transom",
             "skeg", "forward_bulkhead", "floor_frame", "drive_bed", "aft_bulkhead", "tunnel"]
GEARS = ["crank_gear_blank", "tower_pinion_blank", "tower_gear_blank", "line_pinion_blank"]
CRANKS = ["starboard_crank", "port_crank", "starboard_pedal", "port_pedal"]
M = "drive.mechanism."
TOWER = [M + p for p in ["upper_box.housing", "upper_box.cover", "upper_box.crank_axle",
                         "keel_box.housing", "keel_box.lid", "keel_box.latches",
                         "strut.tube.body", "strut.clevis"]]
SHAFT = [M + p for p in ["line_shaft.tube", "line_shaft.bush_block", "line_shaft.cartridge",
                         "line_shaft.stub", "line_shaft.uj_fwd"]]
HEEL = [M + p for p in ["heel.bracket", "heel.upper_bracket", "heel.fork", "heel.bush_port.body", "heel.bush_stbd.body",
                        "tail.pin_port.body", "tail.pin_port.screw", "tail.pin_stbd.body", "tail.pin_stbd.screw",
                        "heel.stock.body", "heel.yoke", "tail.uj_aft", "tail.uj_centre",
                        "tail.head", "tail.tube.body", "tail.prop_shaft.body", "tail.guard_fin"]]
PROP = ["drive.hub", "blade_a", "blade_b"]
SEAT = ["seat.pan", "seat.back"]

DRIVE = ["drive." + g for g in GEARS + CRANKS] + TOWER + SHAFT + HEEL + PROP


def views(prefix, solids, side, at, scale):
    out = []
    for i, name in enumerate(solids):
        ref = name if name.startswith(("drive.", "blade_", "seat.")) else name
        out.append(f"  view {prefix}_{i}(m.{ref}) from {side} at ({at[0]}mm, {at[1]}mm) scale {scale}")
    return out


def main():
    lines = [
        "// kayak.sv on one sheet: the boat and its drive in profile with the port side taken away, in plan",
        "// with the decks lifted, and the stern's drive close up. Written by tools/sheets.py.",
        'model m from "kayak.sv"',
        "",
        "sheet arrangement {",
        "  size (420mm, 297mm)",
        '  label "PEDAL KAYAK  general arrangement. LOA 5800, beam 824, 51 kg; 99th-percentile pilot, seat fully aft" at (14mm, 16mm)',
    ]
    lines += views("profile", ["hull." + h for h in HULL] + DRIVE + SEAT, "front", (30, 110), 0.06)
    lines += views("plan", ["hull." + h for h in HULL_PLAN] + DRIVE + SEAT, "top", (30, 190), 0.06)
    stern = ["hull." + h for h in ["transom", "skeg", "stern_tube", "aft_deck", "aft_bulkhead"]]
    lines += views("stern", stern + SHAFT + HEEL + PROP, "front", (-360, 272), 0.12)
    lines += [
        '  label "Profile from starboard" at (30mm, 62mm)',
        '  label "Plan, decks lifted" at (30mm, 150mm)',
        '  label "The stern, 1:8.3: skeg and stern tube, heel bracket, gimbal, steering stock, tail, propeller" at (30mm, 262mm)',
        "  style .hidden { display: none }",
        "}",
        "",
    ]
    path = pathlib.Path(__file__).resolve().parent.parent / "kayak.svd"
    path.write_text("\n".join(lines))
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
