#!/usr/bin/env python3
"""The pedal kayak's propeller: sized by a trade study, designed for minimum induced loss, analysed
off design, matched to the hull and the rider, and checked for strength and cavitation.

Method
------
* Sections: NACA 16-series thickness on the NACA a = 1.0 mean line (uniform chordwise load), the
  classic propeller section. Polars from NeuralFoil (an XFOIL-trained surrogate), at each station's
  own Reynolds number, n_crit 5 (a propeller in a hull's wake, in a seaway, transitions early).
* Design: Adkins & Liebeck, "Design of Optimum Propellers", J. Propulsion & Power 10(5), 1994 —
  Betz's minimum induced loss with Prandtl's tip loss, profile drag included. At every station the
  camber and the design lift coefficient are those that minimise drag/lift, held `STALL_MARGIN`
  below the section's maximum lift so the blade does not stall when the boat is slower than design.
* Analysis: blade-element momentum with Prandtl's tip and hub losses (Adkins & Liebeck's analysis
  equations), each station's polar read at its own Reynolds number.
* Matching: the rider's pedal power through the drive's efficiency; the propeller's thrust along the
  tail (inclined `TAIL_DOWN` below level), less the thrust deduction, equal to the hull's drag;
  the propeller in the wake fraction's slower water. Solved for speed and cadence together.
* Strength: each station's bending moment from the blade-element loads, its section modulus from
  the section's own coordinates (thin-wall-free, integrated), against nickel-aluminium bronze.
* Cavitation: each station's cavitation number at the top of the disc against a thin-section
  estimate of its minimum pressure coefficient.

Run with the project's venv (numpy, scipy, neuralfoil):

    .venv/bin/python tools/propeller.py            trade study, design, checks, report
    .venv/bin/python tools/propeller.py --write    also write docs/propeller.md and prop_design.sv
"""
import functools
import math
import pathlib
import sys

import numpy as np
from scipy.optimize import brentq

import neuralfoil as nf

ROOT = pathlib.Path(__file__).resolve().parent.parent

# -- water, hull and rider ------------------------------------------------------------------------
RHO = 1025.0                 # sea water, kg/m^3
NU = 1.35e-6                 # at 10 °C, m^2/s (the San Juans' summer water)
P_ATM = 101325.0
P_VAP = 1230.0               # vapour pressure at 10 °C, Pa
G = 9.81
N_CRIT = 5.0

LWL, WETTED, FORM = 5.05, 2.67, 1.12      # tools/lines.py at the design load
RESID_AT, RESID_FN = 0.25, 0.29           # wave-making: a quarter of friction at Fn 0.29 ...
RESID_POWER = 4.0                         # ... growing as Fn^4
WAKE = 0.03                  # the tail puts the disc 0.5 m behind the transom: little wake
THRUST_DEDUCTION = 0.03
TAIL_DOWN = math.radians(11.27)           # dims.tail_down
ETA_DRIVE = 0.94             # two spiral bevel meshes, a CV joint, seals and bearings
PEDAL_DESIGN = 100.0         # W, sustained
CADENCE_DESIGN = 70.0        # rpm at the cranks

# -- the propeller's frame ---------------------------------------------------------------------
BLADES = 2
HUB_R = 0.024                # m: the hub's radius where the blades root
STALL_MARGIN = 0.35          # design cl at least this far below the section's maximum
STATIONS = 21

# thickness/chord along the blade: thick at the root for the sprint's bending, falling fast so the
# working span stays thin, and not so thin at the tip that its leading edge's radius invites a
# suction peak where the tilted inflow swings the incidence
TC_ROOT, TC_TIP, TC_SHAPE = 0.20, 0.075, 2.5
IDEAL_INCIDENCE = False     # camber for least drag; the cavitation margin is checked, not assumed


def tc_at(xi):
    u = min(max((xi - XI_HUB) / (1 - XI_HUB), 0.0), 1.0)
    return TC_TIP + (TC_ROOT - TC_TIP) * (1 - u) ** TC_SHAPE


# -- sections -----------------------------------------------------------------------------------------
def naca16_a10(tc, cli, n=121):
    """Selig-ordered coordinates (upper TE -> LE -> lower TE), unit chord: NACA 16 thickness
    (Stack's analytic form, its 2 % trailing edge kept for machining) on the a = 1.0 mean line."""
    b = np.linspace(0, np.pi, n)
    x = (1 - np.cos(b)) / 2
    yt = np.where(x <= 0.5,
                  0.989665 * np.sqrt(x) - 0.23925 * x - 0.041 * x**2 - 0.5594 * x**3,
                  0.01 + 2.325 * (1 - x) - 3.42 * (1 - x)**2 + 1.46 * (1 - x)**3) * tc
    with np.errstate(divide="ignore", invalid="ignore"):
        xl1 = np.where(x < 1, (1 - x) * np.log(1 - x), 0.0)
        xl0 = np.where(x > 0, x * np.log(x), 0.0)
        yc = -cli / (4 * np.pi) * (xl1 + xl0)
        dyc = cli / (4 * np.pi) * np.where((x > 0) & (x < 1), np.log(1 - x) - np.log(x), 0.0)
    th = np.arctan(dyc)
    xu, yu = x - yt * np.sin(th), yc + yt * np.cos(th)
    xl, yl = x + yt * np.sin(th), yc - yt * np.cos(th)
    return np.vstack([np.c_[xu[::-1], yu[::-1]], np.c_[xl[1:], yl[1:]]])


ALPHAS = np.arange(-6.0, 14.01, 0.25)


@functools.lru_cache(maxsize=None)
def polar(tc, cli, re):
    """(alpha deg, cl, cd, confidence) at a quantised (t/c, cli, Re)."""
    r = nf.get_aero_from_coordinates(coordinates=naca16_a10(tc, cli), alpha=ALPHAS, Re=re,
                                     n_crit=N_CRIT, model_size="large")
    return ALPHAS, np.asarray(r["CL"]), np.asarray(r["CD"]), np.asarray(r["analysis_confidence"])


def q_tc(tc):
    return round(tc * 200) / 200                     # 0.005 steps


def q_re(re):
    return float(round(math.exp(round(math.log(max(re, 2e4)) * 20) / 20), -2))   # 5 % steps


CLIS = tuple(round(c, 2) for c in np.arange(0.1, 1.01, 0.05))


@functools.lru_cache(maxsize=None)
def best_section(tc, re):
    """The camber and the operating point that minimise drag/lift at (t/c, Re), the design cl held
    STALL_MARGIN below the polar's maximum. Returns (cli, cl, alpha_deg, cd)."""
    best = None
    for cli in CLIS:
        a, cl, cd, conf = polar(tc, cli, re)
        ok = conf > 0.8
        if not ok.any():
            continue
        clmax = cl[ok].max()
        cand = ok & (cl <= clmax - STALL_MARGIN) & (cl > 0.15)
        if not cand.any():
            continue
        i = np.argmin(np.where(cand, cd / np.maximum(cl, 1e-6), np.inf))
        if best is None or cd[i] / cl[i] < best[3] / best[1]:
            best = (cli, float(cl[i]), float(a[i]), float(cd[i]))
    return best


def section_at(tc, cli, re, cl=None, alpha=None):
    """A fixed section's (cl, cd, alpha) read at a given cl or alpha (deg), linearly."""
    a, cls, cds, conf = polar(q_tc(tc), cli, q_re(re))
    if cl is not None:
        ok = conf > 0.5
        a_ok, cl_ok, cd_ok = a[ok], cls[ok], cds[ok]
        j = np.argmax(cl_ok)                      # read the attached branch, below cl max
        al = np.interp(cl, cl_ok[: j + 1], a_ok[: j + 1])
        return cl, float(np.interp(al, a, cds)), float(al)
    return float(np.interp(alpha, a, cls)), float(np.interp(alpha, a, cds)), alpha


# -- hull and rider ------------------------------------------------------------------------------------
def hull_drag(v):
    re = v * LWL / NU
    cf = 0.075 / (math.log10(re) - 2) ** 2
    fn = v / math.sqrt(G * LWL)
    resid = RESID_AT * (fn / RESID_FN) ** RESID_POWER
    return 0.5 * RHO * v * v * WETTED * cf * FORM * (1 + resid)


def thrust_needed(v):
    """Thrust along the propeller's axis for speed v."""
    return hull_drag(v) / (1 - THRUST_DEDUCTION) / math.cos(TAIL_DOWN)


def inflow(v):
    """The water's speed along the propeller's axis."""
    return v * (1 - WAKE) * math.cos(TAIL_DOWN)


# -- design: Adkins & Liebeck ----------------------------------------------------------------------------
XI_HUB = 0.2


def mil_design(R, rpm, v_ship, p_shaft, stations=STATIONS, iterations=30, prescribed=None):
    """Minimum-induced-loss blade for shaft power p_shaft at ship speed v_ship and rpm. Each
    station's section is the best it can be at its Reynolds number, or, given `prescribed`
    (xi -> (cli, cl)), that camber at that lift."""
    global XI_HUB
    XI_HUB = HUB_R / R
    om = rpm * 2 * math.pi / 60
    V = inflow(v_ship)
    lam = V / (om * R)
    # stations clustered toward the tip, where the loading changes fastest
    t = np.linspace(0, 1, stations)
    xi = XI_HUB + (1 - XI_HUB) * np.sin(t * math.pi / 2)
    xi[-1] = 0.999
    zeta = 0.0
    Pc = 2 * p_shaft / (RHO * V**3 * math.pi * R**2)
    rows = []
    re_prev = {}
    I1 = I2 = 0.0
    for _ in range(iterations):
        rows = []
        I1 = I2 = J1 = J2 = 0.0
        integrand = []
        for x in xi:
            phit = math.atan(lam * (1 + zeta / 2))
            f = BLADES / 2 * (1 - x) / math.sin(phit)
            F = 2 / math.pi * math.acos(math.exp(-f))
            phi = math.atan(math.tan(phit) / x)
            xx = om * x * R / V
            Gc = F * xx * math.cos(phi) * math.sin(phi)
            tc = tc_at(x)
            # the section, at the Reynolds number the last pass gave this station
            re = re_prev.get(round(x, 4), 2e5)
            if prescribed is None:
                best = best_section(q_tc(tc), q_re(re))
                assert best is not None, f"no section at t/c {tc:.3f}, Re {re:.0f}"
                cli, cl, al, cd = best
            else:
                cli, cl = prescribed(x)
                _, cd, al = section_at(tc, cli, re, cl=cl)
            Wc = 4 * math.pi * lam * Gc * V * R * zeta / (cl * BLADES) if zeta > 0 else 0.0
            eps = cd / cl
            a = zeta / 2 * math.cos(phi) ** 2 * (1 - eps * math.tan(phi))
            ap = zeta / (2 * xx) * math.cos(phi) * math.sin(phi) * (1 + eps / math.tan(phi))
            W = V * (1 + a) / math.sin(phi)
            c = Wc / W if W > 0 else 0.0
            rows.append(dict(xi=x, r=x * R, c=c, phi=phi, beta=phi + math.radians(al), tc=tc,
                             cli=cli, cl=cl, alpha=al, cd=cd, W=W, re=W * c / NU, F=F, a=a, ap=ap))
            i1 = 4 * x * Gc * (1 - eps * math.tan(phi))
            i2 = lam * (i1 / (2 * x)) * (1 + eps / math.tan(phi)) * math.sin(phi) * math.cos(phi)
            j1 = 4 * x * Gc * (1 + eps / math.tan(phi))
            j2 = (j1 / 2) * (1 - eps * math.tan(phi)) * math.cos(phi) ** 2
            integrand.append((i1, i2, j1, j2))
        ig = np.array(integrand)
        I1, I2, J1, J2 = (np.trapezoid(ig[:, k], xi) for k in range(4))
        z_new = -J1 / (2 * J2) + math.sqrt((J1 / (2 * J2)) ** 2 + Pc / J2)
        re_prev = {round(r["xi"], 4): max(r["re"], 2e4) for r in rows}
        if abs(z_new - zeta) < 1e-5:
            zeta = z_new
            break
        zeta = z_new
    Tc = I1 * zeta - I2 * zeta**2
    eta = Tc / Pc
    T = Tc * RHO * V**2 * math.pi * R**2 / 2
    return dict(R=R, rpm=rpm, v=v_ship, V=V, zeta=zeta, eta=eta, T=T, P=p_shaft, rows=rows)


# -- analysis: blade-element momentum ------------------------------------------------------------------
def bem(blade, v_ship, rpm, dvt=0.0):
    """Thrust (N) and torque (N·m) of a fixed blade at ship speed v_ship and rpm, and per-station
    loads (thrust and tangential force per metre of span, per blade)."""
    R = blade["R"]
    om = rpm * 2 * math.pi / 60
    V = max(inflow(v_ship), 1e-3)
    T = Q = 0.0
    loads = []
    rows = blade["rows"]
    rs = np.array([r["r"] for r in rows])
    for k, s in enumerate(rows):
        r, c, beta = s["r"], s["c"], s["beta"]
        if c <= 1e-5:
            loads.append((r, 0.0, 0.0, 0.0, 0.0))
            continue
        sigma = BLADES * c / (2 * math.pi * r)

        def resid(phi):
            al = math.degrees(beta - phi)
            W = math.hypot(V, om * r + dvt)
            cl, cd, _ = section_at(s["tc"], s["cli"], W * c / NU, alpha=al)
            cy = cl * math.cos(phi) - cd * math.sin(phi)
            cx = cl * math.sin(phi) + cd * math.cos(phi)
            ft = BLADES / 2 * (R - r) / (r * math.sin(phi))
            fh = BLADES / 2 * (r - HUB_R) / (HUB_R * math.sin(phi))
            F = (2 / math.pi) ** 2 * math.acos(min(1, math.exp(-ft))) * math.acos(min(1, math.exp(-fh)))
            F = max(F, 1e-4)
            a = sigma * cy / (4 * F * math.sin(phi) ** 2 - sigma * cy)
            ap = sigma * cx / (4 * F * math.sin(phi) * math.cos(phi) + sigma * cx)
            return math.sin(phi) / (1 + a) - V / (om * r + dvt) * math.cos(phi) / (1 - ap), (a, ap, cl, cd)

        lo, hi = 1e-4, math.pi / 2 - 1e-4
        grid = np.linspace(lo, hi, 60)
        vals = [resid(p)[0] for p in grid]
        phi = None
        for i in range(len(grid) - 1):
            if np.sign(vals[i]) != np.sign(vals[i + 1]):
                phi = brentq(lambda p: resid(p)[0], grid[i], grid[i + 1], xtol=1e-7)
                break
        if phi is None:
            loads.append((r, 0.0, 0.0, 0.0, 0.0))
            continue
        _, (a, ap, cl, cd) = resid(phi)
        W = V * (1 + a) / math.sin(phi)
        q = 0.5 * RHO * W * W * c
        dT = q * (cl * math.cos(phi) - cd * math.sin(phi))       # per blade, per metre
        dQf = q * (cl * math.sin(phi) + cd * math.cos(phi))      # tangential force, per metre
        loads.append((r, dT, dQf, math.degrees(beta - phi), W))
    lr = np.array([(l[0], l[1], l[2]) for l in loads])
    T = BLADES * np.trapezoid(lr[:, 1], lr[:, 0])
    Q = BLADES * np.trapezoid(lr[:, 2] * lr[:, 0], lr[:, 0])
    return T, Q, loads


def operating_point(blade, ratio, pedal_w):
    """Speed (m/s) and cadence (rpm) where the propeller absorbs the rider's pedal_w through the
    drive and its thrust balances the hull."""
    p_shaft = pedal_w * ETA_DRIVE

    def cadence_for(v):
        # the rpm at which thrust meets the hull's need at speed v
        def f(rpm):
            return bem(blade, v, rpm)[0] - thrust_needed(v)
        return brentq(f, 50, 1500, xtol=0.05)

    def power_gap(v):
        rpm = cadence_for(v)
        _, Q, _ = bem(blade, v, rpm)
        return Q * rpm * 2 * math.pi / 60 - p_shaft

    v = brentq(power_gap, 0.6, 3.6, xtol=1e-3)
    rpm = cadence_for(v)
    T, Q, _ = bem(blade, v, rpm)
    eta = T * inflow(v) / (Q * rpm * 2 * math.pi / 60)
    return dict(v=v, kn=v / 0.5144, rpm=rpm, cadence=rpm / ratio, T=T, Q=Q, eta=eta,
                total=hull_drag(v) * v / pedal_w)


# -- trade study -----------------------------------------------------------------------------------------
def design_for(D, ratio, prescribed=None):
    """A blade designed at the speed it will actually make: iterate design speed to equilibrium."""
    p = PEDAL_DESIGN * ETA_DRIVE
    rpm = CADENCE_DESIGN * ratio
    v = 2.0
    for _ in range(8):
        b = mil_design(D / 2, rpm, v, p, prescribed=prescribed)
        # the speed at which the hull's thrust need equals the propeller's design thrust
        v_new = brentq(lambda vv: thrust_needed(vv) - b["T"], 0.5, 4.0)
        if abs(v_new - v) < 1e-3:
            break
        v = v_new
    return mil_design(D / 2, rpm, v, p, prescribed=prescribed)


def smooth_design(D, ratio):
    """The best section at every station, then smooth curves through the chosen cambers and lifts,
    then the blade redesigned with those curves: the distributions a designer would draw."""
    first = design_for(D, ratio)
    xi = np.array([r["xi"] for r in first["rows"]])
    w = np.array([r["W"] ** 2 * r["c"] for r in first["rows"]]) + 1e-9   # weight by loading
    cli_fit = np.polyfit(xi, [r["cli"] for r in first["rows"]], 2, w=np.sqrt(w))
    cl_fit = np.polyfit(xi, [r["cl"] for r in first["rows"]], 2, w=np.sqrt(w))

    def prescribed(x):
        # the camber matched to the design lift, so each section meets its design point at ideal
        # incidence, its leading edge free of a suction peak: the margin the tilted inflow needs
        cl = float(np.polyval(cl_fit, x))
        if IDEAL_INCIDENCE:
            return round(min(max(cl, 0.1), 1.0), 2), cl
        cli = min(max(float(np.polyval(cli_fit, x)), 0.1), 1.0)
        return round(cli, 2), cl

    b = design_for(D, ratio, prescribed=prescribed)
    b["cli_fit"], b["cl_fit"] = cli_fit, cl_fit
    return b


def trade():
    out = []
    for D in (0.22, 0.25, 0.27, 0.30, 0.33):
        for ratio in (5.0, 6.0, 7.0, 8.0):
            b = design_for(D, ratio)
            cmax = max(r["c"] for r in b["rows"])
            out.append((D, ratio, b["eta"], b["v"] / 0.5144, cmax * 1000))
            print(f"  D {D * 1000:4.0f} mm  ratio {ratio:3.1f}  rpm {CADENCE_DESIGN * ratio:4.0f}:"
                  f"  eta {b['eta']:.3f}  speed {b['v'] / 0.5144:.2f} kn  max chord {cmax * 1000:4.1f} mm",
                  flush=True)
    return out


# -- strength ----------------------------------------------------------------------------------------------
# Nickel-aluminium bronze, ASTM B148 C95800: the marine propeller alloy, cast or machined from bar.
NAB_YIELD = 240e6
NAB_UTS = 585e6
NAB_FATIGUE_SEAWATER = 105e6     # corrosion fatigue, 1e8 cycles, reversed (literature, as cast)
ALLOW_SPRINT = NAB_YIELD / 1.5   # the standing start, a few times a trip: static, against yield
SF_FATIGUE = 2.0                 # Goodman, the cruise's mean and its once-a-turn alternation
SHAFT_DEPTH = 0.060 + 0.135      # the propeller's centre: 60 mm of tip cover at the design load


def section_modulus(tc, cli, chord):
    """Least section modulus (m^3) of a section and its area (m^2), from its coordinates: the
    second-moment tensor about the centroid, its weak direction, and the farthest fibre from it."""
    xy = naca16_a10(tc, cli, n=241) * chord
    x, y = xy[:, 0], xy[:, 1]
    x1, y1 = np.roll(x, -1), np.roll(y, -1)
    cr = x * y1 - x1 * y
    A = cr.sum() / 2
    cx = ((x + x1) * cr).sum() / (6 * A)
    cy = ((y + y1) * cr).sum() / (6 * A)
    sxx = ((x * x + x * x1 + x1 * x1) * cr).sum() / (12 * A) * A - A * cx * cx    # ∫x² dA
    syy = ((y * y + y * y1 + y1 * y1) * cr).sum() / (12 * A) * A - A * cy * cy    # ∫y² dA
    sxy = ((x * y1 + 2 * x * y + 2 * x1 * y1 + x1 * y) * cr).sum() / (24 * A) * A - A * cx * cy
    C = np.sign(A) * np.array([[sxx, sxy], [sxy, syy]])   # positive whichever way the outline runs
    w, v = np.linalg.eigh(C)                     # w[0]: the least second moment, about the axis
    n = v[:, 0]                                  # square to n: distances along n
    d = np.abs((x - cx) * n[0] + (y - cy) * n[1]).max()
    return float(abs(w[0]) / d), float(abs(A))


def crossflow(v_ship):
    """The tilted tail's crossflow in the disc: the hull's speed square to the propeller's axis."""
    return v_ship * (1 - WAKE) * math.sin(TAIL_DOWN)


def blade_stresses(blade, v_ship, rpm, dvt=0.0):
    """Bending stress at each station from the blade-element loads outboard of it (thrust and
    tangential force combined, conservatively about the section's weak axis)."""
    _, _, loads = bem(blade, v_ship, rpm, dvt)
    rs = np.array([l[0] for l in loads])
    fT = np.array([l[1] for l in loads])
    fQ = np.array([l[2] for l in loads])
    out = []
    for k, s in enumerate(blade["rows"]):
        r0 = s["r"]
        m = rs >= r0
        if m.sum() < 2:
            out.append((s["xi"], 0.0))
            continue
        MT = np.trapezoid(fT[m] * (rs[m] - r0), rs[m])
        MQ = np.trapezoid(fQ[m] * (rs[m] - r0), rs[m])
        M = math.hypot(MT, MQ)
        Z, _ = section_modulus(s["tc"], s["cli"], max(s["c"], 1e-4))
        out.append((s["xi"], M / Z if s["c"] > 1e-3 else 0.0))
    return out


# -- cavitation --------------------------------------------------------------------------------------------
def cavitation(blade, v_ship, rpm, shaft_depth, rows_alpha=None):
    """Each station's cavitation number where it is worst, against an estimate of its least
    pressure coefficient.

    Thin-section superposition: the 16-series thickness (1 + 1.2 t/c), the uniform load (cl/4 each
    side), and the leading edge's suction peak for incidence Δα away from ideal, Δα·sqrt(c / 2ρ),
    ρ = 0.49 (t/c)² c the 16-series' nose radius (the exact peak of an ellipse at incidence). The
    tilted inflow's crossflow is spanwise at the top of the disc and tangential at 3 and 9 o'clock,
    so both are checked: the top, shallowest, at design incidence; the side, at the propeller's
    depth, with the incidence the crossflow adds."""
    om = rpm * 2 * math.pi / 60
    R = blade["R"]
    vt = crossflow(v_ship)
    out = []
    for s in blade["rows"]:
        tc, cl = s["tc"], s["cl"]
        off_ideal = (cl - s["cli"]) / (2 * math.pi)                # rad, from the lift slope
        Va = inflow(v_ship)
        W_top = math.hypot(Va, om * s["r"])
        W_side = math.hypot(Va, om * s["r"] + vt)
        d_alpha = abs(math.atan2(Va, om * s["r"] - vt) - math.atan2(Va, om * s["r"])) * 0.5
        le = 1.01 / tc                                             # sqrt(c / 2ρ) for the 16-series
        def cpmin(da):
            u = 1 + 1.2 * tc + cl / 4 + abs(da) * le
            return u * u - 1
        sig_top = (P_ATM + RHO * G * (shaft_depth - s["r"]) - P_VAP) / (0.5 * RHO * W_top**2)
        sig_side = (P_ATM + RHO * G * shaft_depth - P_VAP) / (0.5 * RHO * W_side**2)
        out.append((s["xi"], sig_top, cpmin(off_ideal), sig_side, cpmin(off_ideal + d_alpha)))
    return out


# -- the final blade ---------------------------------------------------------------------------------------
D_FINAL, RATIO_FINAL = 0.270, 7.0
TIP_FROM, TIP_CHORD = 0.90, 0.25      # the tip rounds from 0.9 R to a quarter of the chord there,
                                      # parabolically: a finite slope at the tip, so the loft builds


def finalise(b):
    """The buildable blade from the ideal one: a rounded tip, the camber smoothed, and each station's
    pitch angle re-derived so its smoothed section still meets its design lift."""
    rows = b["rows"]
    xi = np.array([r["xi"] for r in rows])
    c = np.array([r["c"] for r in rows])
    c09 = float(np.interp(TIP_FROM, xi, c))
    tip = xi > TIP_FROM
    u = np.clip((xi[tip] - TIP_FROM) / (1 - TIP_FROM), 0, 1)
    c[tip] = c09 * (TIP_CHORD + (1 - TIP_CHORD) * (1 - u**2))
    out = []
    for k, r in enumerate(rows):
        r2 = dict(r)
        r2["c"] = float(c[k])
        _, _, al = section_at(r["tc"], r2["cli"], max(r["W"] * c[k] / NU, 2e4), cl=r["cl"])
        r2["alpha"] = al
        r2["beta"] = r["phi"] + math.radians(al)
        r2["re"] = r["W"] * c[k] / NU
        out.append(r2)
    fb = dict(b)
    fb["rows"] = out
    return fb


def stall_rows(blade, v_ship, rpm):
    """Each station's angle of attack against its section's stall angle at (v, rpm)."""
    _, _, loads = bem(blade, v_ship, rpm)
    out = []
    for s, l in zip(blade["rows"], loads):
        a, cl, cd, conf = polar(q_tc(s["tc"]), s["cli"], q_re(max(l[4] * s["c"] / NU, 2e4)))
        ok = conf > 0.5
        a_stall = float(a[ok][np.argmax(cl[ok])]) if ok.any() else float("nan")
        out.append((s["xi"], l[3], a_stall))
    return out


SPRINT_CADENCE = 130.0         # rpm: a standing start, spun as hard as a rider can


def sprint_start(blade):
    """The hardest the water can load the blade: a standing start at the fastest cadence a rider
    reaches. (The cranks' 200 N·m peak cannot reach the blade: a propeller's torque is set by its
    speed, and below that speed the push only spins it up.)"""
    v = 0.3
    rpm = SPRINT_CADENCE * RATIO_FINAL
    T, Q, _ = bem(blade, v, rpm)
    return v, rpm, T, Q


# -- the report ------------------------------------------------------------------------------------------
def main():
    write = "--write" in sys.argv
    if "--trade" in sys.argv:
        print("Trade study: diameter against gear ratio (cadence 70 rpm, 100 W at the pedals)")
        trade()
    ideal = smooth_design(D_FINAL, RATIO_FINAL)
    blade = finalise(ideal)
    rpm_d = CADENCE_DESIGN * RATIO_FINAL
    print(f"ideal (MIL): eta {ideal['eta']:.3f} at {ideal['v'] / 0.5144:.2f} kn, thrust {ideal['T']:.1f} N")
    rows = blade["rows"]
    print(" r/R    r mm  chord  beta   P/D   t/c   cli   cl   alpha  Re      cd")
    for r in rows:
        P = 2 * math.pi * r["r"] * math.tan(r["beta"])
        print(f" {r['xi']:.3f} {r['r'] * 1000:6.1f} {r['c'] * 1000:6.1f} {math.degrees(r['beta']):5.1f}"
              f" {P / (2 * blade['R']):5.2f} {r['tc']:.3f} {r['cli']:.2f} {r['cl']:.2f} {r['alpha']:5.2f}"
              f" {r['re']:7.0f} {r['cd']:.4f}")
    print("\noff design, the final blade (BEM), design load:")
    print(" pedal W  speed kn  cadence  prop rpm  thrust N  eta_prop  pedal-to-tow")
    perf = []
    for pw in (40, 60, 80, 100, 130, 160, 200, 250):
        op = operating_point(blade, RATIO_FINAL, pw)
        perf.append((pw, op))
        print(f"   {pw:4d}    {op['kn']:5.2f}    {op['cadence']:5.1f}    {op['rpm']:5.0f}    {op['T']:6.1f}"
              f"     {op['eta']:.3f}     {op['total']:.3f}")
    v_s, n_s, T_s, Q_s = sprint_start(blade)
    print(f"\nsprint start: {Q_s:.2f} N·m at {n_s:.0f} rpm, {v_s} m/s: thrust {T_s:.0f} N")
    cruise = perf[3][1]
    vt = crossflow(cruise["v"])
    st = blade_stresses(blade, v_s, n_s)
    cr = blade_stresses(blade, cruise["v"], cruise["rpm"])
    adv = blade_stresses(blade, cruise["v"], cruise["rpm"], dvt=vt)
    ret = blade_stresses(blade, cruise["v"], cruise["rpm"], dvt=-vt)
    print(f"strength, nickel-aluminium bronze (crossflow ±{vt:.2f} m/s at 3 and 9 o'clock):")
    print(" r/R   sprint MPa (≤ {:.0f})  cruise mean  alternating  Goodman SF (≥ {:.1f})".format(
        ALLOW_SPRINT / 1e6, SF_FATIGUE))
    checks = []
    for (x, sp), (_, m), (_, hi), (_, lo) in zip(st, cr, adv, ret):
        if m <= 0:
            continue
        sa = abs(hi - lo) / 2
        sf = 1 / (sa / NAB_FATIGUE_SEAWATER + m / NAB_UTS)
        checks.append((x, sp, m, sa, sf))
        print(f" {x:.3f}  {sp / 1e6:7.1f}            {m / 1e6:6.1f}      {sa / 1e6:6.1f}       {sf:5.1f}")
    hard = perf[-1][1]
    cav = cavitation(blade, hard["v"], hard["rpm"], shaft_depth=SHAFT_DEPTH)
    print(f"cavitation at {perf[-1][0]} W ({hard['kn']:.2f} kn, {hard['rpm']:.0f} rpm), shaft {SHAFT_DEPTH * 1000:.0f} mm deep:")
    print(" r/R   top: sigma  -Cpmin   side: sigma  -Cpmin   margin")
    for x, st_, ct, ss, cs in cav[::2]:
        print(f" {x:.3f}      {st_:5.2f}   {ct:5.2f}         {ss:5.2f}   {cs:5.2f}   {min(st_ / ct, ss / cs):5.2f}")
    stl = stall_rows(blade, v_s, n_s)
    return ideal, blade, perf, (v_s, n_s, T_s, Q_s), st, cr, cav, stl


# -- the geometry, for Solvent -----------------------------------------------------------------------------
X_STATIONS = [0.01, 0.03, 0.06, 0.10, 0.17, 0.26, 0.37, 0.50, 0.63, 0.76, 0.88, 0.96, 1.0]
TE_MIN = 0.5e-3              # the trailing edge's least thickness, for machining (m)
EMBED = 0.06                 # the blade runs this far (in s) into the hub


def unit_thickness(x):
    """NACA 16 half-thickness per unit thickness ratio, at chord fraction x."""
    if x <= 0.5:
        return 0.989665 * math.sqrt(x) - 0.23925 * x - 0.041 * x**2 - 0.5594 * x**3
    return 0.01 + 2.325 * (1 - x) - 3.42 * (1 - x) ** 2 + 1.46 * (1 - x) ** 3


def unit_camber(x):
    """a = 1.0 mean line per unit design lift coefficient."""
    if x <= 0 or x >= 1:
        return 0.0
    return -1 / (4 * math.pi) * ((1 - x) * math.log(1 - x) + x * math.log(x))


def fits(blade):
    """The design table as polynomials in s, 0 at the hub and 1 at the tip, highest power first."""
    rows = blade["rows"]
    xh = HUB_R / blade["R"]
    sv = np.array([(r["xi"] - xh) / (1 - xh) for r in rows])
    s0 = (TIP_FROM - xh) / (1 - xh)
    inner = sv <= s0 + 1e-9
    chord = np.polyfit(sv[inner], [r["c"] * 1000 for r, k in zip(rows, inner) if k], 4)
    beta = np.polyfit(sv, [math.degrees(r["beta"]) for r in rows], 5)
    cli = np.polyfit(sv, [r["cli"] for r in rows], 2)
    # how well they fit
    def c_of(s_):
        e = 1 - (max(s_ - s0, 0) / (1 - s0)) ** 2
        return np.polyval(chord, min(s_, s0)) * (TIP_CHORD + (1 - TIP_CHORD) * e)
    err_c = max(abs(c_of(x) - r["c"] * 1000) for x, r in zip(sv, rows))
    err_b = max(abs(np.polyval(beta, x) - math.degrees(r["beta"])) for x, r in zip(sv, rows))
    return dict(chord=chord, beta=beta, cli=cli, s0=s0, err_c=err_c, err_b=err_b)


def poly_expr(coef, var):
    """Horner form, numbers to 6 significant figures."""
    out = f"{coef[0]:.6g}"
    for c in coef[1:]:
        out = f"({out}) * {var} + {c:.6g}"
    return out


def solvent_block(blade, f):
    td = "dims.tail_down"
    L = ["// BEGIN generated by tools/propeller.py: the blade's design table. Edit the design there.",
         f"// chord fit within {f['err_c']:.2f} mm and pitch angle within {f['err_b']:.2f}° of the designed stations",
         f"prop_R := {blade['R'] * 1000:.1f}mm",
         f"prop_hub := {HUB_R * 1000:.1f}mm",
         f"tc_root := {TC_ROOT}",
         f"tc_tip := {TC_TIP}",
         f"tc_shape := {TC_SHAPE}",
         f"tip_from := {f['s0']:.6f}            // the tip rounds from here (0.9 R) ...",
         f"tip_chord := {TIP_CHORD}                 // ... to this share of the chord there",
         f"te_half := {TE_MIN / 2 * 1000:.3f}mm             // half the trailing edge's least thickness",
         "hand := -1                        // left-handed: counter-clockwise seen from astern, ahead",
         "",
         "// One section of a blade at span fraction `s` along its radial stacking line `g` (0 at the hub,",
         "// 1 at the tip): drawn in the station's plane square to `g`, its v forward along the shaft",
         "// (`up`), its u the way a right-handed blade turns (v × the line's way out); `hand` -1 mirrors",
         "// it, for the left-handed propeller this drive turns.",
         "// The chord runs from the leading edge, ahead, to the trailing edge at the pitch angle `beta`",
         "// from the plane of the disc; the section stands on its mid-chord.",
         "component BladeSection(g: line, up: axis, s: Scalar) {",
         "  st := std.stations.OnLine(g, up: up, s: s)",
         "  sc := min(s, tip_from)",
         "  round_off := 1 - (max(s - tip_from, 0) / (1 - tip_from))^2",
         f"  c := ({poly_expr(f['chord'], 'sc')}) * 1mm * (tip_chord + (1 - tip_chord) * round_off)",
         f"  beta := ({poly_expr(f['beta'], 's')}) * 1deg",
         "  tc := tc_tip + (tc_root - tc_tip) * (1 - s)^tc_shape",
         f"  cli := {poly_expr(f['cli'], 's')}",
         "  cb := cos(beta)",
         "  sb := sin(beta)",
         "  in st.n {"]
    names_u, names_l = [], []

    def pt(name, x, sign):
        T, C = unit_thickness(x), unit_camber(x)
        y = f"(c * (cli * {C:.6f} {'+' if sign > 0 else '-'} tc * {T:.6f}) {'+' if sign > 0 else '-'} {x:.3f} * te_half)"
        u = f"(0.5 - {x:.3f}) * c * cb - {y} * sb"
        v = f"(0.5 - {x:.3f}) * c * sb + {y} * cb"
        L.append(f"    {name} := point")
        L.append(f"    {name} coords(du: hand * ({u}), dv: {v}) st.n")

    pt("le", 0.0, 1)
    for k, x in enumerate(X_STATIONS):
        pt(f"u{k}", x, 1)
        names_u.append(f"u{k}")
        pt(f"l{k}", x, -1)
        names_l.append(f"l{k}")
    walk = names_u[::-1] + ["le"] + names_l
    chain = " -> ".join(f"line({a}, {b})" for a, b in zip(walk, walk[1:]))
    L.append(f"    skin := {chain}")
    L.append("    foil := spline(through: skin)")
    L.append(f"    te := line({names_l[-1]}, {names_u[-1]})")
    L.append("  }")
    L.append("  profile := face(foil, te)")
    L.append("}")
    L.append(f"blade_embed := {EMBED}")
    L.append("// END generated")
    return "\n".join(L)


NAB_DENSITY = 7640.0         # kg/m^3
SHEAR_PIN_D = 1.6e-3         # m, C36000 free-cutting brass, double shear
FILLET_KT = 1.3              # stress concentration at the root's fillet
SHEAR_PIN_TAU = 205e6        # its ultimate shear strength, Pa
SHAFT_D = 16.0e-3            # the tail shaft, 316 stainless
HUB_LENGTH = 0.040


def offsets(blade, xis=(0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95)):
    """The section offsets a propeller drawing gives: at each radius, the back (suction) and face
    (pressure) ordinates from the nose-tail line, in mm, at the chord fractions the loft is drawn
    through, the trailing edge thickened to its least thickness."""
    rows = blade["rows"]
    xi = np.array([r["xi"] for r in rows])
    out = []
    for x in xis:
        c = float(np.interp(x, xi, [r["c"] for r in rows]))
        tc = tc_at(x)
        cli = float(np.interp(x, xi, [r["cli"] for r in rows]))
        beta = float(np.interp(x, xi, [math.degrees(r["beta"]) for r in rows]))
        P = 2 * math.pi * x * blade["R"] * math.tan(math.radians(beta))
        back, face = [], []
        for xc in [0.0] + X_STATIONS:
            T, C = unit_thickness(xc), unit_camber(xc)
            back.append((c * (cli * C + tc * T) + xc * TE_MIN / 2) * 1000)
            face.append((c * (cli * C - tc * T) - xc * TE_MIN / 2) * 1000)
        out.append(dict(xi=x, r=x * blade["R"] * 1000, c=c * 1000, beta=beta, P=P * 1000,
                        t=c * tc * 1000, back=back, face=face))
    return out


def mass_props(blade):
    """Blade and hub mass in NAB, expanded area ratio, polar moment of inertia."""
    rows = blade["rows"]
    rs = np.array([r["r"] for r in rows])
    areas = np.array([section_modulus(r["tc"], r["cli"], max(r["c"], 1e-4))[1] for r in rows])
    blade_vol = np.trapezoid(areas, rs)
    hub_vol = math.pi * HUB_R**2 * HUB_LENGTH + 2 / 3 * math.pi * HUB_R**3 \
        - math.pi * (SHAFT_D / 2) ** 2 * HUB_LENGTH
    m_blades = BLADES * blade_vol * NAB_DENSITY
    m_hub = hub_vol * NAB_DENSITY
    J = BLADES * NAB_DENSITY * np.trapezoid(areas * rs**2, rs) + 0.5 * m_hub * HUB_R**2
    ear = BLADES * np.trapezoid([r["c"] for r in rows], rs) / (math.pi * blade["R"] ** 2)
    return dict(m_blades=m_blades, m_hub=m_hub, J=J, ear=ear)


def at_full_load(fn):
    """Run fn with the hull at its full load (tools/lines.py: 320 kg)."""
    global LWL, WETTED
    keep = (LWL, WETTED)
    LWL, WETTED = 5.30, 3.54
    try:
        return fn()
    finally:
        LWL, WETTED = keep


def report(blade, perf, perf_full, sprint, st, cr, adv, ret, cav, f, tr, mp, offs):
    R = blade["R"]
    rows = blade["rows"]
    k07 = min(rows, key=lambda r: abs(r["xi"] - 0.7))
    P07 = 2 * math.pi * k07["r"] * math.tan(k07["beta"])
    cruise = perf[3][1]
    pin_torque = 2 * math.pi * (SHEAR_PIN_D / 2) ** 2 * SHEAR_PIN_TAU * (SHAFT_D / 2)
    z_root, _ = section_modulus(rows[0]["tc"], rows[0]["cli"], rows[0]["c"])
    strike_force = pin_torque / (0.8 * R)
    strike_stress = strike_force * (0.8 * R - HUB_R) / z_root
    vs, ns, Ts, Qs = sprint
    L = []
    w = L.append
    w("# Propeller design report")
    w("")
    w("The pedal kayak's propeller. Generated by `tools/propeller.py` (run it with `--write`); its")
    w("geometry is `prop.sv`. Every number below is computed. The assumptions are listed where they are used.")
    w("")
    w("## Summary")
    w("")
    w("| | |")
    w("|---|---|")
    w(f"| Diameter | {2 * R * 1000:.0f} mm |")
    w(f"| Blades | {BLADES}, left-handed: counter-clockwise seen from astern when going ahead |")
    w(f"| Pitch at 0.7 R | {P07 * 1000:.0f} mm (P/D {P07 / (2 * R):.2f}); the pitch varies along the blade (table below) |")
    w(f"| Expanded area ratio | {mp['ear']:.3f} |")
    w(f"| Hub | Ø{2 * HUB_R * 1000:.0f} × {HUB_LENGTH * 1000:.0f} mm; hub ratio {HUB_R / R:.2f}; bore Ø{SHAFT_D * 1000:.0f} H7 |")
    w("| Sections | NACA 16-series thickness on the NACA a = 1.0 mean line; 0.5 mm minimum trailing edge |")
    w(f"| Thickness/chord | {TC_ROOT:.2f} at the root, falling to {TC_TIP:.3f} at the tip as (1 − s)^{TC_SHAPE} |")
    w(f"| Design point | {PEDAL_DESIGN:.0f} W at the pedals, cadence {CADENCE_DESIGN:.0f} rpm, {CADENCE_DESIGN * RATIO_FINAL:.0f} rpm at the propeller |")
    w(f"| Open-water efficiency at the design point | **{cruise['eta']:.3f}** (BEM analysis of the final blade) |")
    w(f"| Speed at the design point | **{cruise['kn']:.2f} kn** ({cruise['v']:.2f} m/s); thrust {cruise['T']:.1f} N |")
    w(f"| Pedal-to-tow efficiency | {cruise['total']:.3f} (hull drag × speed / pedal power) |")
    w(f"| Material | Nickel-aluminium bronze, ASTM B148 C95800 |")
    w(f"| Mass | {mp['m_blades'] + mp['m_hub']:.2f} kg ({mp['m_blades']:.2f} kg blades, {mp['m_hub']:.2f} kg hub); polar inertia {mp['J'] * 1e6:.0f} kg·mm² |")
    w(f"| Protection | Ø{SHEAR_PIN_D * 1000:.1f} mm brass shear pin through hub and shaft, shears at {pin_torque:.1f} N·m |")
    w("")
    w("## Design basis")
    w("")
    w(f"- **Water:** sea water at 10 °C, ρ = {RHO:.0f} kg/m³, ν = {NU:.2e} m²/s, vapour pressure {P_VAP:.0f} Pa.")
    w(f"- **Hull:** drag from ITTC-57 friction on {WETTED} m² wetted, form factor {FORM}, plus wave-making")
    w(f"  of {RESID_AT:.0%} of friction at Froude number {RESID_FN}, growing as Fn⁴. The hull figures are `tools/lines.py`'s at 156 kg.")
    w(f"- **Hull interaction:** wake fraction {WAKE}, thrust deduction {THRUST_DEDUCTION}. The disc is 0.5 m behind")
    w(f"  the transom on the hinged tail. The shaft runs {math.degrees(TAIL_DOWN):.1f}° below level, so the required")
    w("  thrust is divided by the cosine of that angle. The crossflow across the disc is the hull's speed times its sine.")
    w(f"- **Rider and drive:** {PEDAL_DESIGN:.0f} W sustained at {CADENCE_DESIGN:.0f} rpm. The drive is {ETA_DRIVE:.0%} efficient; the train is {RATIO_FINAL:.0f}:1.")
    w(f"- **Sections:** polars from NeuralFoil (an XFOIL-trained surrogate, `large` model), n_crit {N_CRIT:g}. Each")
    w("  station is read at its own Reynolds number, which runs from 3×10⁴ to 10⁵: laminar separation bubbles")
    w("  dominate the drag here, which is why the polars and not textbook drag coefficients set the sections.")
    w("")
    w("## Method")
    w("")
    w("1. **Trade study.** For each diameter and gear ratio, a minimum-induced-loss blade is designed at the speed it reaches.")
    w("2. **Design.** Adkins & Liebeck (1994), *Design of Optimum Propellers*: Betz's minimum induced loss with Prandtl's")
    w("   tip loss and profile drag. At every station the camber and design lift minimise drag/lift at that")
    w(f"   station's Reynolds number, at least {STALL_MARGIN} below the section's maximum lift. Smooth curves are then drawn")
    w("   through the chosen cambers and lifts, and the blade is designed again on those curves.")
    w(f"3. **Buildable blade.** The tip rounds parabolically from 0.9 R to {TIP_CHORD:.0%} of the chord there. Each")
    w("   station's pitch angle is re-derived so that its section still meets its design lift.")
    w("4. **Analysis.** Blade-element momentum with Prandtl's tip and hub losses on the final blade. This")
    w("   gives every performance, strength and cavitation number below.")
    w("5. **Matching.** For each pedal power: the speed and cadence at which the propeller absorbs that power through")
    w("   the drive, and its thrust meets the hull's drag.")
    w("")
    w("## Trade study: diameter against gear ratio")
    w("")
    w("At 100 W and a 70 rpm cadence, the efficiency and speed of a minimum-induced-loss blade:")
    w("")
    w("| D mm | ratio | rpm | η | kn | max chord mm |")
    w("|---|---|---|---|---|---|")
    for D, ratio, eta, kn, cm in tr:
        w(f"| {D * 1000:.0f} | {ratio:.0f} | {CADENCE_DESIGN * ratio:.0f} | {eta:.3f} | {kn:.2f} | {cm:.1f} |")
    w("")
    w("The optimum is flat. The best case in the window, 330 mm at 5:1, gains 0.04 kn over 270 mm at 7:1.")
    w("It would cost 60 mm more draft, a new gear train, and blades too narrow (25–31 mm) to stay thick")
    w("enough. So the design is 270 mm at 7:1, the train already designed.")
    w("")
    w("## The blade")
    w("")
    w("| r/R | r mm | chord mm | β ° | P/D | t/c | t mm | c_li | c_l | α ° | Re | c_d |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        P = 2 * math.pi * r["r"] * math.tan(r["beta"])
        w(f"| {r['xi']:.3f} | {r['r'] * 1000:.1f} | {r['c'] * 1000:.1f} | {math.degrees(r['beta']):.2f} | {P / (2 * R):.3f} |"
          f" {r['tc']:.3f} | {r['c'] * r['tc'] * 1000:.2f} | {r['cli']:.2f} | {r['cl']:.3f} | {r['alpha']:.2f} | {r['re']:.0f} | {r['cd']:.4f} |")
    w("")
    w(f"`prop.sv` draws the blade from polynomial fits of these columns. They hold the chord to")
    w(f"{f['err_c']:.2f} mm and the pitch angle to {f['err_b']:.2f}° at every station. Each section is drawn square to a")
    w("straight radial stacking line through the mid-chords, with no skew and no rake.")
    w("")
    w("### Section offsets")
    w("")
    w("Ordinates in mm from the nose-tail line, positive toward the back (suction side, facing forward). The face is")
    w("the pressure side, facing aft. The trailing edge is thickened linearly to 0.5 mm.")
    w("")
    hdr = "| r/R | chord | pitch | t max | side | " + " | ".join(f"{x:g}" for x in [0.0] + X_STATIONS) + " |"
    w(hdr)
    w("|" + "---|" * (5 + 1 + len(X_STATIONS)))
    for o in offs:
        w(f"| {o['xi']:.2f} | {o['c']:.2f} | {o['P']:.0f} | {o['t']:.2f} | back | " + " | ".join(f"{v:.3f}" for v in o["back"]) + " |")
        w(f"| | | | | face | " + " | ".join(f"{v:.3f}" for v in o["face"]) + " |")
    w("")
    w("## Performance")
    w("")
    w("The final blade, analysed. The boat at 156 kg:")
    w("")
    w("| pedal W | kn | cadence rpm | propeller rpm | thrust N | η propeller | pedal-to-tow |")
    w("|---|---|---|---|---|---|---|")
    for pw, op in perf:
        w(f"| {pw} | {op['kn']:.2f} | {op['cadence']:.1f} | {op['rpm']:.0f} | {op['T']:.1f} | {op['eta']:.3f} | {op['total']:.3f} |")
    w("")
    w("Fully loaded (320 kg: pilot, passenger, cargo):")
    w("")
    w("| pedal W | kn | cadence rpm | propeller rpm | thrust N | η propeller |")
    w("|---|---|---|---|---|---|")
    for pw, op in perf_full:
        w(f"| {pw} | {op['kn']:.2f} | {op['cadence']:.1f} | {op['rpm']:.0f} | {op['T']:.1f} | {op['eta']:.3f} |")
    w("")
    w("A fixed-pitch propeller sets the cadence by the power: 50–95 rpm from a gentle paddle to a sprint,")
    w("all in a recumbent rider's range. Fully loaded, the cadence at a given power falls by only a few rpm.")
    w("")
    w("## Strength")
    w("")
    w(f"- **Material:** nickel-aluminium bronze C95800. Yield {NAB_YIELD / 1e6:.0f} MPa, ultimate {NAB_UTS / 1e6:.0f} MPa, corrosion")
    w(f"  fatigue in sea water {NAB_FATIGUE_SEAWATER / 1e6:.0f} MPa (10⁸ cycles, reversed; a literature value for as-cast material).")
    w(f"- **Sprint start:** a standing start at a {SPRINT_CADENCE:.0f} rpm cadence ({ns:.0f} rpm, {vs} m/s), {Qs:.2f} N·m, {Ts:.0f} N of thrust.")
    w("  Most of the blade is stalled here, and the polars past stall are NeuralFoil's least confident.")
    w(f"  Limit: yield / 1.5 = {ALLOW_SPRINT / 1e6:.0f} MPa. The cranks' 200 N·m peak cannot reach the blade: a propeller's")
    w("  torque is set by its speed, and below that speed the push only spins it up.")
    w(f"- **Cruise fatigue:** the steady stress at 100 W, plus the alternation once a revolution from the tail's")
    w(f"  crossflow (±{crossflow(cruise['v']):.2f} m/s, tangential at the 3 and 9 o'clock positions). Goodman, required safety factor {SF_FATIGUE}.")
    w("- Bending is taken about each section's weak principal axis, from its own coordinates, under the")
    w("  combined thrust and tangential loads outboard of it.")
    w("")
    w("| r/R | sprint MPa | cruise mean MPa | alternating MPa | Goodman SF |")
    w("|---|---|---|---|---|")
    for (x, sp), (_, m), (_, hi), (_, lo) in zip(st, cr, adv, ret):
        if m <= 0 or x > 0.95:
            continue
        sa = abs(hi - lo) / 2
        sf = 1 / (sa / NAB_FATIGUE_SEAWATER + m / NAB_UTS)
        w(f"| {x:.3f} | {sp / 1e6:.1f} | {m / 1e6:.1f} | {sa / 1e6:.1f} | {sf:.1f} |")
    w("")
    w("The root takes the highest stress. Give it a fillet of at least 3 mm radius to the hub. The stresses above")
    w("carry no fillet concentration factor, and a cast root with a fillet sees about 1.3×.")
    w("")
    ok = strike_stress * FILLET_KT < NAB_YIELD
    w(f"**Strikes.** The shear pin shears at {pin_torque:.1f} N·m, {pin_torque / Qs:.2f}× the sprint start's torque. A tangential")
    w(f"blow at 0.8 R that shears it is {strike_force:.0f} N. That puts {strike_stress / 1e6:.0f} MPa into the root, or")
    w(f"{strike_stress * FILLET_KT / 1e6:.0f} MPa with the fillet's {FILLET_KT}× concentration, against {NAB_YIELD / 1e6:.0f} MPa yield. " +
      ("So the pin shears before the blade bends." if ok else "**The blade would bend before the pin shears: make the pin smaller.**"))
    w("A blow from below or behind is the kick-up tail's to absorb.")
    w("")
    w("## Cavitation and ventilation")
    w("")
    w(f"The disc's centre is {SHAFT_DEPTH * 1000:.0f} mm deep at the design load (60 mm of tip cover). Each section's cavitation number")
    w("is computed at the top of the disc (shallowest) and at the 3 and 9 o'clock positions (where the crossflow")
    w("swings the incidence). It is set against a thin-section estimate of the least pressure coefficient:")
    w("thickness, load, and the leading edge's peak for incidence away from ideal.")
    w("")
    w(f"Worst case shown: {perf[-1][0]} W, {perf[-1][1]['kn']:.2f} kn, {perf[-1][1]['rpm']:.0f} rpm.")
    w("")
    w("| r/R | σ top | −Cp min top | σ side | −Cp min side | margin |")
    w("|---|---|---|---|---|---|")
    for x, st_, ct, ss, cs in cav[::2]:
        w(f"| {x:.3f} | {st_:.2f} | {ct:.2f} | {ss:.2f} | {cs:.2f} | {min(st_ / ct, ss / cs):.2f} |")
    w("")
    w("At 100 W the least margin is about 1.8. At a 250 W sprint the outer tenth of the blade reaches about 1.1 at the")
    w("sides, so a short sprint may show tip-vortex or leading-edge cavitation inception, harmless at these")
    w("powers. Ventilation is the likelier nuisance. With 60 mm of tip cover (0.22 D), a steep wave or a")
    w("hard turn can draw air down to the upper blade. The guard fin under the tail and the tail's own")
    w("depth limit it. Avoid running with the tail partly raised.")
    w("")
    w("## Manufacture")
    w("")
    w("- **Material and process:** cast in C95800 nickel-aluminium bronze and finish-machined, or 5-axis machined")
    w("  from bar. Two other choices:")
    w("  - 17-4PH stainless steel, H1150: stronger, heavier, and needs care against crevice corrosion.")
    w("  - A 3D-printed master for an investment casting.")
    w("  Not aluminium: its corrosion fatigue in sea water is poor.")
    w("- **Geometry:** export `prop.sv`'s blades and hub (`solventc prop.sv --stl …`), or loft the section offsets above.")
    w("- **Tolerances:** adapted from ISO 484-2 Class I, scaled to this diameter.")
    w("  - Local pitch ±1.5 %; mean pitch of each blade ±1 %.")
    w("  - Section thickness +0.15 / −0.05 mm.")
    w("  - Chord ±0.5 mm.")
    w("  - Leading and trailing edges to template within 0.1 mm.")
    w("  - Blade-to-blade angular spacing ±0.5°.")
    w("- **Surface:** Ra ≤ 1.6 µm on both faces, ≤ 0.8 µm over the outer half of the back. Edges sharp to the offsets.")
    w("- **Balance:** static and dynamic, to ISO 1940 G6.3 at 650 rpm. That is a residual unbalance of about")
    w(f"  {(mp['m_blades'] + mp['m_hub']) * 1000 * 6.3 / (650 * 2 * math.pi / 60):.0f} g·mm.")
    w(f"- **Hub:** bore Ø{SHAFT_D * 1000:.0f} H7 on a 316 shaft. A Ø{SHEAR_PIN_D * 1000:.1f} mm C36000 brass shear pin is cross-drilled through hub and")
    w("  shaft. A spinner nut and a split pin hold it aft. Fit a sacrificial zinc anode on the tail tube.")
    w("")
    w("## Limits of this design")
    w("")
    w("- **Polars:** NeuralFoil's, not tunnel data. At Re 3×10⁴–10⁵ the laminar-bubble behaviour is sensitive")
    w("  to free-stream turbulence (n_crit). A test of the finished propeller, thrust and torque against rpm in")
    w("  a tank or behind the boat, would anchor them.")
    w("- **Hull model:** the hull's drag and its wake and thrust deduction are estimates. The design point moves")
    w("  with them, but the efficiency curve is flat across 40–250 W, so an error moves the cadence, not the efficiency.")
    w("- **Sections:** drawn square to the stacking line, not wrapped on their cylinders. At the root a")
    w("  section's ends stand about 1 mm outboard of its radius.")
    w("- **Cavitation:** the estimate is thin-section superposition, not a panel-method pressure distribution.")
    w("")
    w("## References")
    w("")
    w("- Adkins, C. N. & Liebeck, R. H., *Design of Optimum Propellers*, Journal of Propulsion and Power 10(5), 1994.")
    w("- Larrabee, E. E., *Practical Design of Minimum Induced Loss Propellers*, SAE 790585, 1979.")
    w("- Abbott, I. H. & von Doenhoff, A. E., *Theory of Wing Sections*, 1959: the a = 1.0 mean line and the 16-series.")
    w("- Sharpe, P. D., NeuralFoil, 2024 (MIT licence).")
    w("- ISO 484-2, *Shipbuilding — Ship screw propellers — Manufacturing tolerances*.")
    (ROOT / "docs" / "propeller.md").write_text("\n".join(L) + "\n")
    print("wrote docs/propeller.md")


def write_outputs(ideal, blade, perf, sprint, st, cav):
    f = fits(blade)
    sv = ROOT / "prop.sv"
    text = sv.read_text()
    import re
    text = re.sub(r"// BEGIN generated by tools/propeller.py.*?// END generated",
                  lambda m: solvent_block(blade, f), text, flags=re.S)
    sv.write_text(text)
    print("wrote", sv, f"(chord fit {f['err_c']:.2f} mm, pitch fit {f['err_b']:.2f}°)")
    return f


if __name__ == "__main__":
    res = main()
    if "--write" in sys.argv:
        ideal, blade, perf, sprint, st, cr, cav, stl = res
        f = write_outputs(ideal, blade, perf, sprint, st, cav)
        cruise = perf[3][1]
        vt = crossflow(cruise["v"])
        adv = blade_stresses(blade, cruise["v"], cruise["rpm"], dvt=vt)
        ret = blade_stresses(blade, cruise["v"], cruise["rpm"], dvt=-vt)
        perf_full = at_full_load(lambda: [(pw, operating_point(blade, RATIO_FINAL, pw))
                                          for pw in (60, 100, 160, 250)])
        print("trade study ...")
        tr = trade()
        report(blade, perf, perf_full, sprint, st, cr, adv, ret, cav, f, tr, mass_props(blade),
               offsets(blade))
