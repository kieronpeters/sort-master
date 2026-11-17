#!/usr/bin/env python3
"""Check whether levels 3-5 require the spare (empty) vessel.

M4-04 wants at least one of levels 3-5 to need the empty vessel before the
obvious move. This runs the rules-v1 search twice per level:

  * unconstrained  -> the recorded minimum;
  * empty-tube forks forbidden as a destination.

If both minima are equal, no level in the range *requires* the spare vessel and
the criterion is unmet. Reads the shipped level files and rules-v1 only.

Usage:
    py -3.12 tools/solver/check_empty_vessel_lesson.py --levels godot/levels \
        --range 3-5 --solutions godot/tests/solutions.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import solve  # noqa: E402


def minimum_moves(level: dict, forbid_empty_destination: bool) -> int | None:
    """Breadth-first minimum, optionally without pouring into an empty tube."""
    start = [list(t) for t in level["tubes"]]
    if solve.is_won(start):
        return 0
    seen = {solve.key(start)}
    frontier = [start]
    depth = 0
    while frontier:
        depth += 1
        nxt_frontier = []
        for board in frontier:
            for src_i, dst_i, units, _colour in solve.legal_moves(board):
                if forbid_empty_destination and not board[dst_i]:
                    continue
                nxt = solve.apply(board, src_i, dst_i, units)
                k = solve.key(nxt)
                if k in seen:
                    continue
                if solve.is_won(nxt):
                    return depth
                seen.add(k)
                nxt_frontier.append(nxt)
        frontier = nxt_frontier
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--levels", default="godot/levels")
    parser.add_argument("--range", default="3-5")
    parser.add_argument("--solutions", default="godot/tests/solutions.json")
    args = parser.parse_args()

    lo, hi = (int(x) for x in args.range.split("-"))
    recorded = {}
    sol_path = Path(args.solutions)
    if sol_path.exists():
        data = json.loads(sol_path.read_text(encoding="utf-8"))
        entries = data if isinstance(data, list) else data.get("levels", data)
        if isinstance(entries, dict):
            for k, v in entries.items():
                if isinstance(v, dict):
                    recorded[str(k)] = v.get("minimumMoves", v.get("moves"))
        else:
            for v in entries:
                if isinstance(v, dict):
                    recorded[str(v.get("levelId"))] = v.get("minimumMoves")

    print(f"{'level':<6}{'recorded':>9}{'free':>7}{'no-empty':>10}  verdict")
    unmet = []
    for n in range(lo, hi + 1):
        path = Path(args.levels) / f"level_{n}.json"
        if not path.exists():
            print(f"L{n:<5} missing file")
            continue
        level = json.loads(path.read_text(encoding="utf-8"))
        free = minimum_moves(level, False)
        no_empty = minimum_moves(level, True)
        rec = recorded.get(level.get("id"), recorded.get(str(n), "-"))
        # Unsolvable without an empty destination (None) also means the vessel is
        # required; a strictly longer minimum means the constrained path is worse.
        requires = (no_empty is None) or (free is not None and no_empty > free)
        verdict = "REQUIRES the empty vessel" if requires else "does not require it"
        if not requires:
            unmet.append(n)
        print(f"L{n:<5}{str(rec):>9}{str(free):>7}{str(no_empty):>10}  {verdict}")

    print()
    if unmet:
        print(f"criterion UNMET: levels {unmet} are solvable without the spare vessel.")
        return 0
    print("criterion MET: at least one level needs the spare vessel.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
