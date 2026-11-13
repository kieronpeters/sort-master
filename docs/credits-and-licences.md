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
`tools/make_audio.ps1` (sine/noise synthesis with envelopes) and are dedicated
to the public domain under **CC0 1.0**.

| File | Use |
|---|---|
| `select.wav` | tube selected |
| `pour.wav` | legal transfer |
| `invalid.wav` | illegal transfer / locked level |
| `undo.wav` | undo |
| `win.wav` | level complete |
| `ui.wav` | navigation clicks |

No sample libraries, no paid sound packs, no attribution obligations.

## Data and privacy

- No accounts, analytics, advertising or network requests.
- Progress is one local JSON file (`user://progress.json`) containing the
  unlocked level, best move counts and the mute preference.
- No permissions beyond the defaults required by the Android export.

## Credits

Design, code and asset generation: the Sort Master project.
Engine: Godot Engine contributors (MIT).
