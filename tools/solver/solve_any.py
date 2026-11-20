"""Find *a* solution on boards too wide for optimal search.

The catalogue guarantees exact minimum moves, which is stricter than this genre
requires and is what caps it at ten jugs: BFS and A* both fail to close a
twelve-jug board. Real products ship levels that are merely *solvable*.

This returns any solution, found by depth-first search with the moves that
consolidate most first, plus a seen-set so it never revisits a state. It proves a
level is solvable and produces a replayable move list; it does not claim to be
minimal, and callers must not record `minMoves` from it.
"""
from __future__ import annotations
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import CAPACITY, is_won, key, legal_moves  # noqa: E402


def solve_any(level: dict, max_nodes: int = 200000, max_seconds: float = 20.0) -> dict:
    started = time.perf_counter()
    start = [list(t) for t in level["tubes"]]
    seen = {key(start)}
    path: list = []

    def score(move) -> int:
        src_i, dst_i, units, _colour = move
        # prefer moves that empty a tube, then the largest run
        return (0 if units == len(start[src_i]) else 1, -units)

    def walk(board) -> bool:
        if time.perf_counter() - started > max_seconds:
            raise TimeoutError
        if is_won(board):
            return True
        if len(seen) > max_nodes:
            raise TimeoutError
        ordered = sorted(legal_moves(board), key=score)
        for src_i, dst_i, units, _colour in ordered:
            child = [list(t) for t in board]
            poured = min(units, CAPACITY - len(child[dst_i]))
            moved = []
            for _ in range(poured):
                moved.append(child[src_i].pop())
            for unit in reversed(moved):
                child[dst_i].append(unit)
            k = key(child)
            if k in seen:
                continue
            seen.add(k)
            path.append({"from": src_i, "to": dst_i, "units": poured,
                         "colour": moved[-1] if moved else ""})
            if walk(child):
                return True
            path.pop()
        return False

    try:
        ok = walk(start)
    except TimeoutError:
        return {"solvable": None, "moves": None, "visited": len(seen),
                "seconds": time.perf_counter() - started}
    return {"solvable": ok, "moves": path if ok else None, "visited": len(seen),
            "seconds": time.perf_counter() - started}
