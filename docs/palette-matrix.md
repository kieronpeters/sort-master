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

## 2. Known gap — level pairs

The independent QA audit recomputed CIEDE2000 separation for every level using
the plan's thresholds (T2: ΔE00 ≥ 15.0; 12–15 marginal; <12 forbidden):

- **13 of 30 levels contain a pair below 15.0** (worst 12.9: aqua/violet under
  deuteranopia; sapphire/violet 13.8 under protanopia; aqua/rose 14.3).
- **13 of 30 levels use five or six colours**, while the palette plan's own
  rule (R1) caps a level at four and its matrix says no five-colour subset
  passes T2.

The 30-level set is frozen content and cannot be changed without owner
approval, so this is recorded as an open defect rather than silently "fixed".
Mitigations already shipped: the always-on symbol cue, max-contrast ink, and
exact palette rendering (linear tonemap, no filmic desaturation).

## 3. Rendering fidelity

The renderer was switched from `TONE_MAPPER_FILMIC` to linear tone mapping
during QA. Filmic shifted the authored colours (amber `#FFC24B` rendered as
`#F8D65A`, emerald `#2FA45F` as `#38C377`) and pushed one documented pair
below threshold. Sampled from `docs/evidence/rc-gameplay.png` after the change:
amber `#F6BE53`, emerald `#36A767` — within a few units of the authored hex.

## 4. Still unverified

- Review at 100% phone scale on the S23 Ultra (device deferred).
- A runtime guard that rejects a level whose colour set breaks the separation
  rule. Level JSON carries colour ids only; adding a palette check to the
  validator is part of the fix if the levels are ever re-authored.
