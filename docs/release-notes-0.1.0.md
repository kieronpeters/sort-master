# Release notes — 0.1.0 (release candidate)

**Status:** release candidate. Not signed, not published.
**Date:** 18 November 2026

## What this build contains

**Gameplay.** 30 solver-verified levels under `rules-v1`. Every level completes at
its exact minimum move count: 375 moves across the catalogue, verified by replay
through the real game and independently by the Python rules.

**Pouring.** A move is no longer a teleport. The source vessel lifts out of its
slot, carries its liquid to the destination, tips to 85 degrees so its mouth sits
over the target, pours with a tapered stream while the source drains and the
destination rises, then returns home. Input is locked while the vessel is away.
The hover position is solved from the rotation rather than eyeballed, so the mouth
lands over the destination at any tilt.

**Liquid.** One continuous body per colour: no seams between bands, a domed lit
surface on top, and a gloss streak down one side. Colour only — the per-band marks
were removed at the owner's request.

**Vessels.** The shoulder was raised so a full jug reaches the neck instead of
stopping a third of the way short.

**Audio.** Six effects and five music tracks, all generated from first principles
in this repository and dedicated to CC0. The five tracks are 2.5 minutes each
(12.5 minutes before the set repeats), Ogg Vorbis at 1.9 MB total, played in
sequence and reshuffled so the same piece never plays twice in a row, with a
watchdog that restarts the bed if it ever goes quiet.

**Volume.** Separate music and effects sliders running 0-200%, each with its own
mute, all persisted. The top half of the range is a boost because the phone
speaker at 100% measured too quiet.

**Settings.** New screen reachable from home: both volume channels, their mutes,
and a statement that progress stays on the device.

**Android.** Auto Backup enabled so Play can restore progress on reinstall or a
new device with no backend and no account. 16 KB page-size compatible. The Vulkan
mobile renderer was confirmed drawing on a real S23 Ultra (SM-S918B, Android 17,
Adreno 740) — every emulator attempt had fallen back to OpenGL, so this was the
one unknown the desktop could not settle.

**Desktop.** Windows export preset, opening at 648x1152 so the window fits a
1440-tall monitor and can be closed.

## Known gaps before release

| Gap | State |
|---|---|
| Signing | No production keystore; APK is debug-signed, the Windows exe unsigned |
| Device matrix | Install, launch, Vulkan, portrait, no crash and persistence verified on the S23; audio, thermals, frame timing, launcher icon and the multi-tube boards are not |
| Accessibility | The colour-blind mitigation was removed with the marks. 13 levels sit in the marginal separation band with no secondary cue. Recorded in `docs/palette-matrix.md` 2.3 |
| Manual play | 1 of 30 by hand; the automated pass proves correctness, not that the game is enjoyable |
| Minimum SDK | B8 records 24/35 but the engine cannot apply it without a Gradle build; the artifact ships 24/36 |

## Verification

```
tools\test.ps1  ->  rules 128, parity 154, flow 153, game-moves 30, all exit 0
```

Playthrough of all 30 levels on the desktop renderer: 30/30 won at the minimum.
