# Release candidate 0.1.0

**Status:** built 13 November 2026. Release-candidate quality; not publishable
until signing and the device pass are complete.

## Artifacts

| Artifact | Purpose | Size | Signing |
|---|---|---|---|
| `builds/sort-master-rc.apk` | release candidate | 27.06 MB | debug key (fallback; see below) |
| `builds/sort-master.apk` | development build with the F1 overlay | 27.09 MB | debug key |

Both are arm64-v8a only, portrait, ETC2/ASTC enabled, mobile renderer.

## Identity

| Field | Value |
|---|---|
| Package | `com.prismgarden.sortmaster` |
| App name | Sort Master |
| Version | 0.1.0 (code 1) |
| Orientation | portrait, immersive |
| Icon | original 512 px launcher icon + 432 px adaptive foreground/background |
| Min/target SDK | Godot Android defaults (no Gradle build) |

## Presets

| Preset | Feature tag | Excludes |
|---|---|---|
| `Android` (debug) | `dev_build` | — |
| `Android RC` | `release_build` | `scripts/debug/*`, `scripts/dev/*`, `scenes/dev/*`, `tests/*` |

`main.gd` gates the overlay on
`not OS.has_feature("release_build") and (OS.is_debug_build() or OS.has_feature("dev_build"))`,
and loads the overlay script only through a runtime `load()` inside that gate.
A release build therefore has neither the feature flag nor the file.

## Verification performed

- RC APK exists, is a valid ZIP, contains `META-INF/ANDROIDD.RSA` (signed) and
  the expected adaptive icon assets.
- Exported RC content pack (`builds/rc-content.pck`) scanned for
  `debug_overlay`, `test_flow`, `test_rules`, `vessel_spike`, `capture.gd` and
  `scripts/debug` — **none present**. The debug pack contains all of them,
  which proves the scan is meaningful.
- Export log has no icon warning and no resource errors.
- Package name, version, architecture and launcher icons read back from
  `export_presets.cfg` and the APK asset list.

## Signing — owner boundary (M10-03)

A production keystore does not exist in this environment and must not be
invented. `tools/build_rc.ps1` attempts a release export, detects the missing
keystore, and falls back to a **debug-signed export of the release
configuration**, clearly reported as such. The resulting APK installs and runs
but is not suitable for distribution.

To finish signing, the owner needs to provide:

1. a keystore (`.jks`) and alias,
2. the store/alias passwords,
3. approval to write them into the export preset or a local, git-ignored
   properties file.

## Reproduce

```powershell
powershell -ExecutionPolicy Bypass -File tools\test.ps1
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1
```

## Remaining gates

1. Owner signing credentials (M10-03).
2. S23 Ultra device pass — `docs/device-test-checklist.md`.
3. Store listing and publishing (owner).
