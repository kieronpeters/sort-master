"""Read a Magic Sort board from a screenshot, solve it, and play it.

No hardcoded board: the bottles are located from the pixels each time, because
their positions shift when one is lifted. Colours are quantised rather than named,
so the solver only needs them to be consistent with each other.
"""
import sys, subprocess, time, collections
from pathlib import Path
sys.path.insert(0, "tools")
from measure_rendered_palette import decode_png

ADB = r"C:\Users\Asus\AppData\Local\Android\Sdk\platform-tools\adb.exe"
CAP = 4
SHOT = Path("builds/device-pass/_board.png")


def grab() -> tuple[int, int, bytes]:
    subprocess.run([ADB, "shell", "screencap", "-p", "/sdcard/_b.png"], check=False)
    subprocess.run([ADB, "pull", "/sdcard/_b.png", str(SHOT)], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return decode_png(SHOT)


def px(w, h, buf, x, y):
    i = (y * w + x) * 3
    return buf[i], buf[i + 1], buf[i + 2]


def saturated(c) -> bool:
    r, g, b = c
    mx, mn = max(c), min(c)
    return mx > 90 and (mx - mn) > 60


def find_columns(w, h, buf):
    """Columns of liquid, found on a horizontal scan through the bottle bodies."""
    best = []
    for y in range(int(h * 0.50), int(h * 0.62), 6):
        cols = [x for x in range(0, w, 3) if saturated(px(w, h, buf, x, y))]
        if len(cols) > len(best):
            best = cols
    if not best:
        return []
    # group contiguous runs of columns into bottles
    groups, run = [], [best[0]]
    for x in best[1:]:
        if x - run[-1] <= 12:
            run.append(x)
        else:
            groups.append(run)
            run = [x]
    groups.append(run)
    return [int(sum(g) / len(g)) for g in groups if len(g) > 8]


def read_bottle(w, h, buf, cx):
    """Vertical colour runs in one bottle, top to bottom, as (colour, units)."""
    ys = []
    for y in range(int(h * 0.33), int(h * 0.62)):
        ys.append((y, px(w, h, buf, cx, y)))
    runs = []
    for y, c in ys:
        if not saturated(c):
            continue
        if runs and max(abs(a - b) for a, b in zip(runs[-1][0], c)) < 40:
            runs[-1][1].append(y)
        else:
            runs.append((c, [y]))
    runs = [r for r in runs if len(r[1]) > 12]
    if not runs:
        return []
    total = sum(len(r[1]) for r in runs)
    unit = total / CAP
    out = []
    for c, yy in runs:
        n = max(1, round(len(yy) / unit))
        out.extend([tuple(v // 24 for v in c)] * n)
    return out[:CAP]


def solve(board):
    def moves(b):
        out = []
        for i, src in enumerate(b):
            if not src: continue
            col, n = src[-1], 0
            for u in reversed(src):
                if u != col: break
                n += 1
            for j, dst in enumerate(b):
                if i == j or len(dst) >= CAP: continue
                if dst and dst[-1] != col: continue
                if len(dst) + n > CAP: continue
                if not dst and len(src) == CAP and len(set(src)) == 1: continue
                out.append((i, j))
        return out

    def won(b):
        return all(not t or (len(t) == CAP and len(set(t)) == 1) for t in b)

    start = tuple(tuple(t) for t in board)
    seen = {start}
    q = collections.deque([([list(t) for t in board], [])])
    while q:
        b, path = q.popleft()
        if won(b): return path
        for i, j in moves(b):
            nb = [list(t) for t in b]
            col = nb[i][-1]
            n = 0
            for u in reversed(nb[i]):
                if u != col: break
                n += 1
            n = min(n, CAP - len(nb[j]))
            for _ in range(n):
                nb[j].append(nb[i].pop())
            k = tuple(tuple(t) for t in nb)
            if k in seen: continue
            seen.add(k)
            q.append((nb, path + [(i, j)]))
    return None


def main():
    w, h, buf = grab()
    xs = find_columns(w, h, buf)
    print(f"bottles found: {len(xs)} at x={xs}")
    board, keep = [], []
    for cx in xs:
        bands = read_bottle(w, h, buf, cx)
        print(f"  x={cx:4d}: {bands}")
        if bands:
            board.append(bands)
            keep.append(cx)
    if len(board) < 3:
        print("could not read the board reliably; not tapping")
        return 1
    y = int(h * 0.51)
    plan = solve(board)
    print("moves:", len(plan) if plan else None)
    if not plan:
        return 1
    for i, j in plan:
        print(f"  b{i+1} -> b{j+1}")
        subprocess.run([ADB, "shell", "input", "tap", str(keep[i]), str(y)], check=False)
        time.sleep(1.5)
        subprocess.run([ADB, "shell", "input", "tap", str(keep[j]), str(y)], check=False)
        time.sleep(2.0)
    print("played")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
