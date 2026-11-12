# G2 — 3D Vessel Validation (technical spike)

**Ticket:** M2-01 / M2-08 spike
**Date:** 13 November 2026
**Scene:** `godot/scenes/dev/vessel_spike.tscn` (isolated; the gameplay scene is untouched)
**Renderer:** Mobile (Vulkan), as set in `project.godot`
**Status:** desktop validation only. **No Android hardware test has been performed.**

---

## 1. What was built

One vessel generated procedurally at runtime, three instances showing different fill states:

- **Glass shell** — open cylinder, 48 segments, radius 85 mm, height 300 mm, alpha 0.16, roughness 0.06, rim lighting on, `cull_mode = disabled`, `depth_draw = opaque only`.
- **Liquid** — one opaque cylinder per unit band, radius 76 mm, height 75 mm (capacity 4 across 300 mm), butted directly together so the boundaries are hard edges.
- **Glyph cue** — a `Label3D` per band in front of the liquid (`o ^ # * + =`), demonstrating a permanent non-colour cue.
- **Base disc** — dark metal ring so the vessel reads as standing.
- **Lighting** — directional key (slightly blue-white), cyan omni rim from behind-left, warm omni fill from front-right, ambient 0.30.
- **Environment** — flat midnight teal background, glow on (threshold 1.0, intensity 0.5), Filmic tonemap.
- **Camera** — perspective, 30° FOV, 1.45 m back at 0.21 m height, looking slightly up at the band area. This is close to a gameplay angle: bands stay horizontal and readable.

## 2. Observations on the desktop

| What | Result |
|---|---|
| Glass reads as glass | Yes — a faint tinted body with a bright rim highlight, distinguishable from the liquid inside |
| Liquid clearly visible inside | Yes, with hard, unambiguous band boundaries |
| Correct height and shape | Bands fill the cylinder exactly; 4 bands = full, 2 bands = half |
| Separation of liquid and glass | Good: glass is transparent and edge-lit; liquid is opaque |
| Lighting and highlights | Key + rim + fill give shape; the rim highlight is doing most of the work |
| Colour readability | Readable, but **washed toward pastel** — see risks |
| Glyph cues | Present and legible, but **low contrast** against light liquids |
| Sorting artefacts | **None observed** — expected, because only one transparent surface exists per vessel |

## 3. Decisions taken

1. **Liquid is opaque, glass is the only transparent material.** With per-object sorting and no order-independent transparency, this removes the entire class of artefacts. Both liquid-through-liquid and glass-through-glass are avoided.
2. **One transparent layer per vessel, `depth_draw = opaque only`.** Keeps the glass from writing depth over the liquid behind it.
3. **No refraction, no transmission, no screen-space effects.** None of them are available or affordable on the Compatibility fallback, and the look does not need them.
4. **Bands are separate meshes, not a shader.** Chosen for correctness and debuggability; the shader variant (M2-04) can be compared later without changing the rules or the UI.
5. **Glyphs are a separate 3D label**, not baked into the liquid texture. Cheap to change, and they survive any material change.

## 4. Risks and known limitations

| Risk | Notes |
|---|---|
| **Colours drift pale** | Ambient plus filmic tonemap lifts the palette. Either lower ambient further or compensate the albedo. Needs a side-by-side against the M5-01 hex values, not eyeballing. |
| **Glyph contrast** | White glyphs on pale liquid (amber, aqua) are weak. They need a dark outline or a per-colour ink choice — the same problem M5-01 solved for text. |
| **Glass silhouette** | From some angles the rim highlight reads as a lid. The neck/opening is not modelled yet. |
| **No meniscus** | The liquid surface is a flat cylinder cap. A subtle lip/curve would help realism and band separation. |
| **Transparency cost unknown** | One alpha surface per vessel × up to 9 vessels is unmeasured on mobile. Eight overlapping transparent shells on one screen is the worst case and has never been profiled. |
| **Glow cost** | Desktop glow is free; mobile glow is not. Must be measured, and may need to be dropped on the Compatibility fallback. |
| **No MSAA decision** | Edges are aliased at this size; MSAA 2x/4x is a mobile cost trade-off still to be made. |

## 5. What still requires Android hardware

Explicitly **not** validated, and not claimed:

- frame time at 60 fps with 9 vessels and glow
- fill-rate cost of the transparent shells
- thermal behaviour over 10+ minutes
- whether the Mobile renderer is right for the S23 Ultra versus Compatibility
- colour and gamma accuracy on a real panel
- actual readability at 360 dp width in the hand

## 6. Recommendation

The approach is sound enough to proceed with:

- keep **opaque liquid + one transparent shell** as the production model;
- fix colour saturation and glyph contrast next, against the M5-01 palette;
- add a neck/mouth and a liquid meniscus before calling the vessel final;
- profile on hardware **when the owner re-enables device testing** — until then, treat performance as unknown.

Until the hardware pass happens, the 2D placeholder vessels remain in the shipping build. The spike proves the pipeline and the look, not the frame budget.

---

## 7. Second pass — colour, glyphs, neck and meniscus

The first pass left four known weaknesses. All four were addressed in the same isolated scene.

| Weakness | Change | Result |
|---|---|---|
| Palette washed toward pastel | Ambient 0.22 → 0.16, key 0.95 → 0.80, fill 0.55 → 0.40; liquid albedo darkened 6 % plus a small emissive term (0.18) to hold saturation through the Filmic tonemap | Green, amber, cyan and violet now read as themselves |
| Glyph contrast | Ink chosen by liquid luminance: near-black on light liquids, white on dark, with an opposing outline | Legible on every band, including amber |
| No neck or mouth | Tapered neck (62–72 % radius, 45 mm) added above the body | The vessel reads as a vessel, not a tube |
| No meniscus | Thin lighter disc at the liquid surface, inset to 99 % of the liquid radius | The surface is visible as a distinct plane |

A torus lip and a torus meniscus ring were tried first and **removed**: at these dimensions they rendered as floating hoops and read as artefacts, not detail. Recorded so it is not re-attempted.

### Evidence

| File | Angle |
|---|---|
| `docs/evidence/g2-vessel-validation.png` | Gameplay angle — three vessels, three fill states |
| `docs/evidence/g2-vessel-detail.png` | Detail three-quarter — one full vessel, neck and meniscus visible |

### What is still true

Everything in section 5 still holds. Nothing here has been run on Android. Glow, alpha fill-rate, thermal behaviour and the Mobile-versus-Compatibility choice remain unmeasured, and no performance claim is made.
