#!/usr/bin/env python3
"""Exact solver for wide boards, where breadth-first search gives up.

BFS explores by depth alone, so a twelve-jug board (eight colours plus four spares)
blows up: the search did not finish a single level in twenty-eight minutes. A*
with an admissible bound finds the same minimum while ignoring states that cannot
possibly beat the best known answer.

The bound: for each colour, count the tubes that still hold it. Merging k tubes of
one colour takes at least k-1 pours, and a single pour can reduce that count by at
most one, so

    h = sum over colours of (tubes holding it - 1)

is a lower bound on the moves remaining. It is also consistent: a move raises the
depth by one and lowers h by at most one, so f never decreases and the first time a
goal is popped it is optimal.

Run as a check against the shipped catalogue with:

    py -3.12 tools/solver/astar.py --verify-all
"""

from __future__ import annotations

import argparse
import heapq
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import CAPACITY, is_won, key, legal_moves, validate  # noqa: E402

LEVELS = Path("godot/levels")


def bound(tubes: list[list[str]]) -> int:
    """Admissible lower bound on the moves left."""
    holders: dict[str, int] = {}
    for tube in tubes:
        for colour in set(tube):
            holders[colour] = holders.get(colour, 0) + 1
    total = 0
    for count in holders.values():
        total += count - 1
    return total


def solve_astar(level: dict, max_states: int = 400000) -> dict:
    started = time.perf_counter()
    start = [list(t) for t in level["tubes"]]

    if is_won(start):
        return {
            "solvable": True, "minimumMoves": 0, "moves": [],
            "visited": 1, "bounded": False,
            "seconds": time.perf_counter() - started,
        }

    start_key = key(start)
    best_g: dict[tuple, int] = {start_key: 0}
    parents: dict[tuple, tuple | None] = {start_key: None}
    move_into: dict[tuple, tuple | None] = {start_key: None}
    boards: dict[tuple, list[list[str]]] = {start_key: start}

    counter = 0
    heap = [(bound(start), 0, counter, start_key)]

    while heap:
        _, g, _, board_key = heapq.heappop(heap)
        if g > best_g.get(board_key, 1 << 30):
            continue                      # stale entry
        board = boards[board_key]

        if is_won(board):
            moves = []
            cursor = board_key
            while parents.get(cursor) is not None:
                moves.append(move_into[cursor])
                cursor = parents[cursor]
            moves.reverse()
            return {
                "solvable": True, "minimumMoves": g, "moves": moves,
                "visited": len(best_g), "bounded": False,
                "seconds": time.perf_counter() - started,
            }

        if len(best_g) > max_states:
            return {
                "solvable": None, "minimumMoves": None, "moves": None,
                "visited": len(best_g), "bounded": True,
                "seconds": time.perf_counter() - started,
            }

        for src_i, dst_i, units, colour in legal_moves(board):
            child = [list(t) for t in board]
            poured = min(units, CAPACITY - len(child[dst_i]))
            for _ in range(poured):
                child[dst_i].append(child[src_i].pop())
            child_key = key(child)
            child_g = g + 1
            if child_g >= best_g.get(child_key, 1 << 30):
                continue
            best_g[child_key] = child_g
            boards[child_key] = child
            parents[child_key] = board_key
            move_into[child_key] = {
                "from": src_i, "to": dst_i, "units": poured, "colour": colour,
            }
            counter += 1
            heapq.heappush(heap, (child_g + bound(child), child_g, counter, child_key))

    return {
        "solvable": False, "minimumMoves": None, "moves": None,
        "visited": len(best_g), "bounded": False,
        "seconds": time.perf_counter() - started,
    }


def verify_all() -> int:
    """Every shipped level's stored minimum must match A* exactly."""
    problems = 0
    checked = 0
    files = sorted(LEVELS.glob("level_*.json"),
                   key=lambda p: int(p.stem.split("_")[1]))
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        stored = data.get("minMoves")
        if stored is None:
            continue                      # the frozen 1-30 keep theirs elsewhere
        try:
            validate(data)
        except Exception as exc:
            print(f"  {path.name}: invalid - {exc}")
            problems += 1
            continue
        result = solve_astar(data, max_states=600000)
        checked += 1
        if result["minimumMoves"] != stored:
            print(f"  {path.name}: stored {stored}, A* says {result['minimumMoves']}")
            problems += 1
    print(f"checked {checked} levels against A*")
    print("ASTAR VERIFY: PASS" if problems == 0 else f"ASTAR VERIFY: {problems} mismatch(es)")
    return 0 if problems == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify-all", action="store_true")
    ap.add_argument("--level", type=int)
    args = ap.parse_args()

    if args.verify_all:
        return verify_all()

    if args.level:
        data = json.loads((LEVELS / f"level_{args.level}.json").read_text(encoding="utf-8"))
        r = solve_astar(data)
        print(f"level {args.level}: min={r['minimumMoves']} visited={r['visited']} "
              f"{r['seconds']:.2f}s bounded={r['bounded']}")
        return 0

    ap.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
