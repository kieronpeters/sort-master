# Device validation — Samsung Galaxy S23 Ultra

**Status:** package prepared, **not executed on the S23 Ultra**. No physical
device has run this build. Every physical row below is `NOT TESTED` until a human
performs it on that device.

An **emulator** pass (Android 15, API 35, x86_64, 1080 × 2400 / 411 dp) ran on
17 November 2026 and is recorded separately in
`docs/evidence/android/RESULTS.md`. It proves the build installs, launches,
renders, accepts touch, completes a level and persists progress on Android — but
it ran on the **OpenGL ES 3.1 Compatibility fallback**, because the emulator
cannot present a Vulkan swapchain. The shipped **Vulkan mobile** renderer is
therefore still unvalidated. Emulator results never overwrite the rows below.

## 1. Target and build

| Item | Value |
|---|---|
| Device | Samsung Galaxy S23 Ultra (1440 × 3088, 20:9, Android 14/15) |
| APK | `builds/sort-master-rc.apk` (27.18 MB) |
| Package | `com.prismgarden.sortmaster` |
| Version | 0.1.0 (code 2) |
| Build type | **debug build, debuggable, debug-signed** — internal testing only |
| Architecture | arm64-v8a |

The RC is not a production artifact. Do not install it as a store build.

## 2. Prerequisites

- S23 Ultra with USB debugging enabled (owner-only step).
- `adb` from Android platform-tools 37.0.1 on the test machine.
- Battery ≥ 50 %, screen lock disabled for the session, auto-rotate off.
- `adb devices` shows the device as `device` (not `unauthorized`).
- 20–30 minutes for the functional pass plus 15 minutes for the soak.

## 3. Status vocabulary

| Status | Meaning |
|---|---|
| **PASS** | Observed as expected, with a screenshot/log reference. |
| **FAIL** | Observed otherwise; record steps, screenshot and log. |
| **BLOCKED** | Could not run (device, permission, build). |
| **NOT TESTED** | Not attempted. Never report as passed. |

## 4. Test matrix

Method: **A** = automated, **S** = static APK inspection, **P** = physical
device. Automated and static rows are already evidenced; physical rows are not.

### 4.1 Installation and identity

| ID | Check | Method | Expected | Status |
|---|---|---|---|---|
| D01 | Install `adb install -r builds/sort-master-rc.apk` | P | `Success` | NOT TESTED |
| D02 | Launch from the launcher | P | Opens without crash | NOT TESTED |
| D03 | App name and icon on the launcher | P | “Sort Master”, prism bottle, no Godot default | NOT TESTED |
| D04 | Adaptive/themed icon (Android 13+) | P | Mark inside the safe circle, no double bottle | NOT TESTED |
| D05 | Package/version readback | S | `com.prismgarden.sortmaster`, code 2, 0.1.0 | **PASS** (aapt2) |
| D06 | No debug overlay or test assets | S | No `scripts/debug`, `tests/`, dev scenes | **PASS** (APK scan) |

### 4.2 Display and layout

| ID | Check | Method | Expected | Status |
|---|---|---|---|---|
| D07 | Portrait lock | P | Cannot rotate; stays portrait | NOT TESTED |
| D08 | Scaling at 1440 × 3088 | P | No letterboxing, no stretched UI | NOT TESTED |
| D09 | Safe areas: status bar, nav bar, cutout | P | HUD and buttons clear of insets | NOT TESTED |
| D10 | Home / Levels / Credits layout | P | No clipping, readable at arm’s length | NOT TESTED |
| D11 | Gameplay at 4, 5, 6, 8 tubes | P | All vessels visible, no overlap | NOT TESTED |
| D12 | Completion card (normal and final) | P | Card clear of the vessels, buttons reachable | NOT TESTED |

### 4.3 Touch and gameplay

| ID | Check | Method | Expected | Status |
|---|---|---|---|---|
| D13 | Tap accuracy at 4/5/6/8 tubes | P | Every tap selects the intended tube | NOT TESTED |
| D14 | Selection feedback | P | Lift + gold rim + base pool, ~150 ms | NOT TESTED |
| D15 | Tap selected tube again | P | Deselects | NOT TESTED |
| D16 | Empty tube first | P | “Pick a tube with liquid in it.”, no selection | NOT TESTED |
| D17 | Legal transfer | P | Contiguous top run moves, counter +1, pour sound | NOT TESTED |
| D18 | Illegal transfer (mismatch/full/no room) | P | Correct message, invalid sound, shake | NOT TESTED |
| D19 | Undo | P | Exact board and counter restored | NOT TESTED |
| D20 | Undo at start | P | “Nothing to undo.”, no crash | NOT TESTED |
| D21 | Restart with moves | P | Confirmation; confirm resets board | NOT TESTED |
| D22 | Rapid taps / double taps | P | No phantom move, no desync | NOT TESTED |
| D23 | Back mid-level with moves | P | “Leave level?” confirmation | NOT TESTED |
| D24 | Back from map / credits / home | P | Map → home; credits → home; home exits | NOT TESTED |

### 4.4 Progression and persistence

| ID | Check | Method | Expected | Status |
|---|---|---|---|---|
| D25 | Complete level 1 | P | Card, Next Level, Level 2 unlocks | NOT TESTED |
| D26 | Complete the final level | P | “Garden Restored”, Replay/Levels work | NOT TESTED |
| D27 | Force stop and relaunch | P | Continue resumes the correct level; restored tiles remain | NOT TESTED |
| D28 | Mute persists after relaunch | P | Mute state retained | NOT TESTED |
| D29 | Kill mid-level and relaunch | P | Level restarts (mid-level save deferred), no corruption | NOT TESTED |

### 4.5 Visual and audio

| ID | Check | Method | Expected | Status |
|---|---|---|---|---|
| D30 | Glass/vessel readability | P | Glass reads as glass; liquid colours distinct | NOT TESTED |
| D31 | Colour separation on the affected levels | P | Symbols distinguish aqua/violet, sapphire/violet, aqua/rose | NOT TESTED |
| D32 | Garden backdrop | P | Visible, low contrast, no banding | NOT TESTED |
| D33 | Audio triggering and balance | P | Six sounds at sensible volume; no clipping | NOT TESTED |
| D34 | Hiss/noise on pour | P | No harsh hiss at phone volume | NOT TESTED |
| D35 | Mute/unmute | P | Immediate, persists | NOT TESTED |

### 4.6 Performance and stability

| ID | Check | Method | Expected | Status |
|---|---|---|---|---|
| D36 | Frame rate, 60 s of play | P | No interaction frame > 33 ms | NOT TESTED |
| D37 | Stutter during fades/selection | P | No visible hitch | NOT TESTED |
| D38 | 15-minute thermal soak | P | Comfortable temperature; record battery delta | NOT TESTED |
| D39 | Memory across 30 level starts | P | No growth beyond noise | NOT TESTED |
| D40 | Crashes, freezes, softlocks | P | None | NOT TESTED |

## 5. Commands and evidence capture

```powershell
adb devices
adb install -r builds\sort-master-rc.apk
adb shell monkey -p com.prismgarden.sortmaster -c android.intent.category.LAUNCHER 1
adb logcat -c
adb logcat > s23-logcat.txt
adb exec-out screencap -p > s23-home.png
adb shell dumpsys gfxinfo com.prismgarden.sortmaster framestats > s23-framestats.txt
adb shell dumpsys meminfo com.prismgarden.sortmaster > s23-meminfo.txt
adb shell dumpsys battery > s23-battery.txt
```

Record `framestats` after a scripted 60-second run and battery/temperature
before and after the 15-minute soak. Keep the logcat for any failure.

## 6. Results template

| ID | Status | Evidence | Notes / reproduction |
|---|---|---|---|
| D01 | | `s23-d01-install.png` | |
| D02 | | | |
| … | | | |

A row is only PASS with a capture or log reference. Any FAIL must include the
level, the moves, the expected/actual result and a logcat excerpt.

## 7. Already verified without a device

- Package identity, version code, portrait manifest flag, ABI, icon assets,
  release gating and signature — see `docs/release-candidate.md`.
- Gameplay correctness on desktop and headless — 126 / 154 / 153 / 30 checks.
- Layout maths at 1080 × 1920 and 1080 × 2400; hit strips at 4 and 6 tubes.

These do not substitute for the physical rows above.
