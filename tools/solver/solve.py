"""rules-v1 solver and level validator.

Independent implementation of docs/rules-v1.md. Reads a level JSON file,
validates it against the level invariants, and searches breadth-first for a
minimum-length solution.

Usage:
    py -3.12 tools/solver/solve.py godot/levels/level_1.json
    py -3.12 tools/solver/solve.py godot/levels/*.json --summary

Exit codes: 0 solved, 2 invalid level, 3 unsolvable.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import deque
from pathlib import Path

RULE_VERSION = "rules-v1"
CAPACITY = 4


class InvalidLevel(Exception):
    pass


def validate(level: dict) -> None:
    if level.get("ruleVersion") != RULE_VERSION:
        raise InvalidLevel(f"ruleVersion must be {RULE_VERSION!r}, got {level.get('ruleVersion')!r}")
    if level.get("capacity") != CAPACITY:
        raise InvalidLevel(f"capacity must be {CAPACITY}, got {level.get('capacity')!r}")

    tubes = level.get("tubes")
    if not isinstance(tubes, list) or len(tubes) < 2:
        raise InvalidLevel("at least two tubes are required")

    for i, tube in enumerate(tubes):
        if not isinstance(tube, list):
            raise InvalidLevel(f"tube {i} is not a list")
        if len(tube) > CAPACITY:
            raise InvalidLevel(f"tube {i} holds {len(tube)} units, capacity is {CAPACITY}")

    counts: dict[str, int] = {}
    for tube in tubes:
        for colour in tube:
            counts[colour] = counts.get(colour, 0) + 1
    if not counts:
        raise InvalidLevel("board is empty")
    for colour, n in counts.items():
        if n != CAPACITY:
            raise InvalidLevel(f"colour {colour!r} appears {n} times, expected {CAPACITY}")

    if not any(len(t) == 0 for t in tubes):
        raise InvalidLevel("no empty tube")

    if is_won(tubes):
        raise InvalidLevel("level is already won at load")


def top_run(tube: list[str]) -> int:
    if not tube:
        return 0
    colour = tube[-1]
    run = 0
    for unit in reversed(tube):
        if unit != colour:
            break
        run += 1
    return run


def is_won(tubes: list[list[str]]) -> bool:
    for tube in tubes:
        if not tube:
            continue
        if len(tube) != CAPACITY or len(set(tube)) != 1:
            return False
    return True


def legal_moves(tubes: list[list[str]]) -> list[tuple[int, int, int, str]]:
    """Return (from, to, units, colour) for every legal move under rules-v1."""
    moves: list[tuple[int, int, int, str]] = []
    for src_i, src in enumerate(tubes):
        if not src:
            continue
        run = top_run(src)
        colour = src[-1]
        src_single = len(set(src)) == 1
        for dst_i, dst in enumerate(tubes):
            if src_i == dst_i:
                continue
            if len(dst) >= CAPACITY:
                continue
            if dst and dst[-1] != colour:
                continue
            if run > CAPACITY - len(dst):
                continue
            # Permitted self-loop pruning (rules-v1 11.4)
            if src_single and not dst:
                continue
            moves.append((src_i, dst_i, run, colour))
    return moves


def apply(tubes: list[list[str]], src_i: int, dst_i: int, units: int) -> list[list[str]]:
    out = [t[:] for t in tubes]
    moved = out[src_i][-units:]
    del out[src_i][-units:]
    out[dst_i].extend(moved)
    return out


def key(tubes: list[list[str]]) -> tuple[tuple[str, ...], ...]:
    return tuple(sorted(tuple(t) for t in tubes))


def solve(level: dict, max_states: int = 400000) -> dict:
    start = [list(t) for t in level["tubes"]]
    started = time.perf_counter()

    if is_won(start):
        return _result(level, True, 0, [], 1, started, False)

    seen = {key(start): None}
    queue: deque[list[list[str]]] = deque([start])
    parents: dict[tuple, tuple | None] = {key(start): None}
    move_into: dict[tuple, tuple | None] = {key(start): None}

    while queue:
        if len(seen) > max_states:
            return _result(level, False, None, None, len(seen), started, True)
        board = queue.popleft()
        board_key = key(board)
        for src_i, dst_i, units, colour in legal_moves(board):
            nxt = apply(board, src_i, dst_i, units)
            nxt_key = key(nxt)
            if nxt_key in seen:
                continue
            seen[nxt_key] = board_key
            parents[nxt_key] = board_key
            move_into[nxt_key] = (src_i, dst_i, units, colour)
            if is_won(nxt):
                path = _reconstruct(nxt_key, parents, move_into)
                return _result(level, True, len(path), path, len(seen), started, False)
            queue.append(nxt)

    return _result(level, False, None, None, len(seen), started, False)


def _reconstruct(end_key, parents, move_into):
    path = []
    node = end_key
    while True:
        move = move_into[node]
        if move is None:
            break
        src_i, dst_i, units, colour = move
        path.append({"from": src_i, "to": dst_i, "units": units, "colour": colour})
        node = parents[node]
    path.reverse()
    return path


def _result(level, solvable, minimum, moves, visited, started, bounded):
    return {
        "levelId": level.get("id"),
        "ruleVersion": RULE_VERSION,
        "solvable": solvable,
        "minimumMoves": minimum,
        "winCondition": "every tube empty or (full and single-colour)",
        "moves": moves,
        "visitedStates": visited,
        "elapsedMs": round((time.perf_counter() - started) * 1000, 1),
        "bounded": bounded,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("levels", nargs="+")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args(argv)

    worst = 0
    for path_str in args.levels:
        path = Path(path_str)
        try:
            level = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            print(f"{path.name}: unreadable ({exc})")
            worst = max(worst, 2)
            continue
        try:
            validate(level)
        except InvalidLevel as exc:
            print(f"{path.name}: INVALID - {exc}")
            worst = max(worst, 2)
            continue

        result = solve(level)
        if args.summary:
            status = f"solvable in {result['minimumMoves']}" if result["solvable"] else "UNSOLVABLE"
            print(f"{path.name}: {status} | visited {result['visitedStates']} | {result['elapsedMs']} ms")
        else:
            print(json.dumps(result, indent=2))
        if not result["solvable"]:
            worst = max(worst, 3)

    return worst


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
