# rules-v1 — Gameplay Rules Specification (FROZEN)

**Version:** `rules-v1`
**Status:** **FROZEN** for the five-level prototype. Authoritative for gameplay, level authoring and the M4 solver.
**Ticket:** M3-09
**Date frozen:** 13 November 2026
**Supersedes:** the "proposed specification" in `02_GAME_DESIGN_DOCUMENT.md` section "Core rules", where the two differ.
**Change control:** any behavioural change requires `rules-v2`, a decision record and owner approval. Silent edits are prohibited — the solver, the levels and this document must always agree on the version string.

---

## 1. Scope

Initial five-level prototype only. No timer, no hints, no points, no economy, no power-ups. Those are out of scope and must not appear in any implementation of these rules.

---

## 2. Definitions

| Term | Meaning |
|---|---|
| **Tube** | One vessel. Holds an ordered stack of units, index 0 = bottom, highest index = top. |
| **Capacity** | Maximum units per tube. **4** for all v1 levels. Data-driven in code, fixed at 4 in data. |
| **Unit** | One indivisible quantity of a colour. Units of the same colour are **indistinguishable**: a state is fully described by each tube's ordered colour sequence. |
| **Colour** | A symbolic identifier (`amber`, `aqua`, …). Never compared by rendered hue — see M5-01. |
| **Top run** | The maximal sequence of same-coloured units at the top of a tube, counting downwards until the colour changes or the stack ends. |
| **Full tube** | `count == capacity`. |
| **Empty tube** | `count == 0`. |
| **Single-colour tube** | Every unit in the tube has the same colour. An empty tube is **not** single-colour. |

Contents are written bottom→top: `[A,A,B]` means A at the bottom, B on top. `[]` is empty.

---

## 3. State and level validity

A board is an ordered list of tubes. Order is presentational: two boards differing only by permuting **identical** tubes are the same state (see 11.2).

A level is **valid** only if all of these hold:

- every colour appears exactly `capacity` times across the board;
- every tube holds at most `capacity` units;
- at least one tube is empty;
- at least two tubes exist;
- the initial state is **not** already won (section 6).

An invalid level is rejected at load, and the solver exits with an error. It is never played and never "reported as unsolvable".

**A valid level always has at least one legal move.** Pour any non-empty tube into the empty one: the destination is empty (R4), has free capacity (R3), and the run cannot exceed it (R5). So no dead-end handling is needed beyond the goal test.

---

## 4. A move

A move names a source tube and a destination tube. It is **legal** only if all of the following hold.

| ID | Rule |
|---|---|
| **R1** | `source != destination`. |
| **R2** | The source tube is **not empty**. |
| **R3** | The destination is **not full** (`count < capacity`). *(Implied by R5; kept as a separate named condition for clarity and error messages.)* |
| **R4** | The destination is **empty**, **or** its top unit has the same colour as the source's top unit. |
| **R5** | Let `run` be the length of the source's top run and `free = capacity - destination.count`. Then **`run <= free`**. |
| **R6** | On a legal move, **the entire top run moves**. There is no partial transfer. |
| **R7** | The moved units keep their relative order and land on top of the destination stack. |
| **R8** | A move is applied atomically. It either happens completely or not at all. |

### 4.1 The one genuine ambiguity, resolved explicitly

The source documents say *"enough free capacity for the selected run if transferring the full contiguous group"*, which permits two readings:

1. **Full-run-only** — if the whole run does not fit, the move is illegal. *(adopted)*
2. **Partial transfer** — move as many units as fit. *(rejected)*

Reading 1 is adopted: it is what the design document recommends and what the genre convention leads players to expect.

**Evidence status, stated plainly:** frozen **on paper**, not by playtest. M3-09's intended vehicle, the M2-05 pour animation, does not exist. This is recorded as deviation **DR-01** (owner-authorised 13 November 2026), accepting paper evidence in place of the GDD's playtest gate so that solver and level work can proceed. If the later playtest prefers partial transfer, that is `rules-v2` and needs owner approval — not an edit here.

---

## 5. Worked examples

### 5.1 Valid — run fits
```
T1 [B,A,A]   T2 [A]        run 2, free 3, dest top A
→ T1 [B]     T2 [A,A,A]
```

### 5.2 Valid — empty destination
```
T1 [A,B]     T2 []         run 1, free 4
→ T1 [A]     T2 [B]
```

### 5.3 Valid — exact fill
```
T1 [B,A,A]   T2 [A,A]      run 2, free 2
→ T1 [B]     T2 [A,A,A,A]
```

### 5.4 Invalid — run does not fit (the rule that separates full-run from partial)
```
T1 [B,A,A,A] T2 [A,A]      run 3, free 2
→ ILLEGAL (R5). The move is refused; it does not move 2 of the 3.
```

### 5.5 Invalid — destination full
```
T1 [B,A]     T2 [A,A,A,A]  R3/R5 fail.
```

### 5.6 Invalid — colour mismatch
```
T1 [A,B]     T2 [C]        R4 fails: dest is not empty and its top is not B.
```

### 5.7 Invalid — same tube
```
T1 [A,B] → T1              R1 fails.
```

### 5.8 Invalid — empty source
```
T1 []        T2 [A]        R2 fails.
```

### 5.9 Completed tube as a source
```
T1 [A,A,A,A] T2 []         run 4, free 4 → LEGAL
```
A finished tube **may** be poured out. It breaks completion. Blocking it would be a new mechanic. The move leaves the canonical state unchanged, so it is legal for the player and prunable by the solver (11.4).

### 5.10 Legal but pointless
```
T1 [A]       T2 [A,A]      run 1, free 2 → LEGAL
```

---

## 6. Win condition

**W1.** The board is won when **every non-empty tube is single-colour *and* full** (`count == capacity`). Empty tubes are allowed and ignored.

Equivalently: every colour occupies exactly one tube, and that tube is full.

**Why "full" is not optional.** Without it, a colour split across two single-colour tubes (2 + 2) would satisfy a single-colour-only test and be scored as a win. That state is reachable by legal moves and is visually unfinished. The two conditions are **not** equivalent, and a goal test checking only single-colourness will under-report the minimum move count.

**Explicitly rejected:** "win when every non-empty tube is single-colour, regardless of fill". Reachable, looks wrong, and makes the solver's answer wrong.

Win is evaluated **after the commit of a move** and **once at load** (an already-won level is a defect, section 3). Never during animation.

---

## 7. Undo and restart

| Action | Semantics |
|---|---|
| **Undo** | Restores the exact previous logical state — every tube's contents in order, plus the move counter. One undo reverses exactly one move. |
| **Undo at the initial state** | No-op; the control is disabled. Must not corrupt the board. |
| **Undo during a pour** | **Exempt from the input lock.** Cancels the animation, applies to the last *committed* move, re-renders from state. The board is never redrawn from the animation. |
| **Undo after the win** | **Not available.** Completion seals the level; the recorded win is final. Replay is the supported way to revisit it (§7.1). |
| **Board after the win** | **Sealed.** No input alters the board after completion — undo and restart included. The completion card is the only affordance. |
| **Restart** | Restores the initial state exactly and clears the history. Not itself undoable. Changes nothing else. |
| **Selection after undo/restart** | Cleared. |
| **History across save/resume** | Not persisted. A resumed session starts with an empty history at the saved board. |
| **Move counter** | +1 per committed move, −1 per undo, reset by restart. Illegal moves never increment it. Display only. |
| **Restart confirmation** | UI requirement (M6-03), not a rule. |

### 7.1 Decision record — sealing at completion

**D-2026-11-17 (QA-03, owner).** Earlier revisions of this section said undo and
restart stayed available after a win. That contradicted the accepted completion
ticket, which requires that no input alters the board after completion, and it
could not be reconciled with the save format: the win is written immediately
(best moves and the next unlock), so an undo would leave a player with a
recorded win and an unsolved board.

The owner chose to make completion authoritative:

- winning seals the level; the recorded best and unlock stand;
- undo and restart are unavailable once the win is committed;
- **Replay** is the supported route to revisit a sealed level, starting a fresh
  unsealed attempt.

This documents shipped behaviour; no code change follows from the decision. It
narrows the earlier promise in this section rather than the win condition in
section 6, which is unchanged.

---

## 8. Edge cases — normative answers

| Case | Answer |
|---|---|
| Source empty | Illegal (R2). |
| Destination full | Illegal (R3/R5). |
| Source == destination | Illegal (R1). |
| Run longer than free space | Illegal; no partial move (R5, 4.1). |
| Completed tube poured elsewhere | Legal (5.9); a canonical no-op. |
| Identical colour onto identical colour | Legal, even if pointless (5.10). |
| Two identical tubes (empty or not) | Interchangeable; the solver must not double-count them. |
| Level with no empty tube | **Invalid — rejected at load** (section 3); solver exits with an error. |
| Level already won at load | **Invalid — rejected at load**; solver reports `minimumMoves: 0` only if run directly on it. |
| Colour count ≠ capacity | Invalid — rejected at load. |
| `capacity` ≠ 4 in level data | Invalid — rejected. |
| Fewer than two tubes | Invalid — rejected. |
| Corrupt or over-capacity data | Rejected at load. |
| Rapid taps / double input | One committed move per accepted input; pours are locked while in flight (M3-05). |
| Backgrounded mid-pour | Board re-rendered from state on resume; no second move. |
| Undo during a pour | See section 7 — undo is exempt from the lock. |

---

## 9. Out of scope for rules-v1

Hints, scoring, move limits, timers, extra-vessel power-ups, procedural generation, difficulty rating, capacity other than 4. Each needs a new decision.

---

## 10. Authority and precedence

1. this file (`rules-v1`);
2. `02_GAME_DESIGN_DOCUMENT.md`;
3. anything else.

A conflict found later is resolved by amending this file with a new version, never by divergent code.

---

## 11. Contract for the M4-01 solver

The solver is an independent implementation used to prove levels are solvable. It **must** implement section 4 exactly and may not "improve" the rules.

### 11.1 Input and validation

```json
{
  "id": "L3",
  "ruleVersion": "rules-v1",
  "capacity": 4,
  "tubes": [["B","A","A","B"], ["A","B","B","A"], [], []]
}
```

Tubes are listed bottom→top. The snippet is a shape example, not an authored level.

Before searching, the solver **must exit with an error** if any of these fail:

- `ruleVersion != "rules-v1"`
- `capacity != 4`
- any tube longer than `capacity`
- any colour whose total count is not exactly `capacity`
- no empty tube
- fewer than two tubes

A solver that skips validation will certify invalid levels as solvable.

### 11.2 Canonical state — a key, not a stored order

Normalise each tube to a tuple of its units, then sort the list of tuples to form the visited-set key. Identical tubes (empty or not) collapse, which keeps the state count meaningful.

The search node stores the board in **its own tube order**, which is the level order. Moves never permute tubes. If a node were stored sorted, every emitted index would refer to a permutation of the level and the path could not be replayed.

### 11.3 Search

Breadth-first search over canonical states. Depth-limited or heuristic search **must not** report a minimum: it returns `minimumMoves: null` and `bounded: true`.

### 11.4 Move generation

Generate every move satisfying R1–R8.

**One pruning rule is permitted, and only one:** skip a move whose source tube is single-colour and whose destination is empty. That move cannot change the canonical state — before: `{[A,A], []}`, after: `{[], [A,A]}` — so it is a self-loop, and removing self-loops cannot change the minimum. It holds for every single-colour source, full or not.

No other pruning is permitted. If pruning is ever added, M4-02 must run the unpruned reference search alongside it on all five levels and assert identical `minimumMoves`; a replay-only check cannot detect a lost shortest path.

### 11.5 Output

```json
{
  "levelId": "L3",
  "ruleVersion": "rules-v1",
  "solvable": true,
  "minimumMoves": 12,
  "winCondition": "every tube empty or (full and single-colour)",
  "moves": [ /* 12 entries; first shown */ { "from": 1, "to": 2, "units": 2, "colour": "A" } ],
  "visitedStates": 1841,
  "elapsedMs": 23,
  "bounded": false
}
```

| Field | Meaning |
|---|---|
| `from`, `to` | Tube indices **in the level's order**, valid against the board reached by the preceding moves. |
| `units` | Length of the top run moved; equals the number of units transferred (R6). |
| `colour` | Colour of the run (always a single colour under R4/R6). |
| `moves` | `null` when `solvable` is false or `bounded` is true. |
| `minimumMoves` | `null` when `bounded` is true. |

Invariants: when `solvable` and not `bounded`, `len(moves) == minimumMoves`, every entry is legal at its turn, and the final board satisfies W1.

### 11.6 Parity

M4-02 must prove both directions: replaying the solver's `moves` in the game reaches the win state, and replaying the game's recorded moves through the solver is accepted as legal. A deliberate rule change must make the harness fail.

---

## 12. Level file schema

Required:

| Key | Type | Notes |
|---|---|---|
| `id` | string | Stable, unique. |
| `ruleVersion` | string | Must be `"rules-v1"`. |
| `capacity` | int | Must be 4. |
| `tubes` | array of arrays | Bottom→top colour strings. |

Optional (derived, must agree with `tubes` if present): `colourCount`, `emptyCount`, `par`, `solution`, `notes`.

Authoring invariants are the section 3 list, plus: no level may be authored that the solver cannot solve.

---

## 13. Open items

| # | Item | Owner | Effect |
|---|---|---|---|
| 1 | Playtest full-run vs partial transfer | Liam, when M2-05 exists | May produce `rules-v2`; does not block M4-01 |
| 2 | Additional pruning beyond the self-loop rule | Alex | Not permitted without the M4-02 equivalence run |

---

## 14. Approval

Frozen by M3-09. Owner acceptance is recorded on the FlowQuery ticket.
