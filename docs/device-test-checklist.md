# Device test checklist — Samsung S23 Ultra

**Status:** not run. The device was unavailable for the release-candidate
cycle (owner decision). Nothing in this list may be reported as passed until
it has actually been executed on hardware.

Target: Samsung Galaxy S23 Ultra (1440 × 3088, 20:9, Android 14/15).

## 1. Install and identity

- [ ] `adb install -r builds/sort-master-rc.apk` succeeds.
- [ ] Launcher shows **Sort Master** with the prism bottle icon (not the
      default Godot icon), including the adaptive icon on the home screen.
- [ ] App opens in portrait and cannot be rotated.
- [ ] No splash flash of an unstyled window; immersive mode hides the bars.

## 2. Layout at real size

- [ ] Home: title, emblem, Play, Levels, Credits and mute are all readable at
      arm's length; nothing is clipped by the camera cutout or rounded corners.
- [ ] Levels: 30 tiles visible without scrolling; locked/current/restored states
      are distinguishable.
- [ ] Gameplay at 4, 5, 6 and 8 tubes: all vessels visible, none clipped, no
      overlap, tap strips centred on the bottles.
- [ ] HUD: level title, moves chip, Undo and Restart are reachable with a thumb.
- [ ] Completion card fits, including the final "Garden Restored" variant.

## 3. Touch and gameplay

- [ ] Tap a filled tube: it lifts and gains a gold rim.
- [ ] Tap the same tube: selection clears.
- [ ] Tap an empty tube first: "Pick a tube with liquid in it." and no selection.
- [ ] Legal pour: liquid moves, moves counter increments, pour sound plays.
- [ ] Illegal pour (colour mismatch, full tube, not enough room): correct
      message, invalid sound, destination shakes.
- [ ] Multi-unit top run pours in one move.
- [ ] Undo returns the exact board and the counter; Undo at start says
      "Nothing to undo."
- [ ] Restart asks for confirmation when moves exist and resets when confirmed.
- [ ] Rapid alternating taps during a pour never desynchronise art and state.
- [ ] Double tap on a tube does not produce a phantom move.

## 4. Progression and persistence

- [ ] Finish level 1: completion card, Next Level works, Level 2 unlocks.
- [ ] Force-stop the app and relaunch: Continue resumes at the correct level,
      restored tiles remain restored, mute preference persists.
- [ ] Finish level 30: "Garden Restored" card; Replay and Levels both work.
- [ ] Kill the app mid-level: relaunch restarts that level (expected, mid-level
      save is deferred) without corrupting progress.

## 5. Audio

- [ ] All six sounds play and are audible but not harsh at default volume.
- [ ] Mute silences immediately and stays muted after relaunch.
- [ ] No audio glitch when pouring while the win sound is playing.

## 6. Performance and thermals

- [ ] 15 minutes of play: no visible stutter during selection, pours or screen
      fades.
- [ ] `adb shell dumpsys gfxinfo com.prismgarden.sortmaster framestats` after a
      scripted 60-second run: record janky frame percentage and p95 frame time.
- [ ] Device temperature after 15 minutes is comfortable to hold; record the
      battery percentage delta.
- [ ] Memory does not grow across 30 level starts (record `dumpsys meminfo`).

## 7. Release-build checks

- [ ] The RC APK contains no debug overlay: press F1 with a keyboard attached,
      or inspect `assets` for `scripts/debug` (already verified on the desktop
      export; re-verify on device).
- [ ] No test scenes or capture harness are present.
- [ ] Package id is `com.prismgarden.sortmaster`, version name `0.1.0`.

## 8. Evidence to record

| Check | Result | Evidence |
|---|---|---|
| Install + icon | | screenshot |
| Home / Levels / Gameplay / Completion | | screenshots |
| 4/5/6/8-tube hit alignment | | screenshots with overlay (debug build only) |
| Frame stats | | `framestats` excerpt |
| Thermals | | temperature + battery delta |
| Save persistence | | two screenshots after relaunch |

Signing and publishing remain owner-approved steps after this list passes.
