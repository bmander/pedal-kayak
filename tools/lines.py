#!/usr/bin/env python3
"""The pedal kayak's lines: seven rails, each drawn in a plane and convex in it.

The hull is a six-panel stitch-and-glue hull, three strakes a side: the garboard (keel to the
lower chine), the middle strake (lower chine to upper chine) and the sheer strake (upper chine to
sheer). Its seven rails are the keel, in the centreplane, and a lower chine, an upper chine and a
sheer each side. `solventc` refuses a developable panel whose rails fold, so each rail is drawn in
a plane of its own and its half-breadth is concave along the boat: it narrows one way only from
its widest station to each end. Each rail ends on its corner of the transom.

Coordinates, mm: x aft from the stem head, y to starboard (port is -y), z up from the keel's
lowest point (the baseline).

    python3 tools/lines.py            check the rails and print where they run
    python3 tools/lines.py --write    also rewrite the generated rails in hull.sv

The hydrostatics are not here: hydrostatics.sv reads them off the hull as drawn, exactly.
"""
import math
import pathlib
import re
import sys

# -- principal dimensions ---------------------------------------------------------------------
LOA = 5800.0          # stem head to the transom's top
X_MAX = 3000.0        # the widest station
RAKE = math.radians(12)   # the transom leans aft from vertical
STEM_HEAD = (0.0, 540.0)      # (x, z) of the stem's top: the sheer's bow end
FOREFOOT = (430.0, 150.0)     # (x, z) where the keel meets the stem
KEEL_LOW = 3100.0     # the keel's lowest station, z = 0
KEEL_AFT_Z = 112.0    # the keel's height at the transom (its bottom corner)

# Each side rail: its height where it meets the stem, at the widest station (half-breadth,
# height), and at the transom (half-breadth, height); and the exponents of its plan shape forward
# and aft of the widest station (2 is a parabola; larger is fuller).
RAILS = {
    #            bow z   mid (y, z)      transom (y, z)   p_fwd p_aft
    "chine_lo": (250.0, (285.0, 62.0), (205.0, 165.0), 1.9, 2.4),
    "chine_hi": (390.0, (385.0, 185.0), (295.0, 262.0), 1.8, 2.6),
    "sheer":    (540.0, (412.0, 380.0), (322.0, 405.0), 1.7, 2.8),
}



def transom_x(z):
    """The transom plane: x at height z (raked aft by RAKE, its top at LOA)."""
    z_top = RAILS["sheer"][2][1]
    return LOA - (z_top - z) * math.tan(RAKE)


def stem_x(z):
    """The stem line, straight from the forefoot to the stem head: x at height z."""
    (xh, zh), (xf, zf) = STEM_HEAD, FOREFOOT
    return xf + (z - zf) * (xh - xf) / (zh - zf)


class Rail:
    """A side rail: a plane through its three defining points, and a concave plan shape."""

    def __init__(self, name, bow_z, mid, aft, p_fwd, p_aft):
        self.name = name
        self.xb = stem_x(bow_z)
        self.zb = bow_z
        self.ym, self.zm = mid
        self.yt, self.zt = aft
        self.xt = transom_x(self.zt)
        self.p_fwd, self.p_aft = p_fwd, p_aft
        # the plane z = a + b x + c y through the three points (y the half-breadth)
        A = [[1, self.xb, 0.0], [1, X_MAX, self.ym], [1, self.xt, self.yt]]
        rhs = [self.zb, self.zm, self.zt]
        self.a, self.b, self.c = solve3(A, rhs)

    def y(self, x):
        if x <= X_MAX:
            u = (X_MAX - x) / (X_MAX - self.xb)
            return self.ym * (1 - u ** self.p_fwd)
        u = (x - X_MAX) / (self.xt - X_MAX)
        return self.yt + (self.ym - self.yt) * (1 - u ** self.p_aft)

    def z(self, x):
        return self.a + self.b * x + self.c * self.y(x)

    def at(self, x):
        return self.y(x), self.z(x)


def solve3(A, b):
    """Cramer's rule for a 3 × 3 system."""
    def det(m):
        return (m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]))
    d = det(A)
    out = []
    for i in range(3):
        m = [row[:] for row in A]
        for r in range(3):
            m[r][i] = b[r]
        out.append(det(m) / d)
    return out


def keel_z(x):
    """The keel's profile in the centreplane: convex, lowest at KEEL_LOW."""
    if x <= KEEL_LOW:
        u = (KEEL_LOW - x) / (KEEL_LOW - FOREFOOT[0])
        return FOREFOOT[1] * u ** 2
    u = (x - KEEL_LOW) / (keel_aft_x() - KEEL_LOW)
    return KEEL_AFT_Z * u ** 2


def keel_aft_x():
    return transom_x(KEEL_AFT_Z)


SIDE = {name: Rail(name, *spec) for name, spec in RAILS.items()}


# -- the rails' control points ------------------------------------------------------------------
def stations(x0, x1, n):
    """n stations from x0 to x1, closer together toward the ends, where the rails turn fastest."""
    return [x0 + (x1 - x0) * (1 - math.cos(math.pi * i / (n - 1))) / 2 for i in range(n)]


def keel_points(n=9):
    return [(x, 0.0, keel_z(x)) for x in stations(FOREFOOT[0], keel_aft_x(), n)]


def side_points(rail, n=9):
    pts = []
    for x in stations(rail.xb, rail.xt, n):
        y, z = rail.at(x)
        pts.append((x, y, z))
    pts[0] = (rail.xb, 0.0, rail.zb)       # exactly on the stem
    return pts


# -- the rails at a station ------------------------------------------------------------------------
def section(x):
    """The rails' points at x (y >= 0): keel, chine_lo, chine_hi, sheer, or None where x is
    outside a rail's run."""
    pts = []
    if FOREFOOT[0] <= x <= keel_aft_x():
        pts.append((0.0, keel_z(x)))
    else:
        return None
    for name in ("chine_lo", "chine_hi", "sheer"):
        r = SIDE[name]
        if r.xb <= x <= r.xt:
            pts.append(r.at(x))
        else:
            return None
    return pts


def check_rails():
    """Each side rail's plan is concave (narrows one way to each end) and the rails stack
    without crossing: keel < chine_lo < chine_hi < sheer in height, and widening outward."""
    problems = []
    for name, r in SIDE.items():
        xs = [r.xb + (r.xt - r.xb) * i / 400 for i in range(401)]
        ys = [r.y(x) for x in xs]
        for i in range(1, 400):
            if ys[i - 1] - 2 * ys[i] + ys[i + 1] > 1e-6:
                problems.append(f"{name}: plan not concave near x={xs[i]:.0f}")
                break
    for x in range(int(SIDE["sheer"].xb) + 50, int(LOA) - 20, 50):
        sec = section(x)
        if not sec:
            continue
        zs = [p[1] for p in sec]
        if any(zs[i] >= zs[i + 1] for i in range(len(zs) - 1)):
            problems.append(f"rails cross in height at x={x}: {[round(z) for z in zs]}")
            break
    return problems


# -- writing hull.sv's generated block ----------------------------------------------------------
def fmt(v):
    return f"{v:.1f}".rstrip("0").rstrip(".") if abs(v) >= 0.05 else "0"


def rail_block():
    out = ["// BEGIN generated by tools/lines.py: the seven rails. Edit the lines there, not here.",
           "// Each side rail lies in its own plane and narrows one way to each end, so no panel folds."]

    def emit(name, pts, mirror, end):
        """A rail's control points, its last the transom's corner `end`, so the rail ends on it."""
        names = []
        for i, (x, y, z) in enumerate(pts[:-1]):
            n = f"{name}{i}"
            names.append(n)
            yy = -y if mirror else y
            out.append(f"{n} := point hint(({fmt(x)}, {fmt(yy)}, {fmt(z)}))")
            out.append(f"fix(({fmt(x)}mm, {fmt(yy)}mm, {fmt(z)}mm)) {n}")
        return names + [end]

    out.extend(transom_block())
    k = emit("k", keel_points(), False, "t0")
    out.append(f"keel := spline({', '.join(k)})")
    # the transom's ring runs t0 (keel), up the starboard side t1..t3, back down the port t4..t6
    for j, (rail, short) in enumerate((("chine_lo", "cl"), ("chine_hi", "ch"), ("sheer", "sh"))):
        pts = side_points(SIDE[rail])
        for side, mirror, end in (("port", True, f"t{6 - j}"), ("starboard", False, f"t{1 + j}")):
            names = emit(f"{short}{side[0]}", pts, mirror, end)
            out.append(f"{side}_{rail} := spline({', '.join(names)})")
    out.extend(skeg_block())
    out.extend(bulkhead_block())
    out.extend(tunnel_block())
    out.extend(deck_rails_block())
    out.append("// END generated")
    return "\n  ".join(out)


SKEG_FWD = 4000.0      # where the skeg leaves the keel
SKEG_HEEL = 5670.0     # its aft end, short of the transom's bottom: the heel bracket bolts here
                       # (mech.sv: the double U-joint's forward half and the shaft's cartridge)
SKEG_FOOT = 4400.0     # where its bottom reaches the baseline


def skeg_block():
    """The skeg's outline in the centreplane (u = x, v = z): its top along the keel from SKEG_FWD to
    its heel, its heel square, its bottom on the baseline, rising forward to the keel."""
    top = [(x, keel_z(x)) for x in stations(SKEG_FWD, SKEG_HEEL, 7)]
    ring = top + [(SKEG_HEEL, 0.0), (SKEG_FOOT, 0.0)]
    out = ["// the skeg's outline in the centreplane, its top along the keel", "in centre {"]
    names = []
    for i, (x, z) in enumerate(ring):
        n = f"sk{i}"
        names.append(n)
        out.append(f"  {n} := point hint(({fmt(x)}, {fmt(z)}))")
        out.append(f"  fix(({fmt(x)}mm, {fmt(z)}mm)) {n}")
    chain = " -> ".join(f"line({a}, {b})" for a, b in zip(names, names[1:]))
    out.append(f"  skeg_outline := {chain} -> line({names[-1]}, {names[0]}) -> close")
    out.append("}")
    return out


TUNNEL = (2390.0, 5250.0, 116.0)   # the shaft tunnel: from the keel box's output, to, top (outside)
TUNNEL_LID = 9.0                   # its lid's thickness
BED = (1860.0, 2390.0, 45.0)       # the drive bed: from the strut's clevis to the tunnel, its top


def centre_profile(name, ring, prefix):
    out = ["in centre {"]
    names = []
    for i, (x, z) in enumerate(ring):
        n = f"{prefix}{i}"
        names.append(n)
        out.append(f"  {n} := point hint(({fmt(x)}, {fmt(z)}))")
        out.append(f"  fix(({fmt(x)}mm, {fmt(z)}mm)) {n}")
    chain = " -> ".join(f"line({a}, {b})" for a, b in zip(names, names[1:]))
    out.append(f"  {name} := {chain} -> line({names[-1]}, {names[0]}) -> close")
    out.append("}")
    return out


def tunnel_block():
    """The shaft tunnel's profile in the centreplane, its bottom along the keel and its top level;
    its channel's, from below the keel up to the lid's underside; and the drive bed's."""
    x0, x1, top = TUNNEL
    bottom = [(x, keel_z(x)) for x in stations(x0, x1, 7)]
    out = ["// the shaft tunnel's profile and its channel's, in the centreplane"]
    out += centre_profile("tunnel_outline", bottom + [(x1, top), (x0, top)], "tu")
    chan = [(x0 - 1, keel_z(x0) - 30), (x1 + 1, keel_z(x1) - 30), (x1 + 1, top - TUNNEL_LID),
            (x0 - 1, top - TUNNEL_LID)]
    out += centre_profile("channel_outline", chan, "tc")
    # the drive bed: its bottom along the keel, its top level, under the strut's clevis and the keel box
    b0, b1, btop = BED
    bed = [(x, keel_z(x)) for x in stations(b0, b1, 5)]
    out.append("// the drive bed's profile, in the centreplane")
    out += centre_profile("bed_outline", bed + [(b1, btop), (b0, btop)], "db")
    return out


DECKS = {"fore": (None, 1600.0), "aft": (5250.0, None)}   # from, to (None: the rail's end)


def deck_rails_block():
    """Each deck's sheers: the sheer's own points over the deck's length, in the sheer's plane, so each
    deck is a developable between two short rails."""
    out = ["// each deck's two sheers: the sheer over the deck's length"]
    r = SIDE["sheer"]
    for name, (x0, x1) in DECKS.items():
        a = r.xb if x0 is None else x0
        b = r.xt if x1 is None else x1
        pts = [(x, *r.at(x)) for x in stations(a, b, 5)]
        if x0 is None:
            pts[0] = (r.xb, 0.0, r.zb)
        for side, sgn in (("port", -1), ("starboard", 1)):
            names = []
            for i, (x, y, z) in enumerate(pts):
                n = f"d{name[0]}{side[0]}{i}"
                names.append(n)
                out.append(f"{n} := point hint(({fmt(x)}, {fmt(sgn * y)}, {fmt(z)}))")
                out.append(f"fix(({fmt(x)}mm, {fmt(sgn * y)}mm, {fmt(z)}mm)) {n}")
            out.append(f"{name}_{side}_sheer := spline({', '.join(names)})")
    return out


BULKHEADS = {"forward": (1600.0, None), "floor": (2160.0, 110.0), "aft": (5250.0, None)}   # station, top (None: to the sheer)


def bulkhead_block():
    """Each bulkhead's plane (square to the centreline at its station, u to starboard, v up) and its
    outline: the hull's inside at that station, through the rails' points, keel to sheer and across
    the top. Panels are built outboard of their rails, so the rails trace the hull's inside."""
    out = []
    for name, (x, top) in BULKHEADS.items():
        sec = section(x)
        if top is not None:          # a floor: the section below `top`, square across
            low = [sec[0]]
            for (y0, z0), (y1, z1) in zip(sec, sec[1:]):
                if z1 >= top:
                    low.append((y0 + (top - z0) / (z1 - z0) * (y1 - y0), top))
                    break
                low.append((y1, z1))
            sec = low
        ring = [(0.0, sec[0][1])] + [(y, z) for y, z in sec[1:]]
        ring += [(-y, z) for y, z in ring[:0:-1]]
        out.append(f"// the {name} bulkhead, {fmt(x)} aft of the stem head")
        out.append(f"bh_{name} := plane")
        out.append(f"fix(origin == ({fmt(x)}mm, 0mm, 0mm)) bh_{name}")
        out.append(f"fix(dir == (0, 1, 0)) bh_{name}.u")
        out.append(f"fix(dir == (0, 0, 1)) bh_{name}.v")
        out.append(f"in bh_{name} {{")
        names = []
        for i, (y, z) in enumerate(ring):
            n = f"b_{name}{i}"
            names.append(n)
            out.append(f"  {n} := point hint(({fmt(y)}, {fmt(z)}))")
            out.append(f"  fix(({fmt(y)}mm, {fmt(z)}mm)) {n}")
        chain = " -> ".join(f"line({a}, {b})" for a, b in zip(names, names[1:]))
        out.append(f"  bh_{name}_outline := {chain} -> line({names[-1]}, {names[0]}) -> close")
        out.append("}")
    return out


def transom_block():
    """The transom: its plane, raked aft, and its outline through the rails' aft ends, drawn in
    the plane's own coordinates (u athwartships to starboard, v up the rake from the keel)."""
    kx, _, kz = transom_corners()[0]
    s, c = math.sin(RAKE), math.cos(RAKE)
    out = ["// the transom's plane: through the keel's aft end, u to starboard, v up its rake",
           "transom_plane := plane",
           f"fix(origin == ({fmt(kx)}mm, 0mm, {fmt(kz)}mm)) transom_plane",
           "fix(dir == (0, 1, 0)) transom_plane.u",
           f"fix(dir == ({s:.6f}, 0, {c:.6f})) transom_plane.v",
           "in transom_plane {"]
    corners = transom_corners()
    ring = [(0.0, corners[0][2])] + [(y, z) for _, y, z in corners[1:]]
    ring += [(-y, z) for y, z in ring[:0:-1]]     # back down the port side
    names = []
    for i, (y, z) in enumerate(ring):
        n = f"t{i}"
        names.append(n)
        out.append(f"  {n} := point hint(({fmt(y)}, {fmt((z - kz) / c)}))")
        out.append(f"  fix(({fmt(y)}mm, {fmt((z - kz) / c)}mm)) {n}")
    chain = " -> ".join(f"line({a}, {b})" for a, b in zip(names, names[1:]))
    out.append(f"  transom_outline := {chain} -> line({names[-1]}, {names[0]}) -> close")
    out.append("}")
    return out


def transom_pattern_block():
    """The transom's pattern on the 9 mm blank, past the garboards' aft ends: its outline as drawn in
    its plane, laid in the shop floor's."""
    kx, _, kz = transom_corners()[0]
    c = math.cos(RAKE)
    corners = transom_corners()
    ring = [(0.0, corners[0][2])] + [(y, z) for _, y, z in corners[1:]]
    ring += [(-y, z) for y, z in ring[:0:-1]]
    out = []
    ox, oy = 6400.0, 120.0
    out.append("// the transom's pattern on the 9 mm blank: its outline as drawn in its plane")
    out.append("in floor {")
    pnames = []
    for i, (y, z) in enumerate(ring):
        n = f"tp{i}"
        pnames.append(n)
        u, v = y, (z - kz) / c
        out.append(f"  {n} := point hint(({fmt(ox + u)}, {fmt(oy + v)}))")
        out.append(f"  fix(({fmt(ox + u)}mm, {fmt(oy + v)}mm)) {n}")
    for i, (a, b) in enumerate(zip(pnames, pnames[1:] + pnames[:1])):
        out.append(f"  transom_pattern_{i} := line({a}, {b})")
    out.append("}")
    return out


def transom_corners():
    """The transom's corners, starboard side (port mirrors): keel, chine_lo, chine_hi, sheer."""
    pts = [(keel_aft_x(), 0.0, KEEL_AFT_Z)]
    for name in ("chine_lo", "chine_hi", "sheer"):
        r = SIDE[name]
        pts.append((r.xt, r.yt, r.zt))
    return pts


def main():
    probs = check_rails()
    for p in probs:
        print("RAIL PROBLEM:", p)
    print("rails:")
    print(f"  keel      forefoot ({FOREFOOT[0]:.0f}, {FOREFOOT[1]:.0f}) -> transom "
          f"({keel_aft_x():.0f}, {KEEL_AFT_Z:.0f}), lowest at x={KEEL_LOW:.0f}")
    for name, r in SIDE.items():
        print(f"  {name:9} stem ({r.xb:.0f}, {r.zb:.0f})  widest y={r.ym:.0f} z={r.zm:.0f}  "
              f"transom ({r.xt:.0f}, y={r.yt:.0f}, z={r.zt:.0f})  plane z = {r.a:.1f} "
              f"{r.b:+.5f} x {r.c:+.4f} y")
    print("transom corners (starboard):", [tuple(round(v) for v in p) for p in transom_corners()])
    if "--write" in sys.argv:
        hull = pathlib.Path(__file__).resolve().parent.parent / "hull.sv"
        text = hull.read_text()
        new = re.sub(r"// BEGIN generated by.*?// END generated\n", lambda m: rail_block() + "\n", text,
                     flags=re.S)
        new = re.sub(r"// BEGIN generated cut.*?// END generated cut",
                     lambda m: "// BEGIN generated cut\n" + "\n".join(transom_pattern_block())
                     + "\n// END generated cut", new, flags=re.S)
        hull.write_text(new)
        print("wrote", hull)
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main())
