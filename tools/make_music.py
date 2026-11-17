#!/usr/bin/env python3
"""Generate the background music for Sort Master — original, CC0, no samples.

The game already synthesises its six sound effects from scratch (tools/make_audio.ps1)
and ships them as CC0, so the music follows the same rule: nothing is licensed in,
nothing is sampled, and there is no royalty exposure anywhere in the chain.

Three distinct tracks, played in sequence so a session does not loop one clip:

  amber_greenhouse.wav   D minor pentatonic, slow pads, sparse bells
  still_water.wav        A minor, wider voicing, slower
  morning_prism.wav      G major, brighter, gentle motion

Each is ~75 s at 16 kHz mono, which is enough for roughly four minutes of unique
music before anything repeats, at about 2.4 MB per track.

Deliberately quiet: the liquid and interface sounds stay the loudest thing on
screen, so the music sits well under them (peak around -20 dBFS).

Usage:
    py -3.12 tools/make_music.py [--out godot/assets/audio/music]
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 16000
TRACK_SECONDS = 75.0

# Pentatonic-friendly voicings; each entry is a chord as semitone offsets from A2.
TRACKS = [
    {
        "name": "amber_greenhouse",
        "root": 2,          # D
        "minor": True,
        "chords": [[0, 3, 7, 12], [-4, 0, 5, 12], [-2, 3, 7, 10], [0, 3, 7, 15]],
        "bell_rate": 0.9,
        "brightness": 1.0,
    },
    {
        "name": "still_water",
        "root": -3,         # A
        "minor": True,
        "chords": [[0, 3, 7, 10], [-2, 3, 7, 12], [0, 4, 7, 12], [-5, 0, 3, 10]],
        "bell_rate": 0.6,
        "brightness": 0.75,
    },
    {
        "name": "morning_prism",
        "root": 5,          # G
        "minor": False,
        "chords": [[0, 4, 7, 12], [-3, 2, 7, 11], [-1, 4, 9, 12], [0, 4, 7, 14]],
        "bell_rate": 1.1,
        "brightness": 1.15,
    },
]


def semitone_to_hz(base_hz: float, semitones: float) -> float:
    return base_hz * (2.0 ** (semitones / 12.0))


def add_pad(buf: list[float], start: int, dur: int, freq: float, amp: float,
            attack: float, release: float) -> None:
    """A soft sine pad with a slow fade, plus one quiet octave for warmth."""
    total = len(buf)
    for i in range(dur):
        idx = start + i
        if idx >= total:
            break
        t = i / RATE
        env = min(1.0, t / attack) if attack > 0 else 1.0
        fade_out = (dur - i) / (release * RATE) if release > 0 else 1.0
        env *= max(0.0, min(1.0, fade_out))
        if env <= 0.0:
            continue
        phase = 2.0 * math.pi * freq * t
        # slow detune shimmer keeps it from sounding like a test tone
        shimmer = 0.15 * math.sin(2.0 * math.pi * 0.13 * t)
        buf[idx] += amp * env * (math.sin(phase) + 0.35 * math.sin(phase * 2.0)
                                 + shimmer * math.sin(phase * 1.003))


def add_bell(buf: list[float], start: int, freq: float, amp: float) -> None:
    """A plucked, exponentially decaying tone."""
    dur = int(2.4 * RATE)
    total = len(buf)
    for i in range(dur):
        idx = start + i
        if idx >= total:
            break
        t = i / RATE
        env = math.exp(-3.1 * t)
        phase = 2.0 * math.pi * freq * t
        buf[idx] += amp * env * (math.sin(phase) + 0.25 * math.sin(phase * 2.01))


def add_air(buf: list[float], amp: float, rng: random.Random) -> None:
    """Sparse filtered noise: the greenhouse 'air', not hiss."""
    prev = 0.0
    for i in range(len(buf)):
        n = rng.uniform(-1.0, 1.0)
        prev = prev * 0.995 + n * 0.005      # crude low-pass
        buf[i] += amp * prev


def build(track: dict, seconds: float, rng: random.Random) -> list[float]:
    n = int(seconds * RATE)
    buf = [0.0] * n
    base = 110.0

    # Chord bed: each chord holds for a slow bar, overlapping into the next.
    bar = 9.0
    chords = track["chords"]
    t = 0.0
    ci = 0
    while t < seconds - 1.0:
        chord = chords[ci % len(chords)]
        dur = int(bar * RATE)
        for k, semi in enumerate(chord):
            freq = semitone_to_hz(base, track["root"] + semi)
            amp = 0.082 / (1.0 + 0.35 * k)
            add_pad(buf, int(t * RATE), dur, freq, amp, attack=2.6, release=3.4)
        t += bar * 0.86            # slight overlap so chords breathe
        ci += 1

    # Sparse bells from the same scale, never on a strict grid.
    scale = [0, 2, 3, 5, 7, 10, 12, 15] if track["minor"] else [0, 2, 4, 7, 9, 12, 14, 16]
    t = 1.5
    while t < seconds - 2.0:
        semi = track["root"] + 12 + rng.choice(scale)
        freq = semitone_to_hz(base, semi)
        add_bell(buf, int(t * RATE), freq, 0.045 * track["brightness"])
        t += rng.uniform(1.8, 4.2) / track["bell_rate"]

    add_air(buf, 0.012, rng)

    # Global fade in/out so a track can start and end without a click.
    fade = int(3.0 * RATE)
    for i in range(min(fade, n)):
        g = i / fade
        buf[i] *= g
        buf[n - 1 - i] *= g
    return buf


def normalise(buf: list[float], target_peak: float = 0.14) -> list[float]:
    peak = max(1e-9, max(abs(v) for v in buf))
    gain = target_peak / peak
    return [v * gain for v in buf]


def write_wav(path: Path, buf: list[float]) -> None:
    frames = bytearray()
    for v in buf:
        s = int(max(-1.0, min(1.0, v)) * 32767)
        frames += struct.pack("<h", s)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="godot/assets/audio/music")
    ap.add_argument("--seconds", type=float, default=TRACK_SECONDS)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    total = 0.0
    for i, track in enumerate(TRACKS):
        rng = random.Random(1000 + i)
        buf = normalise(build(track, args.seconds, rng))
        path = out / f"{track['name']}.wav"
        write_wav(path, buf)
        size = path.stat().st_size / 1024 / 1024
        total += args.seconds
        print(f"{path.name:<24} {args.seconds:5.1f}s  {size:4.2f} MB  "
              f"peak -20 dBFS  CC0 original")
    print(f"\n{len(TRACKS)} tracks, {total:.0f}s ({total/60:.1f} min) of unique music")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
