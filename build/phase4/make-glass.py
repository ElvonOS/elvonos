#!/usr/bin/env python3
"""Create blurred wallpaper strips for Aero-glass taskbar/dock."""
import struct, zlib, sys

SRC = "/home/kirara/ElvonOS/base/configuration/wallpaper/elvonos-wallpaper.png"
OUTDIR = "/home/kirara/ElvonOS/base/configuration/wallpaper"


def read_png(path):
    d = open(path, "rb").read()
    assert d[:8] == b"\x89PNG\r\n\x1a\n"
    i = 8
    w = h = ct = None
    idat = b""
    while i < len(d):
        ln = struct.unpack(">I", d[i:i+4])[0]
        typ = d[i+4:i+8]
        data = d[i+8:i+8+ln]
        i += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct, comp, filt, inter = struct.unpack(">IIBBBBB", data)
        elif typ == b"IDAT":
            idat += data
    raw = zlib.decompress(idat)
    bpp = 4 if ct == 6 else 3
    stride = w * bpp
    out = bytearray()
    prev = bytearray(stride)
    pos = 0
    for _ in range(h):
        f = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos+stride]); pos += stride
        if f == 1:
            for x in range(bpp, stride): line[x] = (line[x] + line[x-bpp]) & 255
        elif f == 2:
            for x in range(stride): line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x-bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x-bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x-bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        out.extend(line)
        prev = line
    return w, h, bpp, out


def box_blur(rgb, w, h, radius, passes=3):
    bpp = 3
    data = bytearray(rgb)
    for _ in range(passes):
        tmp = bytearray(len(data))
        for y in range(h):
            base = y * w * bpp
            for c in range(3):
                acc = 0
                count = 0
                # simple sliding window
                for x in range(-radius, w + radius):
                    if 0 <= x - radius < w:
                        acc -= data[base + (x - radius) * bpp + c]
                        count -= 1
                    if x < w:
                        acc += data[base + x * bpp + c]
                        count += 1
                    if 0 <= x < w and count > 0:
                        tmp[base + x * bpp + c] = acc // count
        data = tmp
        tmp = bytearray(len(data))
        for x in range(w):
            for c in range(3):
                acc = 0
                count = 0
                for y in range(-radius, h + radius):
                    if 0 <= y - radius < h:
                        acc -= data[((y - radius) * w + x) * bpp + c]
                        count -= 1
                    if y < h:
                        acc += data[(y * w + x) * bpp + c]
                        count += 1
                    if 0 <= y < h and count > 0:
                        tmp[(y * w + x) * bpp + c] = acc // count
        data = tmp
    return data


def write_png(path, w, h, rgb):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw.extend(rgb[y*w*3:(y+1)*w*3])
    def chunk(t, p):
        return struct.pack(">I", len(p)) + t + p + struct.pack(">I", zlib.crc32(t+p) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def crop_darken(src, w, sw, bpp, y0, height, factor=2.4):
    out = bytearray()
    for y in range(y0, y0 + height):
        for x in range(w):
            p = (y * w + x) * bpp
            out.extend((min(255, int(src[p] * factor)),
                        min(255, int(src[p+1] * factor)),
                        min(255, int(src[p+2] * factor))))
    return out


def main():
    w, h, bpp, rgb = read_png(SRC)
    # Top strip: ratio for a 54 px bar on 800 px screen.
    top_h = max(48, int(h * 54 / 800))
    top = crop_darken(rgb, w, 0, bpp, 0, top_h)
    top = box_blur(top, w, top_h, 14)
    write_png(OUTDIR + "/glass-top.png", w, top_h, top)

    # Bottom strip for the dock.
    bottom_h = max(80, int(h * 120 / 800))
    bottom = crop_darken(rgb, w, 0, bpp, h - bottom_h, bottom_h)
    bottom = box_blur(bottom, w, bottom_h, 16)
    write_png(OUTDIR + "/glass-bottom.png", w, bottom_h, bottom)

    print("wrote", OUTDIR + "/glass-top.png", w, top_h)
    print("wrote", OUTDIR + "/glass-bottom.png", w, bottom_h)


if __name__ == "__main__":
    main()
