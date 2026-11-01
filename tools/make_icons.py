#!/usr/bin/env python3
"""Generates the toolbar icons as SVG (Windows) and PDF (macOS) from one
shape list. Run: python3 tools/make_icons.py"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "jg_quickviews" / "icons"
SIZE = 24
INK = (0.0, 0.0, 0.0)
ACCENT = (0.0, 0.0, 0.0)  # schwarz-weiß
SHADE = (0.0, 0.0, 0.0, 0.3)

# Shapes in a 24x24 box, y pointing down.
#  ("rect", x, y, w, h, stroke_rgb or None, fill_rgba or None, line_width)
#  ("line", [(x, y), ...], stroke_rgb, line_width)
ICONS = {
    # stack of images = several scenes, arrow = export
    "export": [
        ("rect", 6.5, 3.5, 14, 10, INK, None, 1.5),
        ("rect", 3.5, 6.5, 14, 10, INK, (1, 1, 1, 1), 1.5),
        ("line", [(5.5, 14.5), (9.5, 10.5), (12, 13), (13.5, 11.5), (15.5, 14.5)], INK, 1.2),
        ("line", [(10.5, 18.5), (10.5, 22.5)], ACCENT, 1.8),
        ("line", [(8, 20.2), (10.5, 22.7), (13, 20.2)], ACCENT, 1.8),
    ],
    # viewport with shaded border and the export frame
    "frame": [
        ("rect", 2.5, 4.5, 19, 15, INK, None, 1.2),
        ("rect", 3.1, 5.1, 3.4, 13.8, None, SHADE, 0),
        ("rect", 17.5, 5.1, 3.4, 13.8, None, SHADE, 0),
        ("rect", 6.5, 5.5, 11, 13, ACCENT, None, 1.8),
    ],
}


def svg(shapes):
    def rgb(c):
        return "#%02x%02x%02x" % tuple(round(v * 255) for v in c[:3])

    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">']
    for s in shapes:
        if s[0] == "rect":
            _, x, y, w, h, stroke, fill, lw = s
            f = f'fill="{rgb(fill)}" fill-opacity="{fill[3]}"' if fill else 'fill="none"'
            st = f'stroke="{rgb(stroke)}" stroke-width="{lw}"' if stroke else ''
            parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="1" {f} {st}/>')
        else:
            _, pts, stroke, lw = s
            p = " ".join(f"{x},{y}" for x, y in pts)
            parts.append(f'<polyline points="{p}" fill="none" stroke="{rgb(stroke)}" stroke-width="{lw}" '
                         'stroke-linecap="round" stroke-linejoin="round"/>')
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def pdf(shapes):
    ops = ["1 J 1 j"]
    gstates = {}
    for s in shapes:
        if s[0] == "rect":
            _, x, y, w, h, stroke, fill, lw = s
            py = SIZE - y - h
            if fill:
                name = f"GS{len(gstates)}"
                gstates[name] = fill[3]
                ops.append(f"q /{name} gs {fill[0]} {fill[1]} {fill[2]} rg {x} {py} {w} {h} re f Q")
            if stroke:
                ops.append(f"{stroke[0]} {stroke[1]} {stroke[2]} RG {lw} w {x} {py} {w} {h} re S")
        else:
            _, pts, stroke, lw = s
            path = " ".join(f"{x} {SIZE - y} {'m' if i == 0 else 'l'}" for i, (x, y) in enumerate(pts))
            ops.append(f"{stroke[0]} {stroke[1]} {stroke[2]} RG {lw} w {path} S")
    content = "\n".join(ops).encode()
    gs = " ".join(f"/{n} << /Type /ExtGState /ca {a} /CA {a} >>" for n, a in gstates.items())
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {SIZE} {SIZE}] "
         f"/Resources << /ExtGState << {gs} >> >> /Contents 4 0 R >>").encode(),
        b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, body in enumerate(objs, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for o in offsets:
        out += b"%010d 00000 n \n" % o
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    return bytes(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, shapes in ICONS.items():
        (OUT / f"{name}.svg").write_text(svg(shapes))
        (OUT / f"{name}.pdf").write_bytes(pdf(shapes))
        print("wrote", name)


if __name__ == "__main__":
    main()
