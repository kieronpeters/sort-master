#!/usr/bin/env python3
"""Objective audio report + listening page for the six shipped sounds.

Measures every file in godot/assets/audio and writes docs/audio-audition.html:
a self-contained page with a player per sound, the measurements, and the A01-A14
checklist from docs/audio-audition.md.

These measurements cannot judge tone. They exist so the human listener knows
what the file actually contains before judging it, and so a defect (clipping,
DC offset, harsh high end, near-silence) is caught before wasting their time.

Usage:
    py -3.12 tools/audio_report.py
"""

from __future__ import annotations

import html
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "godot" / "assets" / "audio"
OUT = ROOT / "docs" / "audio-audition.html"

# Trigger -> human-readable role, matching docs/audio-audition.md.
ROLES = {
    "select.wav": "tube selected",
    "pour.wav": "legal transfer",
    "invalid.wav": "illegal transfer / locked level",
    "undo.wav": "undo",
    "win.wav": "level complete",
    "ui.wav": "navigation",
}

# Per-sound trim applied at play time in AudioDirector.GAINS.
GAINS = {
    "select.wav": -12.0, "pour.wav": -10.0, "invalid.wav": -9.0,
    "undo.wav": -13.0, "win.wav": -8.0, "ui.wav": -15.0,
}

CHECKLIST = [
    ("A01", "Select sound triggers once per selection", "soft tick, no double trigger"),
    ("A02", "Pour sound triggers once per legal move", "liquid sweep, not a click"),
    ("A03", "Invalid sound on illegal move", "low thud, not harsh"),
    ("A04", "Undo sound", "short descending blip"),
    ("A05", "Win sound", "warm arpeggio, <=1 s, not intrusive"),
    ("A06", "UI click on navigation", "quiet, consistent"),
    ("A07", "Volume balance across the six", "win/select audible; UI not louder"),
    ("A08", "Gameplay vs menus consistency", "same character, no jarring shift"),
    ("A09", "No clipping at 100% volume", "no crackle or distortion"),
    ("A10", "No hiss/noise, especially pour", "clean"),
    ("A11", "Repetition fatigue (5x each)", "not annoying"),
    ("A12", "Enhances without dominating", "can hear the game, not the SFX"),
    ("A13", "Mute is immediate and persists after relaunch", "silence everywhere"),
    ("A14", "No audio after backgrounding", "silence when the app is not focused"),
]


def db(ratio: float) -> float:
    return 20.0 * math.log10(ratio) if ratio > 0 else float("-inf")


def measure(path: Path) -> dict:
    with wave.open(str(path), "rb") as w:
        channels = w.getnchannels()
        width = w.getsampwidth()
        rate = w.getframerate()
        frames = w.getnframes()
        raw = w.readframes(frames)

    if width != 2:
        raise SystemExit(f"{path.name}: expected 16-bit, got {width * 8}-bit")

    count = frames * channels
    samples = struct.unpack("<%dh" % count, raw)
    peak = max(abs(s) for s in samples)
    mean = sum(samples) / count
    rms = math.sqrt(sum(s * s for s in samples) / count)

    clipped = sum(1 for s in samples if abs(s) >= 32767)
    dc = mean / 32768.0

    # High-frequency proxy: mean absolute first difference, relative to RMS.
    # A harsh, bright sound has a much larger step-to-step change than a
    # low-passed one, which is what the pour fix targeted.
    steps = sum(abs(samples[i] - samples[i - 1]) for i in range(1, count)) / max(1, count - 1)
    brightness = steps / rms if rms > 0 else 0.0

    return {
        "file": path.name,
        "role": ROLES.get(path.name, ""),
        "duration": frames / rate,
        "rate": rate,
        "channels": channels,
        "peak_dbfs": db(peak / 32768.0),
        "rms_dbfs": db(rms / 32768.0),
        "crest_db": db(peak / rms) if rms > 0 else 0.0,
        "dc": dc,
        "clipped": clipped,
        "brightness": brightness,
        "trim": GAINS.get(path.name, 0.0),
    }


def main() -> int:
    files = sorted(AUDIO.glob("*.wav"))
    if not files:
        raise SystemExit(f"no wav files in {AUDIO}")

    rows = [measure(p) for p in files]

    print(f"{'file':<12}{'role':<32}{'dur s':>7}{'peak dB':>9}{'rms dB':>8}"
          f"{'crest':>7}{'dc':>8}{'clip':>6}{'bright':>8}")
    problems = []
    for r in rows:
        print(f"{r['file']:<12}{r['role']:<32}{r['duration']:>7.2f}"
              f"{r['peak_dbfs']:>9.1f}{r['rms_dbfs']:>8.1f}{r['crest_db']:>7.1f}"
              f"{r['dc']:>8.4f}{r['clipped']:>6}{r['brightness']:>8.3f}")
        if r["clipped"]:
            problems.append(f"{r['file']}: {r['clipped']} clipped samples")
        if abs(r["dc"]) > 0.02:
            problems.append(f"{r['file']}: DC offset {r['dc']:+.3f}")
        if r["peak_dbfs"] > -1.0:
            problems.append(f"{r['file']}: peak {r['peak_dbfs']:.1f} dBFS leaves no headroom")
        if r["rate"] != 22050:
            problems.append(f"{r['file']}: rate {r['rate']} Hz, expected 22050")
        if r["channels"] != 1:
            problems.append(f"{r['file']}: {r['channels']} channels, expected mono")

    print()
    if problems:
        print("objective issues:")
        for p in problems:
            print("  -", p)
    else:
        print("objective checks: all six clean "
              "(no clipping, |DC| <= 0.02, peak <= -1 dBFS, 22 050 Hz mono)")

    # ---- listening page -------------------------------------------------
    table_rows = "".join(
        f"<tr><td>{html.escape(r['file'])}</td><td>{html.escape(r['role'])}</td>"
        f"<td>{r['duration']:.2f}</td><td>{r['peak_dbfs']:.1f}</td>"
        f"<td>{r['rms_dbfs']:.1f}</td><td>{r['crest_db']:.1f}</td>"
        f"<td>{r['trim']:.0f}</td><td>{r['clipped']}</td></tr>"
        for r in rows
    )
    players = "".join(
        f'<div class="sound"><h3>{html.escape(r["file"])} '
        f'<span class="role">{html.escape(r["role"])}</span></h3>'
        f'<audio controls preload="none" '
        f'src="../godot/assets/audio/{html.escape(r["file"])}"></audio></div>'
        for r in rows
    )
    checks = "".join(
        f'<tr><td>{cid}</td><td>{html.escape(what)}</td><td>{html.escape(expect)}</td>'
        f'<td class="blank"></td></tr>'
        for cid, what, expect in CHECKLIST
    )
    issue_html = ("<ul>" + "".join(f"<li>{html.escape(p)}</li>" for p in problems) + "</ul>"
                  if problems else "<p class='ok'>All six pass the objective checks.</p>")

    OUT.write_text(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sort Master - audio audition</title>
<style>
 body {{ font: 15px/1.5 system-ui, sans-serif; margin: 0 auto; max-width: 860px;
        padding: 32px 20px 80px; background: #0B1F27; color: #EAF7FF; }}
 h1 {{ font-size: 26px; margin: 0 0 4px; }}
 h2 {{ font-size: 18px; margin: 32px 0 10px; color: #46D8D0; }}
 h3 {{ font-size: 15px; margin: 0 0 6px; font-weight: 600; }}
 p.lead {{ color: #8FB3BF; margin: 0 0 24px; }}
 .sound {{ background: #102832; border: 1px solid #2A5A66; border-radius: 14px;
           padding: 14px 16px; margin: 10px 0; }}
 .role {{ color: #8FB3BF; font-weight: 400; font-size: 13px; }}
 audio {{ width: 100%; margin-top: 4px; }}
 table {{ border-collapse: collapse; width: 100%; font-size: 13px; }}
 th, td {{ text-align: left; padding: 7px 9px; border-bottom: 1px solid #2A5A66; }}
 th {{ color: #46D8D0; font-weight: 600; }}
 td.blank {{ width: 90px; border-bottom: 1px solid #5E808C; }}
 .ok {{ color: #46D8D0; }}
 .warn {{ background: #3A2530; border-color: #F87AA7; }}
 code {{ background: #061116; padding: 1px 5px; border-radius: 4px; }}
</style></head><body>
<h1>Audio audition &mdash; Sort Master 0.1.0</h1>
<p class="lead">Six CC0 sounds. Listen on the target phone at 50% and 100% media
volume, five plays each, before the notes below are treated as done. The
measurements are objective; tone is not. Nothing here substitutes for your ear.</p>

<h2>1. Objective measurements</h2>
<table><thead><tr><th>File</th><th>Role</th><th>Dur s</th><th>Peak dBFS</th>
<th>RMS dBFS</th><th>Crest dB</th><th>Trim dB</th><th>Clipped</th></tr></thead>
<tbody>{table_rows}</tbody></table>
<p>{'<strong>Issues found:</strong>' if problems else ''}{issue_html}</p>

<h2>2. Listen</h2>
{players}

<h2>3. Checklist</h2>
<table><thead><tr><th>ID</th><th>Check</th><th>Expected</th><th>Result</th></tr></thead>
<tbody>{checks}</tbody></table>

<h2>4. Verdict</h2>
<p>Per sound: <code>PASS</code> or <code>FAIL</code> plus a note. If a sound
fails, name the file, the trigger and the perceived problem (harsh, quiet, long,
clipped, repetitive). Do not re-tune by guesswork; open a defect.</p>
<p>Overall: <strong>&nbsp;</strong></p>
</body></html>
""", encoding="utf-8")

    print(f"\nwrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
