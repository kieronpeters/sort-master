#!/usr/bin/env python3
"""Independent palette-separation audit for the shipped 30-level set.

Recomputes the M5-01 criterion from the level files themselves rather than
trusting a stored table:

  * CIEDE2000 between every colour pair that appears in the same level;
  * for normal vision, simulated protanopia and simulated deuteranopia
    (Machado, Oliveira & Fernandes 2009, severity 1.0, applied in linear sRGB);
  * reports the plan's bands: T2 >= 15.0 pass, 12.0-14.9 marginal, < 12.0
    forbidden, plus rule R1 (at most four colours per level).

Usage:
    py -3.12 tools/solver/audit_palette.py [--levels godot/levels] [--json PATH]
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

# Shipped liquid set, docs/palette-matrix.md §1 (must match palette ids A-F).
COLOURS = {
    "A": ("#FFC24B", "amber"),
    "B": ("#46D8D0", "aqua"),
    "C": ("#2FA45F", "emerald"),
    "D": ("#4D7BF1", "sapphire"),
    "E": ("#D0A2FF", "violet"),
    "F": ("#F87AA7", "rose"),
}

# Machado et al. 2009, severity 1.0, linear-RGB matrices.
SIMULATIONS = {
    "normal": ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
    "protan": (
        (0.152286, 1.052583, -0.204868),
        (0.114503, 0.786281, 0.099216),
        (-0.003882, -0.048116, 1.051998),
    ),
    "deutan": (
        (0.367322, 0.860646, -0.227968),
        (0.280085, 0.672501, 0.047413),
        (-0.011820, 0.042940, 0.968881),
    ),
}

T2_PASS = 15.0
T2_FORBIDDEN = 12.0
COLOUR_CAP = 4


def hex_to_srgb(value: str) -> tuple[float, float, float]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c: float) -> float:
    c = min(max(c, 0.0), 1.0)
    return c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def linear_rgb_to_lab(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    r, g, b = rgb
    x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
    x, y, z = x / 0.95047, y / 1.0, z / 1.08883

    def f(t: float) -> float:
        d = 6.0 / 29.0
        return t ** (1.0 / 3.0) if t > d ** 3 else t / (3 * d * d) + 4.0 / 29.0

    fx, fy, fz = f(x), f(y), f(z)
    return 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)


def simulate(hex_value: str, mode: str) -> tuple[float, float, float]:
    lin = [srgb_to_linear(c) for c in hex_to_srgb(hex_value)]
    m = SIMULATIONS[mode]
    out = [sum(m[i][j] * lin[j] for j in range(3)) for i in range(3)]
    return linear_to_srgb(out[0]), linear_to_srgb(out[1]), linear_to_srgb(out[2])


def ciede2000(lab1, lab2) -> float:
    l1, a1, b1 = lab1
    l2, a2, b2 = lab2
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    cbar = (c1 + c2) / 2.0
    g = 0.5 * (1 - math.sqrt(cbar ** 7 / (cbar ** 7 + 25 ** 7)))
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)

    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if (a1p or b1) else 0.0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if (a2p or b2) else 0.0

    dlp = l2 - l1
    dcp = c2p - c1p
    if c1p * c2p == 0:
        dhp = 0.0
    elif abs(h2p - h1p) <= 180:
        dhp = h2p - h1p
    elif h2p - h1p > 180:
        dhp = h2p - h1p - 360
    else:
        dhp = h2p - h1p + 360
    dhp_ = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dhp) / 2)

    lbp = (l1 + l2) / 2
    cbp = (c1p + c2p) / 2
    if c1p * c2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hbp = (h1p + h2p + 360) / 2
    else:
        hbp = (h1p + h2p - 360) / 2

    t = (1 - 0.17 * math.cos(math.radians(hbp - 30))
         + 0.24 * math.cos(math.radians(2 * hbp))
         + 0.32 * math.cos(math.radians(3 * hbp + 6))
         - 0.20 * math.cos(math.radians(4 * hbp - 63)))
    dtheta = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    rc = 2 * math.sqrt(cbp ** 7 / (cbp ** 7 + 25 ** 7))
    sl = 1 + 0.015 * (lbp - 50) ** 2 / math.sqrt(20 + (lbp - 50) ** 2)
    sc = 1 + 0.045 * cbp
    sh = 1 + 0.015 * cbp * t
    rt = -math.sin(math.radians(2 * dtheta)) * rc
    return math.sqrt((dlp / sl) ** 2 + (dcp / sc) ** 2 + (dhp_ / sh) ** 2
                     + rt * (dcp / sc) * (dhp_ / sh))


def load_levels(directory: Path) -> list[dict]:
    levels = []
    for path in sorted(directory.glob("level_*.json"),
                       key=lambda p: int(p.stem.split("_")[1])):
        data = json.loads(path.read_text(encoding="utf-8"))
        colour_ids = set()
        for tube in data.get("tubes", []):
            colour_ids.update(tube)
        data["_file"] = path.name
        data["_colours"] = sorted(colour_ids)
        levels.append(data)
    return levels


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--levels", default="godot/levels")
    parser.add_argument("--json", default=None)
    args = parser.parse_args()

    levels = load_levels(Path(args.levels))
    if not levels:
        print("no level files found", file=sys.stderr)
        return 2

    labs = {mode: {cid: linear_rgb_to_lab(tuple(srgb_to_linear(c)
                                                for c in simulate(COLOURS[cid][0], mode)))
                   for cid in COLOURS}
            for mode in SIMULATIONS}

    rows = []
    for level in levels:
        ids = level["_colours"]
        worst = {}
        for mode in SIMULATIONS:
            best = None
            for i, a in enumerate(ids):
                for b in ids[i + 1:]:
                    d = ciede2000(labs[mode][a], labs[mode][b])
                    if best is None or d < best[0]:
                        best = (d, a, b)
            worst[mode] = best
        min_all = min(w[0] for w in worst.values() if w)
        rows.append({
            "level": level["id"],
            "file": level["_file"],
            "colours": ids,
            "count": len(ids),
            "worst": {m: {"delta_e": round(v[0], 1), "pair": v[1] + "/" + v[2]}
                      for m, v in worst.items() if v},
            "min_delta_e": round(min_all, 1),
            "over_cap": len(ids) > COLOUR_CAP,
            "verdict": ("forbidden" if min_all < T2_FORBIDDEN
                        else "marginal" if min_all < T2_PASS else "pass"),
        })

    affected = [r for r in rows if r["verdict"] != "pass"]
    forbidden = [r for r in rows if r["verdict"] == "forbidden"]
    over_cap = [r for r in rows if r["over_cap"]]

    print(f"levels audited: {len(rows)}")
    print(f"T2 pass (all pairs >= {T2_PASS}): "
          f"{len(rows) - len(affected)}")
    print(f"marginal (>= {T2_FORBIDDEN} and < {T2_PASS}): {len(affected) - len(forbidden)}")
    print(f"forbidden (< {T2_FORBIDDEN}): {len(forbidden)}")
    print(f"over the R1 colour cap ({COLOUR_CAP}): {len(over_cap)}")
    print()
    print("affected levels:")
    for r in affected:
        pairs = ", ".join(f"{m} {v['delta_e']} ({v['pair']})"
                          for m, v in sorted(r["worst"].items()))
        print(f"  {r['level']:<4} {r['count']} colours  min {r['min_delta_e']:<5} {pairs}")

    if forbidden:
        print("\nFORBIDDEN PAIRS PRESENT - this contradicts the accepted record:")
        for r in forbidden:
            print(f"  {r['level']} min {r['min_delta_e']}")

    if args.json:
        Path(args.json).write_text(json.dumps(
            {"thresholds": {"pass": T2_PASS, "forbidden": T2_FORBIDDEN, "cap": COLOUR_CAP},
             "rows": rows}, indent=2), encoding="utf-8")
        print(f"\nwrote {args.json}")

    return 0 if not forbidden else 1


if __name__ == "__main__":
    raise SystemExit(main())
