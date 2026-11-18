# S23 Ultra — physical device findings

**Device:** SM-S918B, Android 17 (API 37), 1080 x 2316 @ 450 dpi
**Connected over:** wireless ADB (USB never enumerated — phone reported
"Charging phone only" with the other USB modes greyed out)

## The result that matters

**The shipped Vulkan mobile renderer works on real hardware.**

```
Godot : renderingDevice: vulkan (ProjectSettings)
godot : Vulkan 1.3.128 - Forward Mobile - Using Device #0: Qualcomm - Adreno (TM) 740
```

Two things this settles:

1. Every emulator attempt failed to present a Vulkan swapchain
   (`Couldn't present to Vulkan queue`) and fell back to OpenGL ES. That was an
   emulator limitation, not a defect in the game.
2. Everything tuned against desktop captures this cycle — the liquid gloss, the
   domed meniscus, the band seams, the tapered stream, the 85-degree pour — was
   running on the renderer that ships.

The app installed (`Success`), launched, and stayed alive (pid 27717).

## Status of the automated pass: not yet complete

`tools/device_pass.ps1` reported failures that were **its own bugs, not the
app's**, and the run was paused before they were fully cleared:

- `A install -r` — an advanced-function parameter block swallowed `-r`, so the
  install never ran. Fixed by calling adb directly.
- `A shell monkey -p ... -c ...` — same cause, so the app was never launched by
  the script. The wrapper is now a simple function that passes `-args` through.

Both fixed and pushed. The remaining checks (first frame, portrait under forced
rotation, touch, crash scan, force-stop/relaunch) have not yet been re-run since
the fix, so they remain `NOT TESTED` for the formal record.

## Still outstanding on this device

- audio on the speaker (six effects, three music tracks)
- frame timing and thermal soak
- launcher icon and adaptive icon
- 5-, 6- and 8-tube boards on the physical panel
- the full 40-row matrix in `docs/device-validation.md`
