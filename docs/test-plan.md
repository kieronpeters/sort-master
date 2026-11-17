# Test Plan

**Ticket:** M8-01
**Status:** current as of 13 November 2026 (QA cycle 2)

---

## 1. Layers, entry and exit

| Layer | Entry criterion | Exit criterion | Command |
|---|---|---|---|
| Rules + validation + layout + save | Clean checkout, Godot 4.7.2 available | **0 failed**, runtime < 5 s | `test_rules.gd` |
| Solver output | 30 level files + `solutions.json` | 30/30 solvable, minima match the recorded solutions | `tools/solver/solve.py` |
| Parity, direction 1 (solver → game) | Same as above | 0 failed, < 60 s, both sides declare `rules-v1` | `parity.gd` |
| Parity, direction 2 (game → solver) | Flow suite transcript | 30 levels replayed by the Python rules, 0 failed | `verify_game_moves.py` |
| Integration flow | Runnable main scene | 30/30 wins, 0 failed, transcript written | `test_flow.gd` |
| Manual desktop | Debug build, real window | Every checklist row has a capture or log | `docs/device-test-checklist.md` §3 |
| Device | Signed RC + S23 Ultra | Checklist complete, frame/thermal gates met | `docs/device-test-checklist.md` |

Device performance gate: no interaction frame above **33 ms** and no visible
hitch across 15 minutes; record `gfxinfo framestats` and battery delta. Device
testing is **not run**; nothing in this document claims it.

## 2. Device matrix

The S23 Ultra is the **baseline target**, not the floor: it is a flagship and
cannot prove low-end behaviour. The matrix therefore records both.

| Tier | Device | Android / API | Purpose | Status |
|---|---|---|---|---|
| Floor | 720 × 1280, 4 GB, e.g. Galaxy A13/A14 | 9–12 / 28–31 | minimum experience, 1080-design downscale | not available |
| Baseline | Galaxy S23 Ultra 1440 × 3088 | 14–15 / 34–35 | target device, touch, thermals | deferred by owner |
| Forward | Galaxy S24/S25 | 15–16 / 35–36 | future OS behaviour, edge-to-edge | not available |
| Emulator | x86_64 AVD | any | fallback | not usable: APK is arm64-only and no system images are installed |

**Gap:** no device older than the S23 is available, so the floor is unverified.
The 1080 × 1920 and 1080 × 2400 layout maths is tested; physical small-screen
legibility is not.

## 3. Evidence format

A claim is only accepted with one of:

- command output/log under `builds/` (test suites, exports, aapt2),
- a screenshot under `docs/evidence/` named for the screen/state,
- a filled row in `docs/device-test-checklist.md` with a capture reference.

Prose alone is not evidence. Device rows must say "not run" until executed.

## 4. Current results

| Layer | Result | Date |
|---|---|---|
| Rules, validation, layout, save, ink contrast | **126 passed, 0 failed** | 17 Nov 2026 |
| Parity direction 1 | **154 checks, 0 failed, 30 levels** | 13 Nov 2026 |
| Integration flow | **153 passed, 0 failed, 30/30 levels** | 17 Nov 2026 |
| Parity direction 2 | **GAME MOVES VERIFIED: 30 levels, 0 failed** | 13 Nov 2026 |
| Manual desktop | Level 1 interaction set (select/pour/undo) + 4/6-tube hit alignment | 13 Nov 2026 |
| Manual full playthrough | **1 of 30 by hand**; 29 covered only by the flow harness | — |
| Device | **Not run** | — |

## 5. What is covered

- **Rules:** construction, clone independence, pure and in-place move APIs,
  R1–R8, whole-run transfer, win detection, canonical keys, `RULE_VERSION`.
- **Validation:** ruleVersion, capacity, tube shape, per-colour counts, empty
  tube, already-won, non-object, all 30 shipped levels.
- **Layout:** 3/4/5/6/8 tubes, ordering, centring, width containment, baseline,
  taller viewports, degenerate input.
- **Save:** missing file, round-trip, corrupt JSON, negative clamping,
  non-positive bests, non-numeric bests.
- **Symbols:** ink contrast ≥ 4.5:1 for all six liquid colours.
- **Flow:** every level solved through the game's own selection/transfer path;
  Next Level wiring; undo restores the exact board; restart confirmation and
  execution; bounded history; locked-level taps; empty-tube taps; navigation
  and the Android back notification.
- **Parity:** solver paths replayed in-game; the game's recorded moves replayed
  by the independent Python rules.

## 6. Not automatable

| Area | Why | Coverage |
|---|---|---|
| Frame time, thermals, memory | needs hardware | device checklist |
| Real-size legibility, safe areas | needs hardware | device checklist |
| Audio tone | human judgement | **not performed** (recorded as a gap) |
| Visual polish | judgement | screenshots + review |

## 7. Regression policy

- Tests must not be weakened to make a change pass.
- New pure logic gets a check in `test_rules.gd`; new screen behaviour gets a
  step in `test_flow.gd`; new solver/game interaction gets a direction-2 case.
- `tools/test.ps1` is the gate before every build and requires **exit code 0**
  and `FAILED: 0` in each suite.
