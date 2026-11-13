"""Direction-2 parity check: the independent solver verifies the game's play.

`tests/test_flow.gd` records every move the game actually made, level by level,
into a transcript. This script replays those transcripts with the solver's own
rules-v1 implementation and fails on any illegal move, wrong unit count, wrong
move count, or unfinished board.

Usage:
    py -3.12 tools/solver/verify_game_moves.py --transcript C:/tmp/game_moves.json
    py -3.12 tools/solver/verify_game_moves.py --transcript ... --levels godot/levels

Exit codes: 0 verified, 1 mismatch, 2 unreadable input.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from solve import CAPACITY, InvalidLevel, apply, is_won, top_run, validate


def can_move(tubes: list[list[str]], src_i: int, dst_i: int) -> bool:
    """rules-v1 legality without the solver's symmetry pruning.

    The solver may skip pointless single-colour-to-empty moves for speed; a
    player may legitimately make them, so the verifier must accept them.
    """
    if src_i == dst_i:
        return False
    if not (0 <= src_i < len(tubes)) or not (0 <= dst_i < len(tubes)):
        return False
    if not tubes[src_i]:
        return False
    if len(tubes[dst_i]) >= CAPACITY:
        return False
    if tubes[dst_i] and tubes[dst_i][-1] != tubes[src_i][-1]:
        return False
    return top_run(tubes[src_i]) <= CAPACITY - len(tubes[dst_i])


def verify_level(entry: dict, levels_dir: Path) -> list[str]:
    problems: list[str] = []
    number = int(entry.get("level", 0))
    path = levels_dir / f"level_{number}.json"
    if not path.exists():
        return [f"level {number}: file {path} is missing"]

    level = json.loads(path.read_text(encoding="utf-8"))
    try:
        validate(level)
    except InvalidLevel as exc:
        return [f"level {number}: invalid level data ({exc})"]

    tubes = [list(t) for t in level["tubes"]]
    moves = entry.get("moves", [])
    for index, move in enumerate(moves):
        try:
            src_i, dst_i = int(move[0]), int(move[1])
        except (TypeError, ValueError, IndexError):
            problems.append(f"level {number}: move {index + 1} is malformed")
            break
        if not can_move(tubes, src_i, dst_i):
            problems.append(
                f"level {number}: move {index + 1} ({src_i}->{dst_i}) is illegal"
            )
            break
        units = top_run(tubes[src_i])
        tubes = apply(tubes, src_i, dst_i, units)

    if not problems and not is_won(tubes):
        problems.append(f"level {number}: transcript does not end in a won board")
    if not problems and int(entry.get("move_count", -1)) != len(moves):
        problems.append(
            f"level {number}: move_count {entry.get('move_count')} != {len(moves)} recorded moves"
        )
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--transcript", required=True)
    parser.add_argument("--levels", default="godot/levels")
    args = parser.parse_args(argv)

    transcript_path = Path(args.transcript)
    if not transcript_path.exists():
        print(f"transcript not found: {transcript_path}")
        return 2
    try:
        data = json.loads(transcript_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        print(f"transcript unreadable: {exc}")
        return 2

    if data.get("ruleVersion") != "rules-v1":
        print(f"ruleVersion must be rules-v1, got {data.get('ruleVersion')!r}")
        return 1

    entries = data.get("levels", [])
    levels_dir = Path(args.levels)
    problems: list[str] = []
    seen: set[int] = set()
    for entry in entries:
        number = int(entry.get("level", 0))
        seen.add(number)
        problems.extend(verify_level(entry, levels_dir))

    missing = sorted(set(range(1, 31)) - seen)
    if missing:
        problems.append(f"transcript is missing levels: {missing}")

    for problem in problems:
        print("FAIL:", problem)
    print("")
    print(
        f"GAME MOVES VERIFIED: {len(entries)} levels"
        f"  FAILED: {len(problems)}"
    )
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
