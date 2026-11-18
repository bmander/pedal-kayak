#!/usr/bin/env python3
"""The pedal kayak's lines: seven rails, each drawn in a plane and convex in it, and the
hydrostatics of the hull they bound.

The hull is a six-panel stitch-and-glue hull, three strakes a side: the garboard (keel to the
lower chine), the middle strake (lower chine to upper chine) and the sheer strake (upper chine to
sheer). Its seven rails are the keel, in the centreplane, and a lower chine, an upper chine and a
sheer each side. `solventc` refuses a developable panel whose rails fold, so each rail is drawn in
a plane of its own and its half-breadth is concave along the boat: it narrows one way only from
its widest station to each end.

Coordinates, mm: x aft from the stem head, y to starboard (port is -y), z up from the keel's
lowest point (the baseline).

    python3 tools/lines.py            hydrostatics at the design and the full load
    python3 tools/lines.py --write    also rewrite the generated rails in hull.sv

The hydrostatics read each station as the polygon through the rails' points at that station.
The panels between the rails are ruled surfaces whose rulings are not square to the centreline,
so the section between two rails bows slightly from that polygon. For a slender hull the
difference is small, but these are estimates.
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

RHO = 1025e-9         # seawater, kg / mm^3


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


# -- hydrostatics ---------------------------------------------------------------------------------
def section(x):
    """The half-section at x: the polygon keel, chine_lo, chine_hi, sheer (y >= 0), or None
    where x is outside the rail's run."""
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


def clip_area(poly, T):
    """Area and centroid (y, z) of the half-section polygon closed to the centreline, below z = T.
    Returns (area, z-moment, half-breadth at T)."""
    # closed region: centreline from the keel up to the sheer height, out along the rails
    ring = [(0.0, poly[-1][1])] + poly[::-1]      # (0, sheer z) -> sheer -> ... -> keel
    # clip against z <= T (Sutherland–Hodgman, one edge)
    out = []
    for i in range(len(ring)):
        p, q = ring[i], ring[(i + 1) % len(ring)]
        pin, qin = p[1] <= T, q[1] <= T
        if pin:
            out.append(p)
        if pin != qin:
            t = (T - p[1]) / (q[1] - p[1])
            out.append((p[0] + t * (q[0] - p[0]), T))
    if len(out) < 3:
        return 0.0, 0.0, 0.0
    a = mz = 0.0
    for i in range(len(out)):
        (y0, z0), (y1, z1) = out[i], out[(i + 1) % len(out)]
        cr = y0 * z1 - y1 * z0
        a += cr
        mz += (z0 + z1) * cr
    a /= 2
    mz /= 6
    hb = max((p[0] for p in out if abs(p[1] - T) < 1e-9), default=0.0)
    return abs(a), abs(mz), hb


def hydro(T, dx=10.0):
    """Displacement (kg), LCB (mm from stem), KB, waterline length, beam, BM, wetted-ish."""
    vol = mx = mz = 0.0
    xs_wet = []
    I = 0.0
    bwl = 0.0
    x = FOREFOOT[0]
    while x <= LOA:
        poly = section(x)
        if poly:
            a, mzz, hb = clip_area(poly, T)
            vol += 2 * a * dx
            mx += 2 * a * x * dx
            mz += 2 * mzz * dx
            I += (2 / 3) * hb ** 3 * dx
            bwl = max(bwl, 2 * hb)
            if a > 0:
                xs_wet.append(x)
        x += dx
    if vol == 0:
        return None
    disp = vol * RHO
    lwl = (max(xs_wet) - min(xs_wet)) if xs_wet else 0
    return dict(T=T, disp=disp, vol=vol, lcb=mx / vol, kb=mz / vol, lwl=lwl, bwl=bwl,
                bm=I / vol, cb=vol / (lwl * bwl * T) if lwl and bwl else 0)


def draft_for(kg):
    lo, hi = 1.0, 400.0
    for _ in range(60):
        mid = (lo + hi) / 2
        h = hydro(mid)
        if h is None or h["disp"] < kg:
            lo = mid
        else:
            hi = mid
    h = hydro((lo + hi) / 2)
    assert h is not None
    return h


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

    def emit(name, pts, mirror):
        names = []
        for i, (x, y, z) in enumerate(pts):
            n = f"{name}{i}"
            names.append(n)
            yy = -y if mirror else y
            out.append(f"{n} := point hint(({fmt(x)}, {fmt(yy)}, {fmt(z)}))")
            out.append(f"fix(({fmt(x)}mm, {fmt(yy)}mm, {fmt(z)}mm)) {n}")
        return names

    k = emit("k", keel_points(), False)
    out.append(f"keel := spline({', '.join(k)})")
    for rail, short in (("chine_lo", "cl"), ("chine_hi", "ch"), ("sheer", "sh")):
        pts = side_points(SIDE[rail])
        for side, mirror in (("port", True), ("starboard", False)):
            names = emit(f"{short}{side[0]}", pts, mirror)
            out.append(f"{side}_{rail} := spline({', '.join(names)})")
    out.extend(transom_block())
    out.append("// END generated")
    return "\n".join(out)


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
    # its pattern: the same outline on the 9 mm blank, past the garboards' aft ends
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
    for label, kg in (("light (hull+drive+pilot 60 kg)", 120), ("design (pilot 90 kg + gear)", 180),
                      ("full (pilot, passenger, cargo)", 320)):
        h = draft_for(kg)
        immersion = h["T"] - KEEL_AFT_Z
        print(f"{label:34} {kg:4} kg: draft {h['T']:5.1f}  LWL {h['lwl']:5.0f}  BWL {h['bwl']:4.0f}"
              f"  LCB {h['lcb']:5.0f} ({h['lcb'] / LOA:.3f} LOA)"
              f"  KB {h['kb']:4.0f}  BM {h['bm']:4.0f}  KM {h['kb'] + h['bm']:4.0f}"
              f"  Cb {h['cb']:.2f}  transom immersed {immersion:5.1f}")
    sheer_mid = SIDE["sheer"].z(X_MAX)
    print(f"depth at the widest station: {sheer_mid - keel_z(X_MAX):.0f}; "
          f"freeboard there at full load: {sheer_mid - draft_for(320)['T']:.0f}")
    if "--write" in sys.argv:
        hull = pathlib.Path(__file__).resolve().parent.parent / "hull.sv"
        text = hull.read_text()
        new = re.sub(r"// BEGIN generated.*?// END generated", rail_block(), text, flags=re.S)
        hull.write_text(new)
        print("wrote", hull)
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main())
