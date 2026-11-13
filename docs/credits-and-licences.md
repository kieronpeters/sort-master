# Credits and licences

**Status:** release-candidate record, 13 November 2026.

The game contains **no third-party artwork, audio, fonts or code** beyond the
Godot engine itself. Everything visible and audible was made for this project.

## Engine

| Item | Licence | Notes |
|---|---|---|
| Godot Engine 4.7.2 | MIT | https://godotengine.org/license |
| Godot Android export templates | MIT | bundled with the engine |
| Engine default UI font | covered by Godot's third-party notices | no font files are shipped separately |

## Artwork and design

| Asset | Source | Licence |
|---|---|---|
| Vessel lathe geometry (`vessel_mesh.gd`) | generated in project code | original work, © project owner |
| Liquid symbols `glyph_a…f.png` | `tools/make_glyphs.ps1` | original work, © project owner |
| Application icon + adaptive layers | `tools/make_icons.ps1` | original work, © project owner |
| UI icons (`icon_glyphs.gd`) | drawn in code | original work, © project owner |
| Garden shader, glass shader, palette | project code | original work, © project owner |

No purchased, downloaded or AI-generated third-party imagery is used.

## Audio

All six sounds are synthesised from first principles by
`tools/make_audio.ps1` (oscillators, envelopes and a deterministic low-passed
noise source) and are dedicated to the public domain under **CC0 1.0**. The
script is deterministic: re-running it reproduces byte-identical files.

| File | Use | Duration | Peak | Creator | Source | Licence |
|---|---|---:|---:|---|---|---|
| `select.wav` | tube selected | 0.09 s | −11.2 dBFS | this project | `tools/make_audio.ps1` | CC0 1.0 |
| `pour.wav` | legal transfer | 0.45 s | −12 dBFS | this project | `tools/make_audio.ps1` | CC0 1.0 |
| `invalid.wav` | illegal transfer / locked level | 0.16 s | −11.5 dBFS | this project | `tools/make_audio.ps1` | CC0 1.0 |
| `undo.wav` | undo | 0.14 s | −15.7 dBFS | this project | `tools/make_audio.ps1` | CC0 1.0 |
| `win.wav` | level complete | 0.85 s | −11.6 dBFS | this project | `tools/make_audio.ps1` | CC0 1.0 |
| `ui.wav` | navigation clicks | 0.05 s | −17.3 dBFS | this project | `tools/make_audio.ps1` | CC0 1.0 |

Licence texts: `licences/CC0-1.0.txt` and `licences/GODOT-MIT.txt`.

**Outstanding:** the sounds have not been auditioned by a human. The
measurements show they are short and quiet, but "tone reviewed" cannot be
claimed until someone listens on a phone speaker. No sample libraries, paid
sound packs or attribution obligations are involved.

## Data and privacy

- No accounts, analytics, advertising or network requests.
- Progress is one local JSON file (`user://progress.json`) containing the
  unlocked level, best move counts and the mute preference.
- No permissions beyond the defaults required by the Android export.

## Credits

Design, code and asset generation: the Sort Master project.
Engine: Godot Engine contributors (MIT).
