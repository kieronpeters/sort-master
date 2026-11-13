# Rendering architecture

**Status:** current as of 13 November 2026. Supersedes the transparency notes
in `g2-integration.md` for gameplay rendering.

## 1. What is on screen

Gameplay is one `SubViewport` rendered at the 1080-wide design resolution and
stretched by a `SubViewportContainer` that fills the screen. Inside it:

| Layer | Node | Purpose |
|---|---|---|
| Garden | `GardenBackdrop` (unshaded quad, `garden_3d.gdshader`) | procedural night-greenhouse gradient, leaf silhouettes, motes and a shelf glow |
| Vessels | one `Node3D` per tube, built by `VesselBuilder` | lathed glass, liquid bands, liquid symbols, contact shadow |
| Camera | `Camera3D`, orthogonal | framed by `BoardLayout` |

The 2D HUD lives in the parent `Control` above the viewport, and the tap strips
are transparent `Control`s in that same 2D layer.

## 2. Why a backdrop plane, not viewport transparency

BUILD-03 originally tried `SubViewport.transparent_bg = true` with a 2D canvas
behind the board. That forced the camera to be re-fitted whenever the board
changed size and, in the first attempt, clipped vessels and broke the tap
mapping.

The shipped approach keeps the SubViewport **opaque** and draws the garden on a
quad behind the vessels. Depth sorting, camera framing and the fallback 2D
board all stay conventional. There is no alpha coupling between the 3D and 2D
worlds.

The quad is scaled in `board_3d.gd::_fit_camera()` to
`camera.size × aspect` plus 8% overscan, so no window size can show its edge.
It sits at `z = -1.4`; the camera is at `z = 2.0` with `near = 0.05`.

## 3. One layout for art and input

`BoardLayout.compute(tube_count, viewport)` is the single source of truth:

- design width 1080, design height derived from the real viewport;
- vessel size fitted to 88% of the width and at most 46% of the height;
- baseline at 78% of the design height;
- returns `ppu` (design px per world unit), vessel width, slot pitch, centres
  and the tap-strip top edge.

`board_3d.gd` places meshes from that result, and `main.gd::_layout_hits()`
places the tap strips from the same result. This is what removed the
M8-06 coordinate drift: the two used to be computed independently.

## 4. The glass shader

`assets/shaders/glass.gdshader` is unshaded and outputs a Fresnel-driven alpha:
an almost invisible body with a bright rim. Lighting is bypassed because a
lit transparent material produced a white specular wash that read as opaque
plastic and hid the liquid.

Two traps worth recording:

1. **`depth_draw_never` on the garden quad hid every transparent vessel.** The
   quad was participating in the transparent pass and drawing over the glass.
   Removing `depth_draw_never` fixed it. Keep the quad opaque.
2. **`NORMAL`/`VIEW` in the fragment stage are not portable across renderers.**
   The shader interpolates view-space normal and position explicitly in
   `vertex()` and computes Fresnel from those.

The lathe is built with the outer wall only (`build_glass(false)`). A double
wall doubled the layer count and made the glass milky.

## 5. Fallback

`main.gd` has `USE_3D`. Setting it to `false` builds the original 2D
`VesselView` row and skips `Board3D` entirely. The fallback is kept working so
a renderer problem on a future device is a one-line switch, not a rewrite.

## 6. Performance notes

- One directional light, two omni lights, no shadows.
- Glass is one unshaded draw per tube with alpha, no refraction.
- The garden is a single fullscreen quad with a procedural shader; no textures.
- All liquid bands are unshaded, so the palette stays exact and the material
  cost is minimal.
- The SubViewport renders at the design resolution (1080 × 1920), not the
  physical panel resolution; this is intentional for consistent cost.

Device frame-time remains unverified until the S23 Ultra pass.

## 7. QA cycle 2 corrections

- **Tone mapping switched to linear.** Filmic desaturated the liquids (amber
  `#FFC24B` rendered as `#F8D65A`, emerald as `#38C377`), which pushed a
  documented colour pair below the accessibility threshold. Linear mapping now
  renders within a few units of the authored palette.
- **The glass mouth is sealed.** The lathe profile now rolls the lip inward
  (`0.061 → 0.058 → 0.050 → 0.047`) instead of ending in an open edge, which
  read as broken glass at phone scale. Vessel height is 0.512 world units.
- **The glass body is a faint film**, not a wire and not frosted plastic:
  `body_alpha 0.022`, `edge_alpha 0.55`, Fresnel power 5.
- **The garden is brighter and dithered.** The original ramp sat within 0.3
  luminance units of a flat fill; the new top/mid/low values plus sub-LSB
  dither make the leaves, shelf light and vignette readable without competing
  with the liquids.
- **The 2D menu backdrop now actually draws.** It used `set_anchors_preset` in
  `_ready`, which left its size at zero; `set_anchors_and_offsets_preset` fixes
  it. The menu and gameplay gardens now share the same tonal family.
- **Win card moved up.** It is centred in the upper 70% of the screen with a
  0.58 scrim, so the solved vessels remain visible behind it.

