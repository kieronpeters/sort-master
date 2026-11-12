# Test Plan

**Ticket:** M8-01
**Status:** current as of 13 November 2026

---

## 1. Layers

| Layer | Tool | Runs | Authority |
|---|---|---|---|
| Rules unit tests | GDScript, headless | `godot --headless --script res://tests/test_rules.gd` | Authoritative for R1–R8 and W1 |
| Solver | Python 3.12 | `py -3.12 tools/solver/solve.py godot/levels/*.json --summary` | Authoritative for solvability and minimum moves |
| Parity | GDScript + exported solver paths | `godot --headless --script res://tests/parity.gd` | Authoritative for solver↔game agreement |
| Manual UI playthrough | Human, real window | This machine | Authoritative for the *interface* |
| Device | Deferred by owner | — | Not available |

Solver output never counts as manual completion. Parity proves the rules agree; it does not prove the UI is usable.

## 2. Current results

| Suite | Result | Date |
|---|---|---|
| Rules unit tests | **22 passed, 0 failed** | 13 Nov 2026 |
| Parity | **153 checks, 0 failed, 30 levels** | 13 Nov 2026 |
| Manual playthrough | **1 of 30** (Level 1) | 13 Nov 2026 |
| Device | Not run (deferred) | — |

## 3. Commands

```powershell
# rules
& 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/test_rules.gd

# solver, all levels
py -3.12 tools/solver/solve.py godot/levels/level_*.json --summary

# regenerate solver paths, then parity
py -3.12 tools/solver/dump_solutions.py
& 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/parity.gd

# build
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
```

## 4. What is not covered

| Gap | Why | Consequence |
|---|---|---|
| Manual playthrough of levels 2–30 | Blocked: tapping vessels by screenshot-derived coordinates drifts at 5+ vessels | Win/undo/restart verified only on Level 1 |
| Mid-level save/resume | Feature deferred, not implemented | Only the unlocked level persists |
| Device performance, thermals, battery | Owner deferred device testing | No mobile claim is made |
| Accessibility at real phone scale | Needs device | Palette separation judged on desktop only |
| Rapid-tap and interruption | No automated UI harness | Domain-level safety is tested; UI lock is synchronous |

## 5. Evidence rules

- Every claim names the command and the observed output.
- Screenshots live in `docs/evidence/`.
- A failing or unrun check is reported as such; it is never inferred from a neighbouring pass.
- Regressions get a ticket; they are not fixed silently inside an unrelated change.
