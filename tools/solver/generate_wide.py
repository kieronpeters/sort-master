#!/usr/bin/env python3
"""Generate the wide tiers: twelve and fourteen jugs, three rows.

These cannot carry a minimum-move guarantee. Proving the exact minimum on a
twelve-jug board did not finish: BFS was killed twice after twenty-eight minutes
with no level produced, and A* closed only one of four twelve-jug boards and none
of the thirteen-jug ones. What is cheap is proving a board is *solvable* -
depth-first search with consolidation-first ordering closes a fourteen-jug board in
about twenty milliseconds.

So the wide tiers ship with a recorded solution instead of a minimum, and
`minMoves` is deliberately absent: the catalogue must not claim optimality it has
not proved. The replay check at the end applies every recorded solution through the
real rules, so a level that ships is genuinely completable.

Usage:
    py -3.12 tools/solver/generate_wide.py --from 441 --to 500
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import CAPACITY, InvalidLevel, apply, is_won, key, validate  # noqa: E402
from solve_any import solve_any  # noqa: E402
import generate_levels as gen  # noqa: E402

LEVELS = Path("godot/levels")
EXT = Path("godot/tests/solutions_ext.json")


def replay(level: dict, moves: list) -> bool:
    """Apply a recorded solution through the real rules."""
    board = [list(t) for t in level["tubes"]]
    for mv in moves:
        board = apply(board, int(mv["from"]), int(mv["to"]), int(mv["units"]))
    return is_won(board)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="first", type=int, default=441)
    ap.add_argument("--to", dest="last", type=int, default=500)
    ap.add_argument("--seed", type=int, default=3141)
    args = ap.parse_args()

    total = args.last - args.first + 1
    rng = random.Random(args.seed)

    seen = set()
    for path in LEVELS.glob("level_*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        seen.add(key([list(t) for t in data["tubes"]]))

    made = []
    attempts = 0
    while len(made) < total and attempts < total * 60:
        attempts += 1
        # Two thirds of the tier is twelve jugs, the rest fourteen.
        wide = len(made) >= int(total * 0.66)
        colours, empties = (8, 6) if wide else (8, 4)
        board = gen.deal(colours, empties, rng)
        if board is None:
            continue
        candidate = {
            "id": "wide", "ruleVersion": "rules-v1", "capacity": CAPACITY,
            "tubes": board,
        }
        try:
            validate(candidate)
        except InvalidLevel:
            continue
        canon = key(board)
        if canon in seen:
            continue
        result = solve_any(candidate, max_seconds=6.0)
        if not result["solvable"] or not result["moves"]:
            continue
        if not replay(candidate, result["moves"]):
            print("  replay mismatch, discarding")
            continue
        seen.add(canon)
        made.append((candidate, result["moves"]))

    if len(made) < total:
        print(f"only produced {len(made)} of {total}")
        return 1

    # Order by solution length, so the tier still rises rather than jumping about.
    made.sort(key=lambda pair: len(pair[1]))

    ext = json.loads(EXT.read_text(encoding="utf-8"))
    for offset, (candidate, moves) in enumerate(made):
        number = args.first + offset
        candidate["id"] = f"L{number}"
        candidate["name"] = f"Level {number}"
        candidate.pop("minMoves", None)
        (LEVELS / f"level_{number}.json").write_text(
            json.dumps(candidate, indent=2), encoding="utf-8")
        ext[f"level_{number}"] = moves

    EXT.write_text(json.dumps(ext, separators=(",", ":")))

    # verify the whole wide tier from disk
    bad = 0
    for number in range(args.first, args.last + 1):
        data = json.loads((LEVELS / f"level_{number}.json").read_text(encoding="utf-8"))
        if not replay(data, ext[f"level_{number}"]):
            print(f"  level {number}: replay failed")
            bad += 1
    tubes = {}
    for number in range(args.first, args.last + 1):
        data = json.loads((LEVELS / f"level_{number}.json").read_text(encoding="utf-8"))
        tubes[len(data["tubes"])] = tubes.get(len(data["tubes"]), 0) + 1
    print(f"wide tier {args.first}-{args.last}: {len(made)} levels, jugs {tubes}")
    print("WIDE VERIFY: PASS" if bad == 0 else f"WIDE VERIFY: {bad} failure(s)")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
