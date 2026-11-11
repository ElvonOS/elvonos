#!/usr/bin/env python3
"""Generate the ElvonOS desktop wallpaper (dark gradient with soft glows)."""
import math
import os
import struct
import sys
import zlib

W, H = 1920, 1080
TOP = (30, 32, 48)
BOTTOM = (16, 17, 26)
GLOW1 = (138, 173, 244)
GLOW2 = (198, 160, 246)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def chunk(tag, data):
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


rows = []
for y in range(H):
    t = y / (H - 1)
    base = lerp(TOP, BOTTOM, t)
    row = bytearray([0])
    for x in range(W):
        dx = (x - 0.24 * W) / (0.55 * W)
        dy = (y - 0.14 * H) / (0.55 * H)
        g1 = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy))
        g1 = g1 * g1 * 0.38

        dx = (x - 0.82 * W) / (0.52 * W)
        dy = (y - 0.86 * H) / (0.52 * H)
        g2 = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy))
        g2 = g2 * g2 * 0.34

        vx = (x - W / 2) / (W / 2)
        vy = (y - H / 2) / (H / 2)
        vignette = max(0.0, 1.0 - 0.22 * math.sqrt(vx * vx + vy * vy))

        r = (base[0] + GLOW1[0] * g1 + GLOW2[0] * g2) * vignette
        g = (base[1] + GLOW1[1] * g1 + GLOW2[1] * g2) * vignette
        b = (base[2] + GLOW1[2] * g1 + GLOW2[2] * g2) * vignette
        row.extend((min(255, int(r)), min(255, int(g)), min(255, int(b))))
    rows.append(bytes(row))

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
png += chunk(b"IEND", b"")

out = sys.argv[1] if len(sys.argv) > 1 else "elvonos-wallpaper.png"
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
with open(out, "wb") as fh:
    fh.write(png)
print(f"wrote {out}: {W}x{H}, {len(png)} bytes")
