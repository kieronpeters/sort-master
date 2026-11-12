"""Order the level set by measured difficulty.

Preserves every puzzle's tube arrangement, but renumbers them so the minimum
move count rises across the 30-level progression. Ties are broken by colour
count, then by visited-state count.

Usage:
    py -3.12 tools/solver/order_levels.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from solve import solve, validate  # noqa: E402

LEVEL_DIR = Path("godot/levels")
REPORT = Path("docs/levels.md")

STAGES = [
    ("Discovery", 1, 6),
    ("Growing complexity", 7, 12),
    ("Strategy", 13, 18),
    ("Mastery", 19, 24),
    ("Expert", 25, 30),
]


def stage_name(level_no: int) -> str:
    for name, lo, hi in STAGES:
        if lo <= level_no <= hi:
            return name
    return "Expert"


def main() -> int:
    entries = []
    for path in sorted(LEVEL_DIR.glob("level_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        try:
            validate(data)
        except Exception as exc:  # noqa: BLE001
            print(f"{path.name}: INVALID - {exc}")
            return 2
        result = solve(data)
        if not result["solvable"] or result["bounded"]:
            print(f"{path.name}: not solvable / bounded")
            return 3
        entries.append(
            {
                "tubes": data["tubes"],
                "capacity": data.get("capacity", 4),
                "moves": result["minimumMoves"],
                "visited": result["visitedStates"],
                "colours": len({u for t in data["tubes"] for u in t}),
            }
        )

    if len(entries) != 30:
        print(f"expected 30 levels, found {len(entries)}")
        return 4

    entries.sort(key=lambda e: (e["moves"], e["colours"], e["visited"]))

    seen = set()
    for i, entry in enumerate(entries, start=1):
        canon = tuple(sorted(tuple(t) for t in entry["tubes"]))
        if canon in seen:
            print(f"duplicate level at position {i}")
            return 5
        seen.add(canon)

        payload = {
            "id": f"L{i}",
            "ruleVersion": "rules-v1",
            "capacity": entry["capacity"],
            "name": f"Level {i}",
            "tubes": entry["tubes"],
        }
        (LEVEL_DIR / f"level_{i}.json").write_text(
            json.dumps(payload, indent=2) + "\n", encoding="utf-8"
        )

    lines = [
        "# Level catalogue",
        "",
        "All 30 levels are verified by `tools/solver/solve.py` under `rules-v1`.",
        "Minimum move counts are exact: the search is exhaustive and unbounded.",
        "Levels are ordered by measured minimum moves, so difficulty rises",
        "monotonically. Stage names are design guidance, not hard bands.",
        "",
        "| Level | Stage | Colours | Tubes | Min moves | States searched |",
        "|---:|---|---:|---:|---:|---:|",
    ]
    for i, entry in enumerate(entries, start=1):
        lines.append(
            f"| {i} | {stage_name(i)} | {entry['colours']} | {len(entry['tubes'])} | "
            f"{entry['moves']} | {entry['visited']} |"
        )
    lines += [
        "",
        "## Difficulty metrics recorded",
        "",
        "Per level: minimum moves (exact), colour count, tube count, and the number",
        "of states the solver explored (a proxy for branching and dead ends).",
        "",
        "## Notes",
        "",
        "- No two levels share a canonical tube arrangement.",
        "- Every level satisfies the `rules-v1` invariants: 4 units per colour,",
        "  capacity 4, at least one empty tube, not won at load.",
        "- The five original hand-designed levels are preserved; only their",
        "  positions in the progression changed.",
    ]
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"ordered {len(entries)} levels")
    for i, e in enumerate(entries, start=1):
        print(f"  {i:2d} {e['moves']:2d} moves  {e['colours']}c {len(e['tubes'])}t")
    return 0


if __name__ == "__main__":
    sys.exit(main())
