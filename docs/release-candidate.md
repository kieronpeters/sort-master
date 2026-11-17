# Release candidate 0.1.0

**Status:** rebuilt 13 November 2026 after the QA pass. Release-candidate
quality; **not publishable** until signing and the device pass are complete.

## Artifacts

| Artifact | Purpose | Size | Signing |
|---|---|---|---|
| `builds/sort-master-rc.apk` | release candidate | see build output | debug key, **debuggable** (fallback; see below) |
| `builds/sort-master.apk` | development build with the F1 overlay | see build output | debug key |

Both are arm64-v8a only, **portrait-locked**, ETC2/ASTC enabled, mobile
renderer. Version `0.1.0`, version code `2`.

## Identity

| Field | Value |
|---|---|
| Package | `com.prismgarden.sortmaster` |
| App name | Sort Master |
| Version | 0.1.0 (code 2) |
| Orientation | portrait (`screenOrientation=1`, verified with aapt2) |
| Icon | original 512 px launcher icon + adaptive foreground/background (gradient-only background) |
| Min/target SDK | template defaults 24 / 36 (owner decision B8 still open) |

Version-code rule: **increment `version/code` by 1 for every distributed build;
the version name follows semver.** Both presets must be bumped together.

## Presets

| Preset | Feature tag | Excludes |
|---|---|---|
| `Android` (debug) | `dev_build` | — |
| `Android RC` | `release_build` | `scripts/debug/*`, `scripts/dev/*`, `scenes/dev/*`, `tests/*` |

`main.gd` gates the overlay on
`not OS.has_feature("release_build") and (OS.is_debug_build() or OS.has_feature("dev_build"))`
and loads the overlay script only through a runtime `load()` inside that gate.

## Verification performed

- `tools/test.ps1` at the 13 Nov build: rules 118/0, parity 154/0, flow 150/0, game-moves replay
  30/30 — all exit 0.
- `tools/build_rc.ps1` asserts package id, version code 2 and
  `screenOrientation=1` with `aapt2`; a landscape APK now fails the build.
- APK signature verified with `apksigner` (v2/v3; v1 not required at minSdk 24).
- RC content contains no `debug_overlay`, tests, dev scenes or `scripts/debug`
  (verified in the exported APK, not only a separate pack).
- Launcher icons present at every density plus `mipmap-anydpi-v26/icon.xml`;
  adaptive background is gradient-only, so the launcher cannot double-draw the
  bottle.

## Signing — owner boundary (M10-03)

A production keystore does not exist and must not be invented. Without it the
RC is a **debug build**: `android:debuggable=true`, signed with the public
Godot debug key. It installs for internal testing but is not suitable for
distribution. `build_rc.ps1` reports this and leaves the release attempt log in
`builds/build-rc-release.log`.

To finish signing the owner must provide:

1. a keystore (`.jks`) and alias,
2. the store/alias passwords,
3. approval to store them locally (git-ignored) or in the preset.

## Reproduce

```powershell
powershell -ExecutionPolicy Bypass -File tools\test.ps1
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1
```

`$env:GODOT` overrides the engine path; a `godot` on PATH is also accepted.

## Remaining gates

1. Owner signing credentials (M10-03).
2. S23 Ultra device pass — `docs/device-test-checklist.md`.
3. Owner decisions: minimum Android version (B8), the 30-level palette-pair
   exceptions (`docs/palette-matrix.md`), and audio audition.
4. Store listing and publishing (owner).
