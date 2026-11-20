# Release candidate 0.1.0

**Status:** rebuilt 17 November 2026 after the owner decisions and the type-scale
change. Release-candidate quality; **not publishable** until signing and the
device pass are complete.

## Artifacts

| Artifact | Purpose | Size | SHA-256 | Signing |
|---|---|---|---:|---|
| `builds/sort-master-rc.apk` | release candidate, built and installed 20 Nov | 27.86 MB | `1104B5607521AAD7F1E0D3E912F04D1C9B259491EEED0DD2D337D3BFD40143B7` | debug key, **debuggable** |
| `builds/sort-master.apk` | development build with the F1 overlay | 27.22 MB | not pinned - rebuilt on every developer run and not byte-reproducible | debug key |

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
| Auto Backup | **enabled** (`user_data_backup/allow=true`) - progress can be restored on reinstall or a new device with no backend and no account |
| Min/target SDK | **24 / 36** — the Godot 4.7.2 template defaults. B8 is recorded as 24 / 35 but cannot be applied without the Gradle build path; see `docs/owner-decisions.md` §0.1 |
| Type scale | `Palette.TYPE_SCALE = 1.2`, applied in `UIKit`; body copy 16.4 dp, captions 12.3 dp at the target density |

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
  30/30 — all exit 0. Re-run 17 Nov after the type-scale change: **139 / 154 /
  159 / 30, all `FAILED: 0`, exit 0** (re-run 20 Nov).
- `tools/build_rc.ps1` asserts package id, version code 2 and
  `screenOrientation=1` with `aapt2`; a landscape APK now fails the build.
- APK signature verified with `apksigner` (v2/v3; v1 not required at minSdk 24).
- RC content contains no `debug_overlay`, tests, dev scenes or `scripts/debug`
  (verified in the exported APK, not only a separate pack): 208 zip entries,
  0 matches for `debug_overlay|scripts/debug`, 0 for `tests/`, 0 for
  `scenes/dev|vessel_spike`.
- Evidence screenshots regenerated 17 Nov from `godot/tests/capture.gd` at
  720×1280 into `docs/evidence/rc-*.png`; every screen reflows with the new type
  scale and nothing clips.
- **16 KB page-size compatibility** (Play requires it for apps targeting
  Android 15+): `zipalign -c -P 16 4` passes, and both native libraries carry
  `LOAD` segments aligned to `0x4000`:
  `lib/arm64-v8a/libgodot_android.so` (72.7 MB) and `libc++_shared.so` (1.3 MB),
  all three `LOAD` segments at `0x4000`. Verified 17 Nov 2026.
- Android 15 (API 35) emulator pass: installs, launches, renders, pours, wins,
  persists across a force stop and holds portrait — see
  `docs/evidence/android/RESULTS.md`. That pass ran on the OpenGL ES 3.1
  Compatibility fallback because no emulator GPU backend can present a Vulkan
  swapchain here, so the shipped Vulkan renderer is **not** covered by it.
- **Installed and verified on the physical S23 Ultra (SM-S918B, Android 17 /
  API 37)** on 20 Nov 2026 over wireless ADB: `install -r` returned `Success`,
  `dumpsys package` reports `versionName=0.1.0`, `versionCode=2`, `minSdk=24`,
  `targetSdk=36`, `lastUpdateTime=22:34:39`. The launch itself was not confirmed on
  this build - WhatsApp held the foreground with a recording in progress.
- Launcher icons present at every density plus `mipmap-anydpi-v26/icon.xml`;
  adaptive background is gradient-only, so the launcher cannot double-draw the
  bottle.

## Catalogue

500 levels. The guarantees are not uniform, and the level files say which applies:

| Levels | Jugs | Colours | Guarantee |
|---|---:|---:|---|
| 1-30 | 4-8 | 2-6 | QA-verified set, frozen |
| 31-440 | 5-10 | 3-8 | **minimum move count**, proved by exact search |
| 441-500 | 12-14 | 8 | **solvable**, proved by replay; no minimum claimed |

The wide tiers are the only levels without a minimum-move guarantee. Proving the
exact minimum does not scale: BFS on a twelve-jug board produced no level in
twenty-eight minutes, and A* with an admissible bound closed one of four twelve-jug
boards and none of the thirteen-jug ones. Proving *solvability* closes a
fourteen-jug board in about 20 ms, so those levels ship with a recorded solution and
no `minMoves` field. Every recorded solution is replayed through the real rules
before shipping.

They render as two rows of six or three rows of five-five-four.

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
