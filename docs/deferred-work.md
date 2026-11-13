# Deferred work — release-candidate cycle

**Status:** current as of 13 November 2026.

This list was rewritten after the release-candidate cycle. Items that were
previously deferred and are now done have been removed; the remainder are
genuine gaps, each with the reason it is still open.

## Still deferred

| # | Item | Why it is deferred | Impact |
|---|---|---|---|
| 1 | Physical device testing (S23 Ultra) | Device unavailable for this cycle (owner decision) | Performance, thermals, safe areas and real-size legibility are unverified. See `docs/device-test-checklist.md`. |
| 2 | Release signing (M10-03) | Needs the owner's keystore and approval | The RC APK is debug-signed. Not publishable. |
| 3 | Store listing / publishing | Owner boundary | Nothing published. |
| 4 | Haptics (M7-03) | Android hardware needed to tune intensity | No tactile feedback; sound carries all feedback. |
| 5 | Mid-level save | Progress currently stores unlocked level, best moves and mute | A killed process restarts the level; no rule impact. |
| 6 | Tutorial overlay (M6-07) | Level 1 is self-evident in playtesting | New players rely on the selection glow and error messages. |
| 7 | Screen-reader and large-text modes | Needs a device pass and a design decision | Not required for the release gate, still an accessibility gap. |
| 8 | Emulator floor-device coverage | Ultra is the target; emulator adds no evidence | Low-end Android performance unmeasured. |
| 9 | Gradle/AAB path | Debug/release APK is enough for the RC | Play Store upload would need AAB + signing. |

## Deliberate compromises

- Pour and selection are animated in place, but there is no liquid "stream"
  animation. Moves are instant and unambiguous.
- The board is a fixed five- or six-tube layout per level; there is no zoom.
- `best` move counts are recorded but not shown on the level grid (only on the
  completion card), to keep the grid legible.

## Not negotiable — these must never regress

- `rules-v1` correctness and solver parity.
- One-commit-per-move state discipline in `PuzzleState`.
- No ads, analytics, accounts or network calls.
- Undo and restart correctness.
- The M8-06 overlay must never appear in a release build.
