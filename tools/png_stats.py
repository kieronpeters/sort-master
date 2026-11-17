#!/usr/bin/env python3
"""Pixel statistics for the Android smoke harness.

A screenshot proves nothing on its own — a black frame is still a valid PNG, and
that is exactly how the Vulkan present failure looked. These two checks turn a
screenshot into an assertion.

    py -3.12 tools/png_stats.py nonblack <image>        # fraction of lit pixels
    py -3.12 tools/png_stats.py diff <before> <after>   # fraction changed

Reuses the stdlib PNG decoder from measure_rendered_palette.py.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def decoder():
    spec = importlib.util.spec_from_file_location(
        "mrp", ROOT / "measure_rendered_palette.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.decode_png


def nonblack(path: Path) -> int:
    w, h, buf = decoder()(path)
    lit = 0
    total = w * h
    # Step to keep this quick on 1080x2400 frames; the sampling is uniform.
    for y in range(0, h, 3):
        base = y * w * 3
        for x in range(0, w, 3):
            i = base + x * 3
            if buf[i] > 12 or buf[i + 1] > 12 or buf[i + 2] > 12:
                lit += 1
    sampled = len(range(0, h, 3)) * len(range(0, w, 3))
    print(f"{path.name}: size={w}x{h} lit={lit / sampled:.3f}")
    return 0


def diff(a: Path, b: Path) -> int:
    wa, ha, ba = decoder()(a)
    wb, hb, bb = decoder()(b)
    if (wa, ha) != (wb, hb):
        print(f"size mismatch {wa}x{ha} vs {wb}x{hb}: changed=1.000")
        return 0
    changed = 0
    sampled = 0
    for y in range(0, ha, 4):
        base = y * wa * 3
        for x in range(0, wa, 4):
            i = base + x * 3
            sampled += 1
            if (abs(ba[i] - bb[i]) > 8
                    or abs(ba[i + 1] - bb[i + 1]) > 8
                    or abs(ba[i + 2] - bb[i + 2]) > 8):
                changed += 1
    print(f"changed={changed / sampled:.3f}")
    return 0


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "nonblack":
        return nonblack(Path(sys.argv[2]))
    if cmd == "diff":
        if len(sys.argv) < 4:
            print(__doc__)
            return 2
        return diff(Path(sys.argv[2]), Path(sys.argv[3]))
    print(f"unknown command {cmd}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
