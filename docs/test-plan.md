# Test Plan

**Ticket:** M8-01
**Status:** current as of 13 November 2026 (release-candidate cycle)

---

## 1. Layers

| Layer | Tool | Command | Authority |
|---|---|---|---|
| Rules + validation + layout + progress | GDScript, headless | `tests/test_rules.gd` | Authoritative for R1–R8, W1, level validation, board layout, save format |
| Solver | Python 3.12 | `tools/solver/solve.py godot/levels/*.json --summary` | Authoritative for solvability and minimum moves |
| Parity | GDScript + solver paths | `tests/parity.gd` | Authoritative for solver↔game agreement |
| Integration flow | GDScript, headless | `tests/test_flow.gd` | Drives the real game screens through all 30 levels via selection/transfer/undo |
| Manual desktop | Real window, real mouse | see §4 | Authoritative for the interface |
| Device | Deferred by owner | `docs/device-test-checklist.md` | Not available |

Solver output never counts as manual completion. Parity proves the rules agree;
it does not prove the UI is usable. The flow harness exercises the game's own
input path but still does not prove pixels land where a finger lands — that is
what the manual pass and the debug overlay are for.

Run everything with:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

## 2. Results

| Suite | Result | Date |
|---|---|---|
| Rules, validation, layout, progress | **108 passed, 0 failed** | 13 Nov 2026 |
| Parity | **153 checks, 0 failed, 30 levels** | 13 Nov 2026 |
| Integration flow | **141 passed, 0 failed, 30/30 levels solved through the game** | 13 Nov 2026 |
| Manual desktop | Level 1 interaction set (select, pour, undo, real mouse) + hit-alignment at 4 and 6 tubes | 13 Nov 2026 |
| Manual full playthrough | 1 of 30 done by hand (Level 1). 29 levels covered only by the flow harness. | — |
| Device | Not run (deferred) | — |

## 3. What the suites cover

### Rules (`test_rules.gd`)
- Construction, clone independence, all move-legality rules, atomic apply,
  whole-run transfer, win detection, canonical keys.
- Level validation: ruleVersion, capacity, tube shape, per-colour counts,
  empty-tube requirement, already-won rejection, non-object rejection, all 30
  shipped levels validated through the game's own validator.
- `BoardLayout`: 3/4/5/6/8 tubes, ordering, centring, width containment,
  baseline, taller viewports, degenerate input.
- `ProgressStore`: missing file, round-trip, corrupt JSON, negative clamping,
  non-positive bests discarded.

### Parity (`parity.gd`)
- Replays the independent Python solver's path for every level through
  `PuzzleState` and checks every move is legal and the final board is a win.

### Integration flow (`test_flow.gd`)
- Boots `main.tscn`, then for each level: starts it, taps the verified
  solution's source/destination tubes, checks the game declares a win, that the
  move count equals the solver's minimum, that a best is recorded, and that the
  win card exists.\n- Checks back-navigation: gameplay → map → home, credits → home, and that back at home does not quit on desktop.
- Checks progression reaches level 30, the save file contains 30 bests, undo
  restores the exact board and counter, undo at the start is harmless, restart
  opens the confirmation, an empty tube cannot be selected, and the Android back notification routes through `_go_back()`.

## 4. Manual desktop pass (this cycle)

Performed in a real 720 × 1280 window with OS-level mouse input:

1. Launched the saved profile → Home showed **Continue · Level 1**.
2. Started the level, pressed F1 → debug overlay drew four hit strips exactly
   around four vessels.
3. Clicked tube 1 → gold rim, lift, "selected 1".
4. Clicked empty tube 3 → two aqua units poured, moves 0 → 1.
5. Clicked Undo → board and counter restored to the start.
6. Captured home, levels, credits, gameplay, selection, transfer, undo,
   completion, debug and final-level screens (`docs/evidence/rc-*.png`).

A six-tube board was checked with the overlay (`rc-debug.png`): strips align
with all six vessels.

Not manually verified: levels 2–30 completion by hand, audio perception,
physical-size legibility. These are recorded as gaps rather than passes.

## 5. Not automatable

| Area | Why | Covered by |
|---|---|---|
| Frame time, thermals, memory | needs the S23 Ultra | device checklist |
| Touch at real size, safe areas | needs the device | device checklist |
| Audio quality | perception | manual listen |
| Visual polish | judgement | screenshots + review |

## 6. Regression policy

- Existing tests must not be weakened to make a change pass.
- New pure logic gets a test in `test_rules.gd`; new screen behaviour gets a
  step in `test_flow.gd` where it can run headless.
- `tools/test.ps1` is the gate before any build.
