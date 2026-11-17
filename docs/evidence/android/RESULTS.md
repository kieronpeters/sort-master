# Android runtime evidence — emulator pass

**Date:** 17 November 2026
**Build under test:** debug APK (`builds/sort-master.apk`), version 0.1.0 (code 2)
**Result:** the game installs, launches, renders, accepts touch input, completes a
level, persists progress and stays portrait-locked on Android.

This is **not** the S23 Ultra pass. Every physical row in
`docs/device-validation.md` remains `NOT TESTED`. See §4 for what this pass
deliberately does not cover.

---

## 1. Environment

| Item | Value |
|---|---|
| Host | Windows, Hyper-V / WHPX accelerator operational |
| Device | Android emulator AVD `sm_test` (Pixel 6 profile) |
| Android | API 35 (Android 15), `google_apis` x86_64 |
| Display | 1080 × 2400 physical, density 420 dpi → **411 dp wide** (real phone profile) |
| GPU | Host passthrough, NVIDIA GeForce RTX 3050 Laptop GPU |
| Package under test | `com.prismgarden.sortmaster` |

## 2. How it was built, and why it is not the shipped artifact

The game ships **arm64-v8a only**, so it cannot run on an x86_64 emulator. For
this pass only, `architectures/x86_64` was flipped to `true` in the **debug**
preset (`preset.0`), the APK built (54.59 MB, dual ABI), and the preset restored
to `false` afterwards. The release-candidate preset was never touched and remains
arm64-v8a; the committed debug APK is arm64-only again.

Reproduce:

```powershell
# temporarily set architectures/x86_64=true in the [preset.0] block, then
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
adb install -r builds\sort-master.apk
adb shell monkey -p com.prismgarden.sortmaster -c android.intent.category.LAUNCHER 1
# restore architectures/x86_64=false and rebuild
```

## 3. Renderer caveat — important

The shipping build uses the **Vulkan "mobile"** renderer. The emulator **cannot
present a Vulkan swapchain** for this app. Three GPU backends were tried:

| Emulator GPU mode | Vulkan device selected | Outcome |
|---|---|---|
| `swiftshader_indirect` | SwiftShader | initialises, black screen, `Couldn't present to Vulkan queue (VkResult error 5)` on every frame |
| `host` | NVIDIA RTX 3050 (passthrough) | same failure |
| `angle_indirect` | llvmpipe (software Vulkan) | initialises, then the process exits (`OnDestroy`) before any frame |

Representative log:

```
Vulkan 1.2.0 / 1.3.0 - Forward Mobile - Using Device #0: <SwiftShader | RTX 3050 | llvmpipe>
ERROR: Couldn't present to Vulkan queue (VkResult error 5).
   at: command_queue_execute_and_present (drivers/vulkan/rendering_device_driver_vulkan.cpp:3359)
```

This is an emulator graphics limitation, not evidence of an app defect — but it
means **the shipped Vulkan renderer path is still unvalidated on any device**,
and no emulator configuration tried here can close that gap. Only the S23 Ultra
(or any real Android device) can.

The pass below therefore ran with Vulkan disabled on the emulator
(`-feature -Vulkan`), so Godot fell back to the OpenGL ES 3.1 **Compatibility**
renderer:

```
OpenGL API OpenGL ES 3.1 (4.5.0 NVIDIA 610.88) - Compatibility
Using Device: Android Emulator OpenGL ES Translator (NVIDIA GeForce RTX 3050)
```

Everything observed below is under that fallback. Layout, input, persistence and
portrait behaviour are renderer-independent; shader appearance is not.

## 4. Results

Method **P** = physical/emulated device. Only rows actually exercised are
recorded; nothing is inferred.

| ID | Check | Status | Evidence |
|---|---|---|---|
| D01 | `adb install -r` | **PASS** | "Success" |
| D02 | Launch from launcher | **PASS** | pid alive, `mCurrentFocus` = GodotApp, no crash |
| D05 | Package / version readback | **PASS** | aapt2: code 2, 0.1.0 |
| D07 | Portrait lock | **PASS** | forced `user_rotation 1`; app stayed 1080×2400 portrait |
| D08 | Scaling at 1080 × 2400 | **PASS** | no letterbox, no stretch, UI fills the frame |
| D09 | Safe areas | **PARTIAL** | immersive full-screen; emulator has no display cutout, so cutout handling is untested |
| D10 | Home / Levels layout | **PASS** | `d01-home.png`, `d05-levels.png` — no clipping at 411 dp |
| D11 | Gameplay at 4 tubes | **PASS** | `d06-gameplay.png`; 5/6/8 tubes not tested |
| D13 | Tap accuracy at 4 tubes | **PASS** | selection and pour hit the intended tube |
| D17 | Legal transfer | **PASS** | 2 units moved, MOVES 0 → 1, `d08-after-pour.png` |
| D19 | Undo | **PASS** | board and counter restored, `d09-undo.png` |
| D25 | Complete level 1 | **PASS** | 3-move minimum, "Level Complete", `d10-complete.png` |
| D27 | Force stop and relaunch | **PASS** | resumes with "Continue · Level 2", `d11-relaunch.png` |
| D30 | Glass / vessel readability | **PASS (GL fallback)** | bands read as liquid with volume |
| D31 | Colour separation symbols | **PASS** | distinct symbols visible on every band |
| D40 | Crashes / freezes | **PASS so far** | no crash across install, launch, play, relaunch |

**Not exercised — still `NOT TESTED`:** audio (D33–D35; emulator started with
`-no-audio`), frame timing and thermals (D36–D38), memory growth (D39), all
5/6/8-tube boards, restart confirmation (D21), back-navigation confirmation
(D23, D24), mid-level kill (D29), and the launcher icon / adaptive icon rows
(D03, D04).

## 5. Screenshots

| File | Shows |
|---|---|
| `d01-home.png` | home, first launch — "Begin" |
| `d05-levels.png` | level map, 0/30 restored, only level 1 unlocked |
| `d06-gameplay.png` | level 1 from the board |
| `d07-selected.png` | tube selected |
| `d08-after-pour.png` | after a legal transfer, MOVES 1, Undo enabled |
| `d09-undo.png` | after undo |
| `d10-complete.png` | completion card; Undo/Restart dimmed behind it |
| `d11-relaunch.png` | after force stop — "Continue · Level 2" |
| `d12-rotate-landscape.png` | landscape forced; app still portrait |

## 6. What this changes

Gate 13 is still **BLOCKED**, but it is no longer true that the build has never
run on Android. The useful outcomes:

- the APK installs and launches on Android 15 with no crash;
- the UI lays out correctly at 411 dp / 1080 × 2400 with the new type scale;
- touch selection and pouring work at 4 tubes;
- the completion card appears and correctly seals undo/restart (QA-03 policy A
  observed behaviourally, not just read from the source);
- progress survives a force stop;
- portrait lock holds when the system is forced to landscape.

Still open, and only the S23 Ultra can close them: the Vulkan mobile renderer,
a real display cutout, 5/6/8-tube boards, audio, frame timing, thermals and the
launcher icon.
