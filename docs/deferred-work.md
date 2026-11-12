# Deferred Work — post-prototype

Everything here was consciously deferred to get a playable build. Nothing listed is required for the five levels to be correct or playable.

| # | Deferred | Why | Risk if left |
|---|---|---|---|
| 1 | Pour animation (M2-05) | Correctness first; moves are instant | Game feels abrupt. No rule impact. |
| 2 | 3D vessels and the Blender pipeline (M2-01…M2-08) | G2 not run; 2D placeholder vessels used | Visual identity is not yet Prism Garden. Rules unaffected. |
| 3 | Renderer bake-off (M2-08) | Needs the device and the 3D scene | Renderer choice still provisional ("mobile"). |
| 4 | Sound and haptics (M7-02, M7-03) | No audio imported | Silent build. |
| 5 | Tutorial overlay (M6-07) | First level is self-evident enough for testing | New players may need one prompt. |
| 6 | Level-complete celebration | Plain panel used | Less satisfying, no functional gap. |
| 7 | Accessibility pass (M8-04) | Needs device + palette check on screen | Contrast unverified at phone scale. |
| 8 | Robustness suite (M8-02) | Time | Rapid-tap and interrupt paths untested beyond the rules layer. |
| 9 | Performance and thermal (M9) | Needs device | Unknown frame time on hardware. |
| 10 | App icon and adaptive icon (M5-05) | Cosmetic; export warns and uses a default | Launcher shows a generic icon. |
| 11 | Save schema beyond `unlocked` | Only progression is persisted | In-progress board is not restored after a kill. |
| 12 | Settings screen (M6-06) | No audio to toggle yet | None functionally. |
| 13 | Gradle/AAB path and release signing (M10-03) | Needs NDK/CMake and owner approval | Debug APK only. |
| 14 | Emulator feasibility execution (doc 18) | Not needed while the Ultra is the test device | No floor-device coverage. |

## Deliberate compromises in the current build

- Vessels are drawn with `_draw()` rectangles, not meshes. Readable, not premium.
- No animation, so the input lock (M3-05) is trivial: state changes are synchronous.
- Progress saves only the unlocked level, not mid-level state.
- Level 3 and Level 4 both solve in 13 moves; the difficulty ramp is not yet tuned.

## Not deferred — these must not be cut

- Rule correctness and the solver contract (`rules-v1`).
- One-commit-per-move state discipline.
- No ads, analytics, accounts or network calls.
- Undo and restart correctness.
