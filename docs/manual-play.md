# Manual play sheet — agreed 1.0 depth

**Target agreed 17 November 2026:** levels 1–10 plus one five-colour level
(16) and one six-colour level (25). The flow harness is not a substitute;
a row is evidence only once a human has played it and recorded the result.

Run on the debug build so the F1 overlay is available:

```powershell
adb install -r builds\sort-master.apk
```

For each level record: completed (Y/N), moves used, the move count the game
reported, whether any pour was mis-tapped, and anything that looked wrong.
Play at normal speed and with the sound on — audio and touch are part of
what this pass is checking.

Tube numbers below are 1-based, left to right, as drawn on screen.

---

## Level 1

`L1` · 2 colours · 4 tubes · capacity 4 · **minimum 3 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 3 | 2 |
| 2 | 2 | 1 | 2 |
| 3 | 2 | 3 | 2 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 2

`L2` · 3 colours · 5 tubes · capacity 4 · **minimum 6 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 5 | 1 |
| 2 | 3 | 1 | 2 |
| 3 | 3 | 5 | 1 |
| 4 | 1 | 3 | 3 |
| 5 | 4 | 5 | 2 |
| 6 | 2 | 4 | 2 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 3

`L3` · 3 colours · 5 tubes · capacity 4 · **minimum 6 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 3 | 1 |
| 2 | 4 | 2 | 1 |
| 3 | 4 | 1 | 1 |
| 4 | 2 | 4 | 3 |
| 5 | 3 | 2 | 3 |
| 6 | 1 | 3 | 3 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 4

`L4` · 3 colours · 5 tubes · capacity 4 · **minimum 7 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 2 | 1 | 1 |
| 2 | 3 | 1 | 1 |
| 3 | 3 | 2 | 1 |
| 4 | 4 | 1 | 1 |
| 5 | 4 | 3 | 1 |
| 6 | 2 | 4 | 3 |
| 7 | 2 | 3 | 1 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 5

`L5` · 3 colours · 5 tubes · capacity 4 · **minimum 7 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 3 | 1 |
| 2 | 2 | 3 | 1 |
| 3 | 2 | 4 | 1 |
| 4 | 2 | 1 | 1 |
| 5 | 4 | 2 | 3 |
| 6 | 3 | 4 | 3 |
| 7 | 1 | 3 | 3 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 6

`L6` · 4 colours · 6 tubes · capacity 4 · **minimum 8 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 6 | 2 |
| 2 | 2 | 5 | 1 |
| 3 | 2 | 3 | 1 |
| 4 | 2 | 6 | 1 |
| 5 | 1 | 2 | 1 |
| 6 | 4 | 2 | 2 |
| 7 | 4 | 6 | 1 |
| 8 | 3 | 4 | 3 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 7

`L7` · 4 colours · 6 tubes · capacity 4 · **minimum 8 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 2 | 6 | 2 |
| 2 | 1 | 2 | 1 |
| 3 | 3 | 6 | 1 |
| 4 | 4 | 3 | 1 |
| 5 | 4 | 6 | 1 |
| 6 | 1 | 4 | 2 |
| 7 | 5 | 3 | 1 |
| 8 | 2 | 5 | 2 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 8

`L8` · 4 colours · 6 tubes · capacity 4 · **minimum 9 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 4 | 1 |
| 2 | 3 | 2 | 1 |
| 3 | 3 | 1 | 2 |
| 4 | 4 | 3 | 2 |
| 5 | 2 | 4 | 2 |
| 6 | 5 | 2 | 2 |
| 7 | 5 | 3 | 1 |
| 8 | 1 | 5 | 3 |
| 9 | 1 | 2 | 1 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 9

`L9` · 3 colours · 5 tubes · capacity 4 · **minimum 10 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 4 | 1 |
| 2 | 3 | 1 | 1 |
| 3 | 2 | 3 | 1 |
| 4 | 2 | 4 | 1 |
| 5 | 1 | 2 | 2 |
| 6 | 3 | 1 | 2 |
| 7 | 3 | 4 | 1 |
| 8 | 2 | 3 | 3 |
| 9 | 1 | 2 | 3 |
| 10 | 1 | 4 | 1 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 10

`L10` · 4 colours · 6 tubes · capacity 4 · **minimum 10 moves**

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 1 | 3 | 1 |
| 2 | 4 | 3 | 1 |
| 3 | 1 | 4 | 1 |
| 4 | 5 | 2 | 1 |
| 5 | 1 | 5 | 1 |
| 6 | 2 | 1 | 2 |
| 7 | 2 | 4 | 1 |
| 8 | 3 | 2 | 3 |
| 9 | 5 | 3 | 3 |
| 10 | 1 | 5 | 3 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 16  **five-colour level — palette marginal band (QA-01)**

`L16` · 5 colours · 7 tubes · capacity 4 · **minimum 12 moves**

While playing, note whether the shape symbols are enough to tell the colours apart at arm's length. That is the mitigation QA-01 relies on.

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 2 | 6 | 1 |
| 2 | 3 | 5 | 1 |
| 3 | 2 | 3 | 1 |
| 4 | 4 | 3 | 1 |
| 5 | 2 | 4 | 1 |
| 6 | 3 | 2 | 3 |
| 7 | 1 | 3 | 1 |
| 8 | 6 | 1 | 2 |
| 9 | 6 | 3 | 1 |
| 10 | 4 | 6 | 3 |
| 11 | 5 | 4 | 3 |
| 12 | 3 | 5 | 3 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Level 25  **six-colour level — palette marginal band (QA-01)**

`L25` · 6 colours · 8 tubes · capacity 4 · **minimum 18 moves**

While playing, note whether the shape symbols are enough to tell the colours apart at arm's length. That is the mitigation QA-01 relies on.

| # | From tube | To tube | Units |
|---:|---:|---:|---:|
| 1 | 2 | 6 | 1 |
| 2 | 3 | 1 | 1 |
| 3 | 4 | 2 | 1 |
| 4 | 4 | 8 | 2 |
| 5 | 5 | 8 | 1 |
| 6 | 7 | 8 | 1 |
| 7 | 4 | 7 | 1 |
| 8 | 6 | 4 | 2 |
| 9 | 7 | 6 | 2 |
| 10 | 3 | 7 | 1 |
| 11 | 3 | 4 | 1 |
| 12 | 7 | 3 | 2 |
| 13 | 2 | 7 | 2 |
| 14 | 2 | 4 | 1 |
| 15 | 2 | 3 | 1 |
| 16 | 5 | 7 | 1 |
| 17 | 1 | 5 | 2 |
| 18 | 1 | 6 | 1 |

| Check | Result |
|---|---|
| Completed without a softlock | |
| Moves used | |
| Matches the game's reported count | |
| Every tap hit the intended tube | |
| Undo restored the exact board | |
| Back mid-level asked to confirm | |
| Notes / defects | |

---

## Sign-off

| Field | Value |
|---|---|
| Builder | |
| Device / OS | |
| APK SHA-256 | |
| Levels completed | / 12 |
| Result | PASS / FAIL |

A FAIL on any level needs the level, the move number, the expected and the
actual result, and a screenshot or logcat excerpt.
