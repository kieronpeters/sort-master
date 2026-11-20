"""Generate the seal jingle (a bright four-note rise) and a star sprite."""
import math, struct, wave, zlib
from pathlib import Path

RATE = 16000

def bell(freq, dur, amp=0.5):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-4.2 * t) * min(1.0, t * 300.0)
        # a couple of inharmonic partials gives it a glassy chime quality
        v = (math.sin(2*math.pi*freq*t) * 1.0
             + math.sin(2*math.pi*freq*2.01*t) * 0.35
             + math.sin(2*math.pi*freq*2.98*t) * 0.16)
        out.append(v * env * amp)
    return out

notes = [523.25, 659.25, 783.99, 1046.50]   # C5 E5 G5 C6
tail = 0.9
buf = [0.0] * int(RATE * (len(notes) * 0.16 + tail))
for k, f in enumerate(notes):
    start = int(RATE * 0.16 * k)
    sample = bell(f, tail)
    for i, v in enumerate(sample):
        if start + i < len(buf):
            buf[start + i] += v * (0.8 if k < 3 else 1.0)

peak = max(abs(v) for v in buf) or 1.0
buf = [v / peak * 0.7 for v in buf]
path = Path("godot/assets/audio/seal.wav")
with wave.open(str(path), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in buf))
print(f"{path.name}: {path.stat().st_size/1024:.1f} KB, {len(buf)/RATE:.2f}s")

# --- star sprite: a soft five-point star on transparent, 32x32 ---
S = 32
px = []
for y in range(S):
    row = []
    for x in range(S):
        dx, dy = (x + 0.5 - S/2) / (S/2), (y + 0.5 - S/2) / (S/2)
        ang = math.atan2(dy, dx)
        r = math.hypot(dx, dy)
        # five lobes
        petal = abs(math.cos(2.5 * ang))
        edge = 0.32 + 0.68 * petal
        a = max(0.0, 1.0 - (r / edge))
        a = min(1.0, a * 2.2)
        row.append((255, 238, 180, int(a * 255)))
    px.append(row)

raw = b"".join(b"\x00" + b"".join(struct.pack("4B", *px[y][x]) for x in range(S)) for y in range(S))
def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
sp = Path("godot/assets/2d/star.png")
sp.write_bytes(png)
print(f"{sp.name}: {sp.stat().st_size} bytes")
