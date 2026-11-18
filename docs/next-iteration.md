# Next iteration — where to pick up

**Written:** 18 November 2026, end of the cycle that added the pour animation,
music, volume controls and the visual pass against Magic Sort!.
**Baseline:** `b1579db` still intact; everything since is additive.
**Repo:** https://github.com/kieronpeters/sort-master (private)

The release is still a **candidate**, not a release. Nothing here is blocked on
code; most of it is blocked on a device or a decision.

---

## 1. Where it actually stands

| Gate | State |
|---|---|
| Rules / parity / flow / moves | **PASS** — 136 / 154 / 153 / 30, exit 0 |
| 30-level catalogue | **PASS** — all 30 won, every one at the solver minimum |
| Pour animation | working; verified in stills only |
| Music + volume controls | working; **not listened to by a human** |
| Android runtime | installs, launches, plays, persists — **OpenGL fallback only** |
| Vulkan mobile renderer | **unvalidated** |
| S23 Ultra physical pass | **BLOCKED** — no device connected |
| Production signing | **BLOCKED** — no keystore |
| Audio audition | **BLOCKED** — needs a human |
| Manual play (M8-06) | **1/30 by hand** |
| QA-04 SDK | recorded as 24/35 but not applicable — Godot needs Gradle to override |

## 2. Highest-value next work, in order

### P1 — Round the liquid bands (highest visual return)

Every band is a plain cylinder, so each stripe has a hard flat top and bottom.
Magic Sort!'s bands are **rounded pills** with a soft edge at every boundary, and
that — not the palette, not the colour count — is the largest remaining visual
difference. Their tubes also hold only 4–5 colours, the same as ours.

This is a geometry change: give each band a chamfered lathe profile (or a
rounded-top/bottom cylinder), then re-check that the meniscus dome still sits
cleanly and that band seams stay legible under the gloss.

Watch out: `liquid.gdshader` derives its lateral coordinate from model-space x,
so a changed profile must keep the band radius uniform in the shader's terms.

### P2 — Get it on the S23 Ultra

Everything visual this cycle is verified **in stills on the desktop renderer**.
A 0.87 s pour, a gloss highlight and a domed surface are exactly the things that
look right in a capture and wrong in motion or on a real panel. Connect the
device and the fastest win is a single launch:

- does it render at all on **Vulkan**? No emulator backend could present a
  Vulkan swapchain, so the shipped renderer has never drawn a frame.
- does the pour feel right at 60 fps?
- does the gloss shimmer or band on the OLED?

### P3 — Pour z-order

In the mid-pour frames the travelling bottle can read as passing **behind** its
neighbours. It is lifted toward the camera (`POUR_FRONT = 0.55`), but the glass is
alpha-blended, so draw order can beat depth. Needs a render-order fix or a
material tweak, then a re-capture.

### P4 — Music intensity

The bed is louder now (peak −11.7 dBFS, played at −9 dB) but it is still three
slow ambient pads. If it does not feel like it drives the game, volume is the
wrong dial — it needs a **rhythmic layer** (soft pulse, marimba, low pulse on the
beat). `tools/make_music.py` is the place; it is deterministic and CC0.

### P5 — Decide QA-04 properly

Godot rejects `min_sdk`/`target_sdk` unless the Gradle build is enabled, so the
artifact ships 24/36 while the record says 24/35. Either ratify what ships or
authorise the Gradle path (`android_source.zip` ships prebuilt AARs, so the NDK
assumption in `docs/release-signing.md` may be wrong).

### P6 — Signing

Nothing can be published until the artifact is `debuggable=false` and signed with
the owner's key. The procedure is written in `docs/release-signing.md`.

### P7 — Human gates

- **Audio audition**: six sounds plus three tracks. `docs/audio-audition.html`
  has players and measurements; it needs ears.
- **Manual play**: `docs/manual-play.md`, 12 levels agreed. The automated
  playthrough proves correctness, not that the game is fun or the ramp lands.

## 3. Things not to break

- `rules-v1` and the 30 levels are frozen; solver minima and parity must stay green.
- State commits on the tap; the pour animation is presentation only and is
  skipped headless. The flow suite asserts the move counter one frame after a tap.
- The pour stream must be freed explicitly — killing a tween chain skips its
  callbacks, and an orphaned stream survives a level rebuild.
- A black frame is a valid PNG. Any screenshot assertion must check pixels, not
  existence.
- No competitor assets or code. Public store screenshots were used for
  measurement only; every implementation here is original.

## 4. Useful commands

```powershell
$env:GODOT = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File tools\test.ps1                     # 136 / 154 / 153 / 30

# play a level (or several) and capture what the player sees
& $env:GODOT --path godot --resolution 720x1280 --script res://tests/playthrough.gd -- --levels=1,2,3

# evidence screenshots for every screen
& $env:GODOT --path godot --resolution 720x1280 --script res://tests/capture.gd

# Android smoke: boots the AVD, installs, asserts it renders and responds
powershell -ExecutionPolicy Bypass -File tools\android_smoke.ps1

# regenerate the audio (both are deterministic and CC0)
py -3.12 tools\make_music.py
powershell -ExecutionPolicy Bypass -File tools\make_audio.ps1

powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1
```

Board client: `tools\flowquery.mjs`, reading the token path from
`FLOWQUERY_TOKEN_FILE`.
