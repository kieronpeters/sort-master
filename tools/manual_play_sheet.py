#!/usr/bin/env python3
"""Generate the manual-play sheet for the agreed 1.0 depth.

The owner agreed (17 Nov 2026) to manual play of levels 1-10 plus one five-colour
and one six-colour level, rather than all 30. This writes docs/manual-play.md:
one block per level with the verified minimum, the exact move list in
human tube numbers, and the boxes to tick while playing it by hand on a device.

The move lists come from godot/tests/solutions.json, which the parity suites
already validate in both directions. This sheet is the *procedure*; it is not
evidence until a human has played a level and recorded the result.

Usage:
    py -3.12 tools/manual_play_sheet.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOLUTIONS = ROOT / "godot" / "tests" / "solutions.json"
LEVELS = ROOT / "godot" / "levels"
OUT = ROOT / "docs" / "manual-play.md"

# Agreed depth: 1-10 continuous, plus the worst palette band at 5 colours (16)
# and at 6 colours (25).
SUBSET = list(range(1, 11)) + [16, 25]


def load_level(n: int) -> dict:
    return json.loads((LEVELS / f"level_{n}.json").read_text(encoding="utf-8"))


def moves_for(n: int, solutions: dict) -> list[dict]:
    entry = solutions.get(f"level_{n}")
    return entry["moves"] if entry else []


def main() -> int:
    solutions = json.loads(SOLUTIONS.read_text(encoding="utf-8"))
    lines = [
        "# Manual play sheet — agreed 1.0 depth",
        "",
        "**Target agreed 17 November 2026:** levels 1–10 plus one five-colour level",
        "(16) and one six-colour level (25). The flow harness is not a substitute;",
        "a row is evidence only once a human has played it and recorded the result.",
        "",
        "Run on the debug build so the F1 overlay is available:",
        "",
        "```powershell",
        "adb install -r builds\\sort-master.apk",
        "```",
        "",
        "For each level record: completed (Y/N), moves used, the move count the game",
        "reported, whether any pour was mis-tapped, and anything that looked wrong.",
        "Play at normal speed and with the sound on — audio and touch are part of",
        "what this pass is checking.",
        "",
        "Tube numbers below are 1-based, left to right, as drawn on screen.",
        "",
        "---",
        "",
    ]

    for n in SUBSET:
        level = load_level(n)
        moves = moves_for(n, solutions)
        tubes = level["tubes"]
        colours = sorted({c for t in tubes for c in t})
        band = ""
        if n == 16:
            band = "  **five-colour level — palette marginal band (QA-01)**"
        elif n == 25:
            band = "  **six-colour level — palette marginal band (QA-01)**"

        lines.append(f"## Level {n}{band}")
        lines.append("")
        lines.append(f"`{level['id']}` · {len(colours)} colours · {len(tubes)} tubes "
                     f"· capacity {level['capacity']} · **minimum {len(moves)} moves**")
        lines.append("")
        if band:
            lines.append("While playing, note whether the shape symbols are enough to "
                         "tell the colours apart at arm's length. That is the "
                         "mitigation QA-01 relies on.")
            lines.append("")
        lines.append("| # | From tube | To tube | Units |")
        lines.append("|---:|---:|---:|---:|")
        for i, m in enumerate(moves, 1):
            lines.append(f"| {i} | {m['from'] + 1} | {m['to'] + 1} | {m['units']} |")
        lines.append("")
        lines.append("| Check | Result |")
        lines.append("|---|---|")
        lines.append("| Completed without a softlock | |")
        lines.append("| Moves used | |")
        lines.append("| Matches the game's reported count | |")
        lines.append("| Every tap hit the intended tube | |")
        lines.append("| Undo restored the exact board | |")
        lines.append("| Back mid-level asked to confirm | |")
        lines.append("| Notes / defects | |")
        lines.append("")
        lines.append("---")
        lines.append("")

    lines += [
        "## Sign-off",
        "",
        "| Field | Value |",
        "|---|---|",
        "| Builder | |",
        "| Device / OS | |",
        "| APK SHA-256 | |",
        "| Levels completed | / 12 |",
        "| Result | PASS / FAIL |",
        "",
        "A FAIL on any level needs the level, the move number, the expected and the",
        "actual result, and a screenshot or logcat excerpt.",
        "",
    ]

    OUT.write_text("\n".join(lines), encoding="utf-8")
    total = sum(len(moves_for(n, solutions)) for n in SUBSET)
    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"{len(SUBSET)} levels, {total} recorded moves, covering "
          f"{len(SUBSET)}/{len(load_level(1) and list(LEVELS.glob('level_*.json')))} of the catalogue")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
