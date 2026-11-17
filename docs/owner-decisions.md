# Owner decisions

**Status:** four decisions **recorded** 17 November 2026; three applied, QA-04
blocked on the build pipeline (see §0.1).
**Baseline:** `b1579db`. This document records the decisions and their state.

Each decision records the evidence, the options, the consequences and a
recommendation. The owner’s choice is recorded here and on the FlowQuery ticket
before any code, level, palette or SDK change.

## 0. Recorded decisions (17 November 2026)

| ID | Decision | Recorded choice | State |
|---|---|---|---|
| QA-01 | Palette exceptions vs re-authoring 13 levels | **Option A** — accept the 13 documented exceptions | Applied (record only) |
| QA-03 | Post-win undo policy | **Policy A** — completion seals the level; `rules-v1` §7 amended (§7.1) | Applied |
| QA-04 | Minimum and target SDK | **Option A** — min 24 / target 35 | **Recorded, not applied** — see §0.1 |
| L3-5 | Levels 3–5 empty-vessel lesson | **Option A** — accept the documented exception | Applied (record only) |

### 0.1 QA-04 cannot be applied by the current pipeline

Godot 4.7.2 **rejects** `gradle_build/min_sdk` and `gradle_build/target_sdk`
unless “Use Gradle Build” is enabled:

```
ERROR: Cannot export project with preset "Android RC" due to configuration errors:
"Min SDK" can only be overridden when "Use Gradle Build" is enabled.
"Target SDK" can only be overridden when "Use Gradle Build" is enabled.
```

Setting the values does not change the artifact, it breaks the export. The
presets are therefore blank, and the APK ships the template defaults:
**minSdk 24 / targetSdk 36**, verified with `aapt2` on the rebuilt RC.

A second finding changes the recommendation’s rationale: **target 35 does not
avoid edge-to-edge.** Android 15 enforces edge-to-edge for apps targeting API 35
and above, so 35 and 36 behave the same way on Android 15+ devices. Only target
34 or lower defers it, which is below the current Play requirement.

Options open to the owner:

| Option | Work | Effect |
|---|---|---|
| **A. Ratify min 24 / target 36** | none | The record matches the artifact; edge-to-edge must still be validated on device |
| **B. Enable the Gradle build path** | install the Android build template, first build downloads a Gradle distribution | Pins the values exactly; produces a different APK that needs its own device pass. `android_source.zip` ships prebuilt `godot-lib` AARs, so the NDK/CMake that `docs/release-signing.md` assumed may not be required |
| C. Record 24 / 35 and ship 24 / 36 | none | **Rejected** — the record would not match the artifact |

Until this is settled, gate 9 (`docs/release-readiness.md`) stays open and the
device pass must exercise edge-to-edge and safe-area insets (D08, D09).

### 0.2 Independent re-verification performed before recording

Neither numeric claim below was taken on trust from the earlier handover.

- `tools/solver/audit_palette.py` recomputes CIEDE2000 for every colour pair in
  every level from the level files (Machado 2009 severity 1.0, linear sRGB):
  **17 pass, 13 marginal, 0 forbidden, 13 over the four-colour cap.** Affected
  ids match the record exactly; worst pairs aqua/violet 12.9 deutan,
  sapphire/violet 13.8 protan, aqua/rose 14.3 deutan (documented values
  reproduce within ΔE 0.2).
- `tools/solver/check_empty_vessel_lesson.py` reruns the rules-v1 search with
  every pour into an empty tube forbidden: levels 3, 4 and 5 still solve in
  **6, 7, 7** — identical minima, so none requires the spare vessel. Levels 1, 2
  and 6 are unsolvable without one, so the lesson lands at L1–L2 and resumes at
  L6.

---

## QA-01 — Palette separation

### What the criterion says

M5-01 requires that no two liquid colours in the same level fall below the
defined separation threshold. The approved palette plan sets:

- **T2 = CIEDE2000 ≥ 15.0** for normal vision and for simulated deuteranopia
  and protanopia;
- 12.0–14.9 is the plan’s **“marginal — avoid in the same level”** band;
- **< 12.0 is forbidden**;
- R1 caps a level at **four colours**.

### What the shipped levels do

Audit of all 30 level files with the plan’s own metric (CIEDE2000, Machado
2009 severity 1.0, linear sRGB):

| Level | Colours | Failing pair | Normal | Protan | Deutan |
|---|---:|---|---:|---:|---:|
| 16, 19–24 | 5 | aqua / violet | 40.1 | 21.2 | **12.8** |
| 16, 19–24 | 5 | sapphire / violet | 24.2 | **13.9** | 20.0 |
| 25–30 | 6 | aqua / violet | 40.1 | 21.2 | **12.8** |
| 25–30 | 6 | sapphire / violet | 24.2 | **13.9** | 20.0 |
| 25–30 | 6 | aqua / rose | 62.6 | 17.2 | **14.4** |

- **13 of 30 levels** are affected: 16, 19, 20, 21, 22, 23, 24 (five colours)
  and 25, 26, 27, 28, 29, 30 (six colours).
- Every failing pair is in the **marginal 12–14.9 band**. **No pair is below
  the forbidden 12.0 threshold.**
- All 13 levels also exceed the four-colour cap (R1).
- Levels 1–15 and 17–18 pass both rules.

### Practical consequence

A player with deuteranopia may confuse aqua with violet (ΔE 12.8) and aqua
with rose (14.4); a player with protanopia may confuse sapphire with violet
(13.9). Hue alone is not reliable for those pairs.

The shipped game always draws a **shape symbol** on every band: aqua = prism,
violet = hexagon, rose = ring, sapphire = sparkle. Shape remains distinct when
hue collapses, and the symbols use max-contrast ink (5.0–12.1:1 authored).
Screenshots of the affected levels: `docs/evidence/qa-level-16.png`,
`qa-level-21.png`, `qa-level-25.png`, `qa-level-30.png`.

### Options

| Option | Work | Risk | Result |
|---|---|---|---|
| **A. Accept documented exceptions for 1.0** | none; record the exception | accessibility claim is weaker for 13 levels | ships now, symbols mitigate |
| B. Re-author the 13 levels to ≤4 colours and ΔE ≥15 | new levels, solver minima, solutions/parity, difficulty re-ordering, full retest | changes frozen content and the verified difficulty ramp; release slips | strongest accessibility |
| C. Hybrid: re-author only 25–30 | 6 levels | still leaves 7 five-colour marginal levels | middle ground |

### Recommendation

**A** for 1.0. The failures are marginal, not forbidden; the always-on shape
cue is present; and re-authoring risks the verified 30-level progression.
Record the exception in `docs/palette-matrix.md` and revisit in 1.1. Choose C
only if a stronger accessibility statement is required for launch.

### Decision text to approve

> QA-01: I approve Option ____. The 13 affected levels (16, 19–24, 25–30) are
> [accepted as documented exceptions / to be re-authored]. No level or palette
> change may be made before this approval.

---

## QA-03 — Post-win undo

### The conflict

`docs/rules-v1.md` §7 states that undo and restart remain available after a
win. The completion ticket requires that no input alters the board after
completion. The implementation follows the ticket: the completion card covers
the screen and the board is sealed.

### Consequence of each policy

| Policy | Behaviour | Risk |
|---|---|---|
| **A. Seal the level at completion (current)** | best and unlock are saved; the card offers Next / Replay / Levels | contradicts §7 as written; no way to inspect or undo the final board |
| B. Allow undo/restart on the card | board can be unsolved after the win was saved | save says “restored” while the board is unsolved; best/unlock would need rollback rules |

### Recommendation

**A**, and amend `rules-v1` §7 with a decision record: the level is sealed at
completion; Replay is the supported way to revisit it. This avoids a
saved-win/unsolved-board inconsistency and matches the accepted completion
ticket.

### Decision text to approve

> QA-03: I choose policy ____. If A, amend `rules-v1` §7 to state that
> completion seals the board and Replay is the supported route.

---

## QA-04 — Minimum and target SDK

### Current state

Both export presets leave `gradle_build/min_sdk` and `target_sdk` blank, so the
APK ships the Godot 4.7.2 template defaults: **minSdk 24 (Android 7.0),
targetSdk 36 (Android 16), compileSdk 36**. The installed build-tools are
35.0.1, so every build prints “Could not find version of build tools that
matches Target SDK, using 35.0.1”.

### Implications

- **min 24** covers Android 7.0 and later. It is the engine default and matches
  the arm64-only build.
- **target 36** enables Android 16 behaviour, including mandatory edge-to-edge.
  The game applies safe-area insets, but edge-to-edge has never been exercised
  on a device.
- Google Play requires a recent target API for new apps; 35 and 36 both meet
  current requirements at the time of writing.
- min 24 is a support statement, not just a build setting: it promises the game
  runs on 2016-era devices that have never been tested.

### Options

| Option | Meaning | Trade-off |
|---|---|---|
| **A. min 24, target 35** | explicit, matches installed platform/build-tools | stable, but excludes nothing; edge-to-edge not forced |
| B. min 24, target 36 | latest behaviour | requires build-tools 36 and an edge-to-edge device pass |
| C. min 26+ | drop Android 7 | smaller test surface, loses some devices |

### Recommendation

**A** for 1.0: record min 24 / target 35 explicitly in both presets, install
matching build-tools/platform, and test edge-to-edge separately before moving
to 36. If the owner prefers 36, the device pass must include edge-to-edge and
build-tools 36 must be installed.

### Decision text to approve

> QA-04: B8 minimum Android version = ____ (API ____); target API = ____.
> Apply to both presets and the device matrix.

---

## Levels 3–5 — empty-vessel lesson

### The criterion

M4-04 requires that at least one of levels 3–5 requires using the empty vessel
before the obvious move.

### Evidence

- The recorded minimum solutions for levels 3, 4 and 5 never pour into the
  empty tube (each level has exactly one empty tube; only tube 4 is empty).
- An exhaustive search that forbids the empty tube as a destination still
  solves all three in **6, 7 and 7 moves**, the same minima.
- Therefore no level in 3–5 *requires* the spare vessel. Level 2’s recorded
  path does use it, and the five- and six-colour levels need spare capacity,
  but the specific 3–5 lesson is absent.
- Move counts are 3, 6, 6, 7, 7: non-decreasing, but ties at 2–3 and 4–5; the
  “monotonically rising” wording in `docs/levels.md` is overstated.

### Options

| Option | Work | Consequence |
|---|---|---|
| **A. Accept the exception for 1.0** | none; record it | the lesson lands at level 2 and in later levels instead of 3–5 |
| B. Re-author 3–5 | new levels, solver minima, solutions/parity, difficulty re-check, full retest | meets the criterion but changes frozen content |

### Recommendation

**A** for 1.0. The levels are solvable, verified and non-decreasing in
difficulty; the missing lesson is a design nicety, not a defect in play. If the
owner wants the lesson, approve B explicitly and budget a full level/parity
cycle.

### Decision text to approve

> Levels 3–5: I [accept the documented exception / approve re-authoring].
> Frozen level content may not change before this approval.

---

## Not owner decisions, but still open

| ID | Item | Owner of the action |
|---|---|---|
| QA-02 | Audio audition | a human listener; see `docs/audio-audition.md` |
| QA-05 | Visual polish (glass tint, type scale, final card, themed icon, brand mark) | backlog; classify as post-1.0 unless the owner wants them in 1.0 |
| — | Production signing (M10-03) | owner key + approval; see `docs/release-signing.md` |
| — | Device pass | owner hardware; see `docs/device-validation.md` |
