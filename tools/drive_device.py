#!/usr/bin/env python3
"""Drive the game on a connected Android device through its levels.

Tap coordinates are not guessed: the game is 1080 design pixels wide and the S23
Ultra panel is 1080 physical pixels wide, so scale is exactly 1 and vessel
centres come from the same BoardLayout maths the game uses.

Wireless ADB drops when the phone sleeps and comes back on a different port, so
every level re-checks the device and wakes it. A tap into a dead connection looks
identical to a working run -- an earlier attempt "played" 28 levels against a
phone that had disconnected, so liveness is checked, not assumed.

Usage:
    py -3.12 -u tools/drive_device.py --level 2 --shot out.png
    py -3.12 -u tools/drive_device.py --from 3 --to 30 --next-y 806 --snapdir shots
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOLUTIONS = ROOT / "godot" / "tests" / "solutions.json"
LEVELS = ROOT / "godot" / "levels"
ADB = Path.home() / "AppData" / "Local" / "Android" / "Sdk" / "platform-tools" / "adb.exe"

DESIGN_W = 1080.0
VESSEL_WORLD_W = 0.172
VESSEL_WORLD_H = 0.512
VESSEL_GAP = 20.0
WIDTH_FRACTION = 0.94
BASELINE_FRACTION = 0.66
MAX_HEIGHT_FRACTION = 0.46


def adb(*args: str, timeout: int = 45) -> str:
    try:
        r = subprocess.run([str(ADB), *args], capture_output=True, text=True, timeout=timeout)
        return (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return ""


def connected() -> bool:
    out = adb("devices")
    for line in out.splitlines()[1:]:
        if "\tdevice" in line and "offline" not in line:
            return True
    return False


def ensure_device() -> bool:
    if connected():
        adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
        return True
    print("  device gone; rediscovering ...", flush=True)
    for line in adb("mdns", "services").splitlines():
        if "_adb-tls-connect._tcp" in line:
            endpoint = line.split()[-1]
            print(f"  connecting to {endpoint}", flush=True)
            adb("connect", endpoint)
            time.sleep(3)
            if connected():
                return True
    return False


def screen_size() -> tuple[int, int]:
    for line in adb("shell", "wm", "size").splitlines():
        if ":" in line and "x" in line.split(":")[-1]:
            w, h = line.split(":")[-1].strip().split("x")
            return int(w), int(h)
    return 1080, 2316


def tap(x: float, y: float) -> None:
    adb("shell", "input", "tap", str(int(round(x))), str(int(round(y))))


def layout(tubes: int, viewport: tuple[int, int]) -> dict:
    vw, vh = viewport
    sx = vw / DESIGN_W
    design_h = vh / sx
    usable = DESIGN_W * WIDTH_FRACTION
    ppu_w = (usable - (tubes - 1) * VESSEL_GAP) / (tubes * VESSEL_WORLD_W)
    ppu_h = design_h * MAX_HEIGHT_FRACTION / VESSEL_WORLD_H
    ppu = max(1.0, min(ppu_w, ppu_h))
    vessel_w = VESSEL_WORLD_W * ppu
    slot = vessel_w + VESSEL_GAP
    total = tubes * slot - VESSEL_GAP
    start = (DESIGN_W - total) * 0.5
    centres = [start + slot * (i + 0.5) for i in range(tubes)]
    baseline = design_h * BASELINE_FRACTION
    hit_top = baseline - VESSEL_WORLD_H * ppu * 1.06
    tap_y = hit_top + (baseline - hit_top) * 0.55
    return {"centres": [c * sx for c in centres], "tap_y": tap_y * sx}


def shot(path: Path) -> bool:
    for _ in range(3):
        adb("shell", "screencap", "-p", "/sdcard/drive.png")
        adb("pull", "/sdcard/drive.png", str(path))
        if path.exists() and path.stat().st_size > 2000:
            return True
        time.sleep(2)
    return False


def play_level(n: int, viewport: tuple[int, int], snap: Path | None) -> bool:
    level = json.loads((LEVELS / f"level_{n}.json").read_text(encoding="utf-8"))
    solutions = json.loads(SOLUTIONS.read_text(encoding="utf-8"))
    key = f"level_{n}"
    if key not in solutions:
        print(f"level {n}: no recorded solution", flush=True)
        return False

    lay = layout(len(level["tubes"]), viewport)
    moves = solutions[key]["moves"]
    print(f"level {n:2d}: {len(level['tubes'])} tubes, {len(moves)} moves, "
          f"tap_y={lay['tap_y']:.0f}", flush=True)

    for i, m in enumerate(moves, 1):
        if not ensure_device():
            print(f"  ABORT: device unreachable during level {n} move {i}", flush=True)
            return False
        tap(lay["centres"][m["from"]], lay["tap_y"])
        time.sleep(0.20)
        tap(lay["centres"][m["to"]], lay["tap_y"])
        time.sleep(1.05)          # the pour locks input for ~0.87 s
    time.sleep(1.2)

    if snap:
        snap.mkdir(parents=True, exist_ok=True)
        if shot(snap / f"level{n:02d}.png"):
            print(f"  completed, screenshot saved", flush=True)
        else:
            print(f"  completed, screenshot FAILED", flush=True)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", type=int)
    ap.add_argument("--from", dest="first", type=int)
    ap.add_argument("--to", dest="last", type=int)
    ap.add_argument("--shot")
    ap.add_argument("--snapdir")
    ap.add_argument("--next-x", type=int, default=540)
    ap.add_argument("--next-y", type=int, default=0)
    ap.add_argument("--pause", type=float, default=2.0)
    args = ap.parse_args()

    if not ADB.exists():
        print(f"adb not found at {ADB}")
        return 2
    if not ensure_device():
        print("no device reachable", flush=True)
        return 2

    vp = screen_size()
    print(f"device screen {vp[0]}x{vp[1]}", flush=True)

    levels = [args.level] if args.level else list(range(args.first or 1, (args.last or 30) + 1))
    for i, n in enumerate(levels):
        if not play_level(n, vp, Path(args.snapdir) if args.snapdir else (Path(args.shot) if len(levels) == 1 and args.shot else None)):
            return 1
        if args.next_y and i < len(levels) - 1:
            tap(args.next_x, args.next_y)
            time.sleep(args.pause)
    print("finished", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
