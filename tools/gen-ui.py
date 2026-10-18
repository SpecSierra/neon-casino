#!/usr/bin/env python3
"""UI chrome for the 'cut steel' look: 9-patch panel frames, glows and buttons in every accent
color, plus a hazard-stripe tile. Run from the repo root; writes qml/images/ui/."""
from PIL import Image, ImageDraw, ImageFilter

OUT = "qml/images/ui/"
COLORS = {"cyan": (0, 240, 255), "pink": (255, 43, 214), "yellow": (248, 255, 58), "green": (57, 255, 136),
          "red": (255, 51, 85), "violet": (160, 90, 255), "orange": (255, 159, 20), "gold": (255, 200, 40),
          "white": (235, 235, 255), "grey": (130, 130, 160)}
# Drawn at 2x: QML scales by Theme.pixelRatio / 2 so lines stay crisp on every density.
X = 2
S = 4            # supersample
N = 96 * X       # 9-patch size; borders are 28 * X px
C = 18 * X       # corner cut
INK = (8, 5, 20)

def poly_cut(w, h, c, cuts=("tl", "br")):
    pts = []
    pts += [(c, 0)] if "tl" in cuts else [(0, 0)]
    pts += [(w - c, 0), (w, c)] if "tr" in cuts else [(w, 0)]
    pts += [(w, h - c), (w - c, h)] if "br" in cuts else [(w, h)]
    pts += [(c, h), (0, h - c)] if "bl" in cuts else [(0, h)]
    if "tl" in cuts:
        pts += [(0, c)]
    return pts

def scaled(pts, k=S, off=0):
    return [((x + off) * k, (y + off) * k) for x, y in pts]

def frame(rgb, fill_alpha):
    im = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    outer = poly_cut(N - 1, N - 1, C)
    d.polygon(scaled(outer), fill=INK + (int(255 * fill_alpha),))
    d.line(scaled(outer + [outer[0]]), fill=rgb + (235,), width=2 * X * S)
    # inner hairline, inset 5, only along the top and left edges
    d.line([((9 * X + C // 2) * S, 5 * X * S), ((N - 22 * X) * S, 5 * X * S)], fill=rgb + (110,), width=X * S)
    d.line([(5 * X * S, (C + 9 * X) * S), (5 * X * S, (N - 26 * X) * S)], fill=rgb + (110,), width=X * S)
    # tab on the top edge, tick marks at the bottom right
    d.rectangle(((C + 4 * X) * S, 0, (C + 26 * X) * S, 4 * X * S), fill=rgb + (255,))
    for i in range(3):
        x = N - (34 - i * 6) * X
        d.line([(x * S, (N - 4 * X) * S), ((x + 3 * X) * S, (N - 9 * X) * S)], fill=rgb + (200,), width=X * S)
    return im.resize((N, N), Image.LANCZOS)

def glow(rgb):
    P = 24 * X
    im = Image.new("RGBA", ((N + 2 * P) * S // 2, (N + 2 * P) * S // 2), (0, 0, 0, 0))
    m = Image.new("L", im.size, 0); d = ImageDraw.Draw(m)
    outer = poly_cut(N - 1, N - 1, C)
    d.line(scaled(outer + [outer[0]], k=S // 2, off=P), fill=255, width=6 * X * S // 2)
    m = m.filter(ImageFilter.GaussianBlur(8 * X * S // 2))
    im = Image.new("RGBA", im.size, rgb + (0,)); im.putalpha(m)
    return im.resize((N + 2 * P, N + 2 * P), Image.LANCZOS)

def button(rgb, solid):
    B = 64 * X; c = 12 * X
    im = Image.new("RGBA", (B * S, B * S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    pts = poly_cut(B - 1, B - 1, c, cuts=("tr", "bl"))
    if solid:
        d.polygon(scaled(pts), fill=rgb + (245,))
        d.line([(4 * X * S, (B - 5 * X) * S), ((B - 20 * X) * S, (B - 5 * X) * S)], fill=INK + (90,), width=X * S)   # a groove
    else:
        d.polygon(scaled(pts), fill=rgb + (28,))
        d.line(scaled(pts + [pts[0]]), fill=rgb + (230,), width=2 * X * S)
    return im.resize((B, B), Image.LANCZOS)

def hazard(rgb):
    T = 24 * X
    im = Image.new("RGBA", (T * S, T * S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for k in range(-2, 3):
        x0 = k * T * S
        d.polygon([(x0, T * S), (x0 + T * S // 2, 0), (x0 + T * S, 0), (x0 + T * S // 2, T * S)], fill=rgb + (230,))
    return im.resize((T, T), Image.LANCZOS)

if __name__ == "__main__":
    for name, rgb in COLORS.items():
        frame(rgb, 0.62).save(OUT + "frame-%s.png" % name)
        frame(rgb, 0.86).save(OUT + "frame-%s-strong.png" % name)
        glow(rgb).save(OUT + "glow-%s.png" % name)
        button(rgb, True).save(OUT + "btn-%s-solid.png" % name)
        button(rgb, False).save(OUT + "btn-%s-line.png" % name)
    hazard(COLORS["yellow"]).save(OUT + "hazard-yellow.png")
    hazard(COLORS["pink"]).save(OUT + "hazard-pink.png")
