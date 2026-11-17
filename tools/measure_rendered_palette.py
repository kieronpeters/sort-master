#!/usr/bin/env python3
"""Measure the colour actually rendered on screen, from an evidence screenshot.

QA-01 records the separation of the *authored* palette hexes. That is not what a
player sees: the bands are drawn under a linear tonemap, then shaded by
liquid.gdshader. This samples the screenshot and reports the separation that
actually reached the screen.

Pure stdlib: a minimal PNG decoder (8-bit RGB/RGBA, filters 0-4) plus the
CIEDE2000 from tools/solver/audit_palette.py.

Usage:
    py -3.12 tools/measure_rendered_palette.py docs/evidence/android/d15-level16-5tubes.png --tubes 7
"""

from __future__ import annotations

import argparse
import importlib.util
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load_audit():
    spec = importlib.util.spec_from_file_location(
        "audit_palette", ROOT / "tools" / "solver" / "audit_palette.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def decode_png(path: Path) -> tuple[int, int, bytes]:
    """Return (width, height, RGB bytes). Handles 8-bit truecolour with filters."""
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos = 8
    idat = bytearray()
    width = height = depth = colour_type = 0
    while pos < len(raw):
        length = struct.unpack_from(">I", raw, pos)[0]
        ctype = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, depth, colour_type = struct.unpack_from(">IIBB", data, 0)
            interlace = data[12]
            if depth != 8 or colour_type not in (2, 6) or interlace != 0:
                raise SystemExit(
                    f"unsupported PNG: depth={depth} colour={colour_type} interlace={interlace}")
        elif ctype == b"IDAT":
            idat += data
        elif ctype == b"IEND":
            break

    channels = 3 if colour_type == 2 else 4
    stride = width * channels
    data = zlib.decompress(bytes(idat))
    out = bytearray(width * height * 3)
    prev = bytearray(stride)
    o = 0
    for y in range(height):
        f = data[o]
        o += 1
        line = bytearray(data[o:o + stride])
        o += stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        elif f != 0:
            raise SystemExit(f"bad filter {f} on row {y}")
        prev = line
        for x in range(width):
            base = x * channels
            out[(y * width + x) * 3] = line[base]
            out[(y * width + x) * 3 + 1] = line[base + 1]
            out[(y * width + x) * 3 + 2] = line[base + 2]
    return width, height, bytes(out)


def px(buf: bytes, w: int, x: int, y: int) -> tuple[int, int, int]:
    i = (y * w + x) * 3
    return buf[i], buf[i + 1], buf[i + 2]


def hexs(c: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % c


def rgb255_to_lab(audit, c):
    return audit.linear_rgb_to_lab(tuple(audit.srgb_to_linear(v / 255.0) for v in c))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--tubes", type=int, default=7)
    ap.add_argument("--width-fraction", type=float, default=0.94)
    ap.add_argument("--gap", type=float, default=20.0)
    ap.add_argument("--vessel-w", type=float, default=0.172)
    ap.add_argument("--y-from", type=float, default=0.42, help="fraction of height")
    ap.add_argument("--y-to", type=float, default=0.72)
    args = ap.parse_args()

    audit = load_audit()
    path = Path(args.image)
    w, h, buf = decode_png(path)
    print(f"{path.name}: {w}x{h}")

    # BoardLayout: same maths as the game, so the sampled columns are vessel centres.
    design_w = 1080.0
    usable = design_w * args.width_fraction
    ppu_w = (usable - (args.tubes - 1) * args.gap) / (args.tubes * args.vessel_w)
    ppu = max(1.0, ppu_w)
    vessel_w = args.vessel_w * ppu
    slot = vessel_w + args.gap
    total = args.tubes * slot - args.gap
    start = (design_w - total) * 0.5
    centres = [round(start + slot * (i + 0.5)) for i in range(args.tubes)]

    print(f"predicted vessel centres (design px): {centres}")
    print(f"(image width {w}, so scale {w / design_w:.3f})")

    lab = {}
    for cid, (hexv, name) in audit.COLOURS.items():
        rgb = audit.hex_to_srgb(hexv)
        lab[hexv] = (name, audit.linear_rgb_to_lab(tuple(audit.srgb_to_linear(c) for c in rgb)))

    y0, y1 = int(h * args.y_from), int(h * args.y_to)
    sampled = {}
    for idx, cx in enumerate(centres):
        sx = round(cx * w / design_w)
        if not (0 <= sx < w):
            continue
        # cluster the column into colour runs
        runs = []
        for y in range(y0, y1):
            c = px(buf, w, sx, y)
            if runs and all(abs(c[k] - runs[-1][0][k]) <= 6 for k in range(3)):
                runs[-1][1] += 1
            else:
                runs.append([c, 1])
        big = [(c, n) for c, n in runs if n >= 12]
        print(f"\ntube {idx + 1} (x={sx}):")
        for c, n in big:
            best = min(lab.values(), key=lambda v: audit.ciede2000(
                rgb255_to_lab(audit, c), v[1]))
            rendered_lab = rgb255_to_lab(audit, c)
            d = audit.ciede2000(rendered_lab, best[1])
            print(f"   {hexs(c)}  run={n:3d}  nearest={best[0]:<9} (authored dE {d:5.1f})")
            sampled.setdefault(best[0], []).append(c)

    # The marginal pair QA-01 accepted: aqua vs violet.
    def mean(colours):
        n = len(colours)
        return tuple(round(sum(c[k] for c in colours) / n) for k in range(3))

    if "aqua" in sampled and "violet" in sampled:
        a, v = mean(sampled["aqua"]), mean(sampled["violet"])
        al = rgb255_to_lab(audit, a)
        vl = rgb255_to_lab(audit, v)
        d_normal = audit.ciede2000(al, vl)
        da = audit.simulate(hexs(a), "deutan")
        dv = audit.simulate(hexs(v), "deutan")
        d_deutan = audit.ciede2000(
            audit.linear_rgb_to_lab(tuple(audit.srgb_to_linear(c) for c in da)),
            audit.linear_rgb_to_lab(tuple(audit.srgb_to_linear(c) for c in dv)))
        print(f"\naqua/violet RENDERED: {hexs(a)} vs {hexs(v)}"
              f" -> normal dE {d_normal:.1f}, deuteranopia dE {d_deutan:.1f}")
        print(f"authored reference    : #46D8D0 vs #D0A2FF"
              f" -> normal dE 40.1, deuteranopia dE 12.9")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
