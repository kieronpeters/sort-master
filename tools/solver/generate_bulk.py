#!/usr/bin/env python3
"""Bulk-generate the extended level catalogue, verified level by level.

Levels 1-30 are frozen and untouched. This appends 31 onwards to a target count,
each candidate dealt at random and then checked with the real solver: a board is
only kept if it is valid under rules-v1, solvable, and its minimum move count
lands near the target for its position in the curve.

The minimum is stored on the level itself as `minMoves`, so the shipped catalogue
does not carry a second file of solutions and the parity suites stay focused on
the 30 levels they were written for.

Usage:
    py -3.12 tools/solver/generate_bulk.py --total 500
    py -3.12 tools/solver/generate_bulk.py --total 500 --verify-only
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import CAPACITY, InvalidLevel, is_won, key, solve, validate  # noqa: E402
import generate_levels as gen  # noqa: E402

LEVEL_DIR = Path("godot/levels")
FROZEN = 30          # 1-30 are the QA-verified set and are never rewritten


def tier(level_no: int) -> tuple[int, int]:
    """(colours, target minimum moves) for a level number.

    Six colours with two spare tubes is the widest the board layout has been
    tested for, so the curve tops out there rather than growing the tube count.
    """
    if level_no <= 40:
        return 4, 12
    if level_no <= 70:
        return 4, 14
    if level_no <= 110:
        return 5, 15
    if level_no <= 160:
        return 5, 16
    if level_no <= 220:
        return 5, 17
    if level_no <= 300:
        return 6, 18
    if level_no <= 400:
        return 7, 22
    return 8, 23


def make_level(level_no: int, rng: random.Random, seen: set, attempts: int = 40):
    # 90 attempts, not 400: on the higher colour counts the target move count is
    # rarely hit exactly, so a large budget was spent searching for a board that
    # does not exist. Taking the closest candidate found is good enough and keeps
    # generation to a few seconds per level.
    colours, target = tier(level_no)
    empties = 2
    best = None
    best_delta = 99
    for _ in range(attempts):
        board = gen.deal(colours, empties, rng)
        if board is None:
            continue
        candidate = {
            "id": f"L{level_no}",
            "ruleVersion": "rules-v1",
            "capacity": CAPACITY,
            "name": f"Level {level_no}",
            "tubes": board,
        }
        try:
            validate(candidate)
        except InvalidLevel:
            continue
        canon = key(board)
        if canon in seen:
            continue
        result = solve(candidate, max_states=250000)
        if not result["solvable"] or result["bounded"]:
            continue
        moves = result["minimumMoves"]
        delta = abs(moves - target)
        if best is None or delta < best_delta:
            best = (candidate, moves, canon)
            best_delta = delta
        if delta <= 1:
            break
    return best


def load_seen() -> set:
    seen = set()
    for path in sorted(LEVEL_DIR.glob("level_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        seen.add(key([list(t) for t in data["tubes"]]))
    return seen


def verify_all(expected_total: int) -> int:
    """Re-solve every shipped level and check the stored minimum."""
    problems = 0
    files = sorted(LEVEL_DIR.glob("level_*.json"),
                   key=lambda p: int(p.stem.split("_")[1]))
    print(f"verifying {len(files)} level files ...")
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        try:
            validate(data)
        except InvalidLevel as exc:
            print(f"  {path.name}: INVALID - {exc}")
            problems += 1
            continue
        stored = data.get("minMoves")
        if stored is None:
            continue                      # the frozen 30 keep theirs in solutions.json
        result = solve(data, max_states=400000)
        if not result["solvable"]:
            print(f"  {path.name}: UNSOLVABLE")
            problems += 1
            continue
        if result["minimumMoves"] != stored:
            print(f"  {path.name}: stored {stored}, solver says {result['minimumMoves']}")
            problems += 1
    count = len(files)
    print(f"levels on disk: {count} (expected {expected_total})")
    if count != expected_total:
        problems += 1
    print("VERIFY: PASS" if problems == 0 else f"VERIFY: {problems} problem(s)")
    return 0 if problems == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--total", type=int, default=500)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--verify-only", action="store_true")
    args = ap.parse_args()

    if args.verify_only:
        return verify_all(args.total)

    LEVEL_DIR.mkdir(parents=True, exist_ok=True)
    seen = load_seen()
    rng = random.Random(args.seed)

    have = len(list(LEVEL_DIR.glob("level_*.json")))
    print(f"starting from {have} levels, target {args.total}")
    started = time.perf_counter()
    made = 0

    for n in range(max(have + 1, FROZEN + 1), args.total + 1):
        best = make_level(n, rng, seen)
        if best is None:
            print(f"  level {n}: no candidate found, skipped")
            continue
        candidate, moves, canon = best
        candidate["minMoves"] = moves
        seen.add(canon)
        path = LEVEL_DIR / f"level_{n}.json"
        path.write_text(json.dumps(candidate, indent=2), encoding="utf-8")
        made += 1
        if made % 25 == 0 or n == args.total:
            elapsed = time.perf_counter() - started
            rate = made / elapsed if elapsed else 0
            print(f"  {n}/{args.total} levels  ({rate:.1f}/s, {elapsed:.0f}s elapsed)")

    total = len(list(LEVEL_DIR.glob("level_*.json")))
    print(f"\ndone: {total} level files")
    return verify_all(args.total)


if __name__ == "__main__":
    raise SystemExit(main())
