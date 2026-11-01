#!/usr/bin/env python3
"""Analyse Quick Views spike exports (no third-party packages needed).

Finds the coloured markers in every exported PNG and compares their pixel
positions with the prediction of the Quick Views frame model:

  native     image keeps the vertical extent of the viewport:
             scale = H / vp_h, image centre = viewport centre
  inscribed  image equals the largest rectangle with the image aspect that
             fits centred into the viewport (what the overlay draws)
"""
import json
import struct
import sys
import zlib
from pathlib import Path

OUT = Path(__file__).parent / "out"


def read_png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, w, h, ctype = 8, b"", 0, 0, 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and interlace == 0 and ctype in (2, 6), (depth, ctype, interlace)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    i = 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def classify(r, g, b):
    m = max(r, g, b)
    if m < 100:
        return None
    hi, lo = 0.6 * m, 0.35 * m
    if r > hi and b > hi and g < lo:
        return "magenta"
    if g > hi and b > hi and r < lo:
        return "cyan"
    if r > hi and g > hi and b < lo:
        return "yellow"
    return None


def find_markers(path):
    w, h, bpp, rows = read_png(path)
    acc = {}
    for y, line in enumerate(rows):
        for x in range(w):
            o = x * bpp
            name = classify(line[o], line[o + 1], line[o + 2])
            if name:
                s = acc.setdefault(name, [0, 0.0, 0.0])
                s[0] += 1
                s[1] += x + 0.5
                s[2] += y + 0.5
    return (w, h), {k: (v[1] / v[0], v[2] / v[0]) for k, v in acc.items() if v[0] > 20}


def predict(case, name):
    W, H = case["size"]
    vw, vh = case["vp"]
    x, y = case["markers_vp"][name]
    if case["hypothesis"] == "native":
        s = H / vh
        return W / 2 + (x - vw / 2) * s, H / 2 + (y - vh / 2) * s
    # inscribed frame
    a_img, a_vp = W / H, vw / vh
    fw, fh = (vw, vw / a_img) if a_img > a_vp else (vh * a_img, vh)
    s = W / fw
    return W / 2 + (x - vw / 2) * s, H / 2 + (y - vh / 2) * s


def main():
    res = json.loads((OUT / "results.json").read_text())
    print(f"SketchUp {res['sketchup']}  viewport {res['vp']}  ui_scale {res['ui_scale']}")
    worst = 0.0
    for case in res["cases"]:
        size, found = find_markers(OUT / case["file"])
        errs = []
        for name in case["markers_vp"]:
            if name not in found:
                errs.append(f"{name}: not in image")
                continue
            px, py = predict(case, name)
            fx, fy = found[name]
            d = ((px - fx) ** 2 + (py - fy) ** 2) ** 0.5
            worst = max(worst, d) if case["hypothesis"] != "native" or case["aspect_ratio"] == 0 else worst
            errs.append(f"{name}: found ({fx:7.1f},{fy:7.1f}) predicted ({px:7.1f},{py:7.1f}) err {d:5.1f}px")
        print(f"\n{case['id']}  {size[0]}x{size[1]}  hyp={case['hypothesis']} fov_is_height={case['fov_is_height']}")
        for e in errs:
            print("   ", e)
    print(f"\nworst error (native + inscribed, aspect_ratio 0): {worst:.1f}px")
    return 0 if worst < 3 else 1


if __name__ == "__main__":
    sys.exit(main())
