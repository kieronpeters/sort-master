"""Dump solver solutions for the parity harness.

Writes godot/tests/solutions.json: one verified move list per level, produced
by the independent Python implementation. The Godot side replays them through
the game's own PuzzleState, which is what proves the two implementations agree.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import solve, validate  # noqa: E402

LEVEL_DIR = Path("godot/levels")
OUT = Path("godot/tests/solutions.json")


def main() -> int:
    solutions = {}
    for path in sorted(LEVEL_DIR.glob("level_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        validate(data)
        result = solve(data)
        if not result["solvable"] or result["bounded"]:
            print(f"{path.name}: not solvable")
            return 2
        solutions[path.stem] = {
            "ruleVersion": result["ruleVersion"],
            "minimumMoves": result["minimumMoves"],
            "moves": result["moves"],
        }
        print(f"{path.name}: {result['minimumMoves']} moves")

    OUT.write_text(json.dumps(solutions, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT} with {len(solutions)} solutions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
