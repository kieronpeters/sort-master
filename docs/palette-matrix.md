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

**Owner decision QA-01, 17 November 2026: the 13 affected levels are accepted as
documented exceptions for 1.0.** No level or palette change is permitted before a
new decision. Revisit in 1.1.

The independent QA audit recomputed CIEDE2000 separation for every level using
the plan's thresholds (T2: ΔE00 ≥ 15.0; 12–15 marginal; <12 forbidden):

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
over the R1 cap**, affected ids 16, 19–24 and 25–30 — matching this record.
It exits non-zero only if a pair falls below the forbidden 12.0 threshold, so it
can be run as a regression tripwire in future level authoring.

A hard validator guard cannot be added at 1.0: it would reject the 13 accepted
levels. It belongs with the re-authoring work in 1.1.

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
