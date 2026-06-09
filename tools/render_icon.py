#!/usr/bin/env python3
"""Render ios/icons/icon_1024.png from the icon.svg design — pure stdlib.

App Store icons must be 1024x1024, opaque, NO transparency and NO rounded
corners (Apple applies the mask). So this draws the same fox primitives as
icon.svg on a SOLID square background. Anti-aliased via 4x4 supersampling,
painted bottom-up (painter's algorithm). PNG is truecolor (no alpha channel).

Run: python3 tools/render_icon.py
"""
import math
import struct
import zlib
from pathlib import Path

N = 1024
S = N / 128.0          # icon.svg uses a 128 unit canvas
SS = 4                 # supersamples per axis (16 per pixel) for smooth edges
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ios" / "icons" / "icon_1024.png"

buf = bytearray(N * N * 3)


def hexrgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def fill(color):
    r, g, b = color
    for i in range(0, len(buf), 3):
        buf[i] = r; buf[i + 1] = g; buf[i + 2] = b


def blend_px(x, y, color, a):
    if a <= 0:
        return
    if a > 1:
        a = 1.0
    o = (y * N + x) * 3
    ia = 1.0 - a
    buf[o] = int(color[0] * a + buf[o] * ia)
    buf[o + 1] = int(color[1] * a + buf[o + 1] * ia)
    buf[o + 2] = int(color[2] * a + buf[o + 2] * ia)


def paint(bbox, inside, color, alpha=1.0):
    """bbox in svg units; `inside(sx,sy)->bool` in svg units; supersampled."""
    x0 = max(0, int(bbox[0] * S)); y0 = max(0, int(bbox[1] * S))
    x1 = min(N, int(math.ceil(bbox[2] * S))); y1 = min(N, int(math.ceil(bbox[3] * S)))
    step = 1.0 / SS
    inv = 1.0 / (SS * SS)
    for py in range(y0, y1):
        for px in range(x0, x1):
            hits = 0
            for j in range(SS):
                sy = (py + (j + 0.5) * step) / S
                for i in range(SS):
                    sx = (px + (i + 0.5) * step) / S
                    if inside(sx, sy):
                        hits += 1
            if hits:
                blend_px(px, py, color, alpha * hits * inv)


def circle(cx, cy, r, color, alpha=1.0):
    r2 = r * r
    paint((cx - r, cy - r, cx + r, cy + r),
          lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r2, color, alpha)


def ellipse(cx, cy, rx, ry, color, alpha=1.0):
    paint((cx - rx, cy - ry, cx + rx, cy + ry),
          lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0, color, alpha)


def polygon(pts, color, alpha=1.0):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]

    def inside(x, y):
        c = False
        n = len(pts)
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]; xj, yj = pts[j]
            if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
                c = not c
            j = i
        return c
    paint((min(xs), min(ys), max(xs), max(ys)), inside, color, alpha)


def stroke_quad(p0, ctrl, p1, width, color):
    # Sample the quadratic Bezier into segments, fill round-capped band.
    pts = []
    steps = 24
    for k in range(steps + 1):
        t = k / steps
        mt = 1 - t
        x = mt * mt * p0[0] + 2 * mt * t * ctrl[0] + t * t * p1[0]
        y = mt * mt * p0[1] + 2 * mt * t * ctrl[1] + t * t * p1[1]
        pts.append((x, y))
    hw = width / 2.0
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]

    def dist2_seg(px, py, a, b):
        ax, ay = a; bx, by = b
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        if L == 0:
            return (px - ax) ** 2 + (py - ay) ** 2
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L))
        cx, cy = ax + t * dx, ay + t * dy
        return (px - cx) ** 2 + (py - cy) ** 2

    def inside(x, y):
        for i in range(len(pts) - 1):
            if dist2_seg(x, y, pts[i], pts[i + 1]) <= hw * hw:
                return True
        return False
    paint((min(xs) - hw, min(ys) - hw, max(xs) + hw, max(ys) + hw), inside, color)


def write_png(path):
    raw = bytearray()
    for y in range(N):
        raw.append(0)  # filter type 0
        o = y * N * 3
        raw.extend(buf[o:o + N * 3])
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
    ihdr = struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0)  # 8-bit truecolor, no alpha
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", comp))
        f.write(chunk(b"IEND", b""))


# --- the fox, layered bottom-up (mirrors icon.svg) ---
fill(hexrgb("#a8e6cf"))                                          # solid bg (no corners)
polygon([(36, 48), (28, 14), (62, 36)], hexrgb("#e88a4f"))       # ears (outer)
polygon([(92, 48), (100, 14), (66, 36)], hexrgb("#e88a4f"))
polygon([(38, 42), (34, 22), (54, 36)], hexrgb("#fff3e6"))       # ears (inner)
polygon([(90, 42), (94, 22), (74, 36)], hexrgb("#fff3e6"))
circle(64, 70, 34, hexrgb("#f09a5e"))                            # head
ellipse(64, 88, 18, 13, hexrgb("#fff3e6"))                       # muzzle
circle(38, 78, 6, hexrgb("#ff8b94"), 0.55)                       # cheeks
circle(90, 78, 6, hexrgb("#ff8b94"), 0.55)
circle(50, 62, 5, hexrgb("#3d405b"))                             # eyes
circle(78, 62, 5, hexrgb("#3d405b"))
circle(52, 60, 1.8, hexrgb("#ffffff"))                           # eye glints
circle(80, 60, 1.8, hexrgb("#ffffff"))
circle(64, 81, 4, hexrgb("#3d405b"))                             # nose
stroke_quad((56, 90), (64, 97), (72, 90), 3.5, hexrgb("#3d405b"))  # smile

write_png(OUT)
print(f"wrote {OUT.relative_to(ROOT)} ({N}x{N}, opaque)")
