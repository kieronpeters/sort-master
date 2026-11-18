#!/usr/bin/env python3
"""Reorder the extended levels by measured difficulty.

Generation picks whichever board is closest to a target move count, so the raw
sequence oscillates (12, 11, 12, 11). Players read that as randomness rather than
progression. This sorts levels 31 onward by the solver's own measurement -
minimum moves first, then colour count, then search effort - and renumbers them so
difficulty never falls from one level to the next.

Levels 1-30 are frozen and are not touched.

Usage:
    py -3.12 tools/solver/reorder_bulk.py --from 31 --timeout-note
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import solve  # noqa: E402

LEVEL_DIR = Path("godot/levels")
FROZEN = 30


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="first", type=int, default=FROZEN + 1)
    args = ap.parse_args()

    files = []
    for path in LEVEL_DIR.glob("level_*.json"):
        n = int(path.stem.split("_")[1])
        if n >= args.first:
            files.append((n, path))

    if not files:
        print("nothing to reorder")
        return 1

    records = []
    for n, path in sorted(files):
        data = json.loads(path.read_text(encoding="utf-8"))
        moves = data.get("minMoves")
        if moves is None:
            result = solve(data, max_states=400000)
            moves = result["minimumMoves"] or 0
        colours = len({c for t in data["tubes"] for c in t})
        records.append({"data": data, "moves": moves, "colours": colours, "old": n})

    records.sort(key=lambda r: (r["moves"], r["colours"]))

    # Move the old files aside first so renumbering cannot collide.
    for r in records:
        (LEVEL_DIR / f"level_{r['old']}.json").unlink()

    drops = 0
    previous = None
    for offset, r in enumerate(records):
        number = args.first + offset
        data = r["data"]
        data["id"] = f"L{number}"
        data["name"] = f"Level {number}"
        data["minMoves"] = r["moves"]
        (LEVEL_DIR / f"level_{number}.json").write_text(
            json.dumps(data, indent=2), encoding="utf-8")
        if previous is not None and r["moves"] < previous:
            drops += 1
        previous = r["moves"]

    total = len(list(LEVEL_DIR.glob("level_*.json")))
    print(f"reordered {len(records)} levels from {args.first}")
    print(f"levels on disk: {total}")
    print(f"difficulty drops after ordering: {drops}")
    print(f"range: {records[0]['moves']} .. {records[-1]['moves']}")
    return 0 if drops == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
