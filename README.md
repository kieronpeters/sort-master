# Sort Master — Prism Garden

A calm water-sort puzzle set in a midnight greenhouse. Godot 4.7.2, GDScript,
Android-first, portrait, offline.

**Status:** release candidate (unsigned). 30 solver-verified levels, frozen
`rules-v1`, rebuilt presentation, original artwork and audio. Not publishable
until the owner supplies a signing key and the S23 Ultra checklist is run.
See `docs/release-readiness.md` for the gate list and `docs/owner-decisions.md`
for the four decisions that must be recorded first.

## Run

```powershell
$env:GODOT = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT --path godot
```

## Test

```powershell
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Four suites: rules/validation/layout/save (118), solver→game parity (154),
30-level integration flow (150), and the independent Python replay of the
game's recorded moves (30 levels).

## Build

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1   # dev APK
powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1      # release candidate
```

`build_rc.ps1` requires the owner's keystore for a real release build; without
it, it produces a debuggable, debug-signed RC and says so. Both scripts verify
package id, version code and portrait lock with `aapt2`.

## Layout

```
godot/            project (scenes, scripts, levels, assets, tests)
tools/            build/test scripts, solver, asset generators
docs/             rules, rendering, palette, test plan, RC, credits, device checklist
licences/         licence texts (Godot MIT, CC0 for the audio)
```

## Documentation

- `docs/rules-v1.md` — frozen rules contract
- `docs/levels.md` — the 30-level catalogue and difficulty metrics
- `docs/rendering.md` — backdrop, glass, board layout
- `docs/palette-matrix.md` — colour and symbol contrast, known level-pair gaps
- `docs/test-plan.md` — suites, device matrix, current results
- `docs/release-readiness.md` — release gates, status and blockers
- `docs/owner-decisions.md` — palette, post-win undo, SDK and levels 3–5
- `docs/device-validation.md` — S23 Ultra matrix and evidence template
- `docs/audio-audition.md` — human listening checklist
- `docs/release-signing.md` — secure signing and production build
- `docs/release-candidate.md` — artifacts, verification, signing boundary
- `docs/credits-and-licences.md` — asset provenance
- `docs/deferred-work.md` — what is deliberately not done

## Licence

Original code and artwork. Audio is CC0 1.0. Engine: Godot, MIT
(`licences/GODOT-MIT.txt`). No accounts, ads, analytics or network calls.
