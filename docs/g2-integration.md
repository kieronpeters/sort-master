# G2 Integration — 3D vessels inside the gameplay scene

**Date:** 13 November 2026
**Scope:** rendering only. No rule, solver, level or input-semantics change.

---

## 1. Approach chosen: SubViewport

The gameplay screen is a `Control` tree built in code (`scripts/ui/main.gd`), with navigation, HUD, dialogs and progress all in 2D. Two options were available:

| Option | Assessment |
|---|---|
| **SubViewport hosting a 3D board** *(chosen)* | The 3D scene is a child of one `SubViewport` placed behind the existing HUD. Input stays in 2D. Nothing above the board changes. |
| Full 3D gameplay scene | Would re-implement the HUD, navigation, menus and input in 3D. Large change, high regression risk, no visual gain for a portrait puzzle. |

The minimum change wins: **one container, one viewport, one 3D node, plus transparent hit areas.**

### Layout contract

Both sides work in the same 1080 × 900 design space:

- vessels are 132 px wide with a 14 px gap, centred;
- the 3D camera is orthographic, `size = 900 / 870` so that 1 world unit = 870 px;
- hit areas are 146 px wide (vessel + gap) so there are no dead strips between vessels.

This keeps the 3D projection and the 2D tap targets aligned by construction rather than by eye.

## 2. What changed

| File | Change |
|---|---|
| `scripts/presentation/vessel_builder.gd` | **New.** The vessel geometry and materials, extracted from the spike so spike and gameplay share one definition. |
| `scripts/presentation/board_3d.gd` | **New.** Builds a vessel per tube, owns the ortho camera, environment and lights, exposes `set_board(tubes, capacity, selected)`. |
| `scripts/ui/main.gd` | Board area now holds a `SubViewportContainer` + `SubViewport` + `Board3D`, with a transparent hit layer above it. `USE_3D` const switches back to the 2D board. |
| `scripts/ui/vessel_view.gd` | **Untouched** — the 2D fallback. |

`PuzzleState`, the solver, the level files, undo/restart, win detection and progression were not modified.

## 3. Results

| Check | Result |
|---|---|
| Board renders inside the gameplay layout | Yes — four vessels, correct scale and spacing |
| Empty, partial and full states | Yes — empty shells, 2-band and 4-band fills all render |
| Bands and glyphs readable at gameplay size | Yes, though glyphs are small at 1080-wide downscaled |
| Neck, mouth, meniscus | Present and correct |
| Transparency artefacts | None observed with 4 vessels |
| Selection feedback | Gold-tinted glass plus "Tube N selected" status |
| Tap mapping | Aligned; hit strips widened to 146 px after an edge tap missed |
| Valid move | Committed, counter incremented, board updated |
| Undo | Restored the previous board and counter |
| Restart | Restored the initial board |
| Parity (M4-02) | **153 checks, 0 failures, 30 levels** |

## 4. Evidence

- `docs/evidence/integrated-gameplay.png` — gameplay scene, level 1, four 3D vessels
- `docs/evidence/integrated-selected.png` — same scene with tube 1 selected

## 5. Fallback

`const USE_3D := true` in `main.gd`. Set it to `false` and the previous 2D `VesselView` board returns unchanged. Nothing was deleted.

## 6. Risks and what is still unproven

| Risk | Status |
|---|---|
| Mobile performance of a SubViewport + 3D board | **Unknown.** A SubViewport adds a render target and a full extra pass. This is the largest new cost and has never been measured on hardware. |
| Glow and alpha fill-rate with 9 vessels | Unknown; desktop only. |
| SubViewport resolution | Fixed 1080×820 render target upscaled to the board area. On a 1440p phone it may look soft; needs a device to judge. |
| Glyph legibility at real size | Judged on a 900 px-wide window, not a 360 dp phone. |
| Input latency | Not measured. |
| Battery/thermal | Not measured. |

None of these can be settled without the S23 Ultra, which remains deferred by the owner.

## 7. Not done

- The 2D HUD still draws its own background over the 3D board's edges in places; cosmetic.
- No pour animation (still instant), so the 3D board never animates.
- No win/celebration treatment in 3D.
