# Palette and colour-accessibility record

**Status:** reviewed 13 November 2026 during the QA cycle. The calculated
matrix lives in the master plan (`19_M5-01_PALETTE_AND_COLOUR_ACCESSIBILITY.md`
and `M5-01_palette.json`); this file records what the shipped game actually
does and what remains open.

## 1. Shipped liquid set

| Id | Hex | Symbol | Symbol ink | Ink contrast |
|---|---|---|---|---|
| A | `#FFC24B` amber | droplet | `#080D12` | 12.14:1 |
| B | `#46D8D0` aqua | prism | `#080D12` | 11.14:1 |
| C | `#2FA45F` emerald | leaf | `#080D12` | 6.13:1 |
| D | `#4D7BF1` sapphire | sparkle | `#080D12` | 5.03:1 |
| E | `#D0A2FF` violet | hexagon | `#080D12` | 9.56:1 |
| F | `#F87AA7` rose | ring | `#080D12` | 7.74:1 |

The ink rule now picks whichever of near-black or white has the higher WCAG
contrast, instead of a luminance threshold. That change fixed white-on-emerald
(3.2:1 authored, worse when rendered) and is covered by six unit checks
(`test_rules.gd`, threshold 4.5:1).

The symbols are always on, so hue is never the only cue.

## 2. Known gap â€” level pairs

**Owner decision QA-01, 17 November 2026: the 13 affected levels are accepted as
documented exceptions for 1.0.** No level or palette change is permitted before a
new decision. Revisit in 1.1.

The independent QA audit recomputed CIEDE2000 separation for every level using
the plan's thresholds (T2: Î”E00 â‰¥ 15.0; 12â€“15 marginal; <12 forbidden):

- **13 of 30 levels contain a pair below 15.0** (worst 12.9: aqua/violet under
  deuteranopia; sapphire/violet 13.8 under protanopia; aqua/rose 14.3).
- **13 of 30 levels use five or six colours**, while the palette plan's own
  rule (R1) caps a level at four and its matrix says no five-colour subset
  passes T2.

The 30-level set is frozen content, so this is recorded as an accepted exception
rather than silently "fixed". Mitigations already shipped: the always-on shape
symbol cue, max-contrast ink, and exact palette rendering (linear tonemap, no
filmic desaturation).

### Re-verification

`tools/solver/audit_palette.py` recomputes the whole matrix from the level files
(Machado 2009 severity 1.0, linear sRGB) and is the tool of record:

```powershell
py -3.12 tools\solver\audit_palette.py --levels godot\levels
```

Result on 17 November 2026: 30 levels, **17 pass, 13 marginal, 0 forbidden, 13
over the R1 cap**, affected ids 16, 19â€“24 and 25â€“30 â€” matching this record.
It exits non-zero only if a pair falls below the forbidden 12.0 threshold, so it
can be run as a regression tripwire in future level authoring.

A hard validator guard cannot be added at 1.0: it would reject the 13 accepted
levels. It belongs with the re-authoring work in 1.1.

### 2.1 Rendered separation â€” first measurement (17 Nov 2026)

Every figure above is measured from the authored hexes. What a player sees has
been through the linear tonemap and `liquid.gdshader`, so it is not the same.

`tools/measure_rendered_palette.py` samples an evidence screenshot and recomputes
the separation from the pixels. On the Android emulator capture of level 16
(`docs/evidence/android/d15-level16-5tubes.png`):

| Pair | Rendered | Normal Î”E | Deuteranopia Î”E |
|---|---|---:|---:|
| aqua / violet | `#3EBAB4` vs `#B18CD9` | 37.2 | **11.6** |
| aqua / violet (authored) | `#46D8D0` vs `#D0A2FF` | 40.1 | 12.9 |

The rendered pair is **closer than the authored pair**, and 11.6 is below the
plan's forbidden 12.0 threshold where the authored 12.9 is above it.

Read this with care before acting on it:

- it was captured on the **OpenGL ES 3.1 Compatibility fallback**, not the
  shipped Vulkan mobile renderer;
- the sample is a single column through each vessel centre, and the liquid
  shader deliberately darkens toward the edges, so the mean is crude;
- the direction of the effect is the meaningful part, not the exact number.

Conclusion recorded for 1.1: the mismatch between authored and rendered
separation is real enough to warrant re-measuring on the shipped renderer and on
the target device before the palette exception is re-affirmed. It does not change
the 1.0 decision, which is based on the always-on symbol cue rather than on the
pair clearing the threshold.

## 3. Rendering fidelity

The renderer was switched from `TONE_MAPPER_FILMIC` to linear tone mapping
during QA. Filmic shifted the authored colours (amber `#FFC24B` rendered as
`#F8D65A`, emerald `#2FA45F` as `#38C377`) and pushed one documented pair
below threshold. Sampled from `docs/evidence/rc-gameplay.png` after the change:
amber `#F6BE53`, emerald `#36A767` â€” within a few units of the authored hex.

## 4. Still unverified

- Review at 100% phone scale on the S23 Ultra (device deferred).
- A runtime guard that rejects a level whose colour set breaks the separation
  rule. Level JSON carries colour ids only; adding a palette check to the
  validator is part of the fix if the levels are ever re-authored.

### 2.2 Marks made subtle, palette widened to eight (17 Nov 2026)

Owner decision: the black shapes did not make visual sense and are replaced by a
quiet mark; colour count is capped at eight rather than twelve.

**Marks.** The glyph is now 0.018 world units (was 0.040), sits toward the band's
left edge, and is tinted from the band colour at 55% alpha instead of being inked
in near-black. Contrast against its own band is now held to **between 1.02 and
2.2:1** — the inverse of the old 4.5:1 rule. The band reads as colour first, which
is what the genre looks like.

**Be explicit about what this costs.** At 1.02–2.2:1 the mark is a faint emboss,
not a reliable identifier. The QA-01 exception for 13 levels was justified by
"shape remains distinct when hue collapses"; that justification is now much
weaker, and those levels are separated only by hue for a colour-blind player.
This is an accepted trade, not an oversight, and it should be revisited in 1.1.

**Palette.** Two colours were added: **G #FF4428** and **H #4FFFB2**, chosen
by search rather than by eye to maximise the worst pair against the shipped six.
The eight-colour set's worst pair is **?E 14.0** across normal, protan and deutan
— better than the shipped six's own 12.9, so headroom was added without making
anything harder to tell apart. No shipped level uses G or H; levels 1–30 still
use A–F.

Measured ceiling for reference (worst pair, all three visions):

| Colours | Worst pair | Verdict |
|---:|---:|---|
| 6 | 20.3 | meets T2 |
| 8 | 14.0–15.3 | marginal / borderline T2 |
| 10 | 12.3 | marginal |
| 12 | 9.7 | below the forbidden 12.0 |

Twelve colours separate fine for normal vision (?E 18.7) and fail badly for
protan/deutan. Twelve per level would also need 16 tubes against the board's cap
of 8, so it is a layout and level-format change, not a palette change.

### 2.3 Marks removed entirely (18 Nov 2026)

Owner decision: the per-band marks are gone. The liquid is **colour only**, as in
the rest of the genre.

This is the end of a three-step retreat from the original accessibility design:

| Step | Cue | Contrast vs band |
|---|---|---|
| Original | black shape on every band | >= 4.5:1 |
| 17 Nov | small tinted mark at the band edge | 1.02 - 2.2:1 |
| **18 Nov** | **none** | **n/a** |

**State this plainly: there is now no colour-vision mitigation at all.** The
QA-01 exception for 13 levels was accepted on the basis that "shape remains
distinct when hue collapses"; that basis no longer exists. A player with
deuteranopia or protanopia cannot separate aqua/violet (rendered dE ~11.6) on
those levels by anything except position and memory.

The eight ink-contrast checks were removed with the feature; the rules suite went
136 -> 128 checks. They tested code that no longer exists rather than being
relaxed to pass.

If accessibility is to be restored for 1.1, the options are, in order of cost:
re-author the 13 levels within the separation threshold; or reintroduce a cue
that does not clutter the water, such as a subtle pattern in the glass rather
than on the liquid.
