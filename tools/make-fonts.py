#!/usr/bin/env python3
"""Build the app fonts from the OFL originals in tools/fonts-src/:
- draw Neon Casino's currency sign, a 'credit chip' (hexagon with a bar through top and bottom),
  into the ¤ (U+00A4) slot, sized from the font's cap height and digit width;
- rename the families (the Share Tech Mono licence reserves the name 'Share' for unmodified
  fonts): Chakra Petch Bold -> Neon Display, Share Tech Mono -> Neon Mono.
Needs fontTools:  python3 tools/make-fonts.py
"""
import math, os, shutil
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

SRC = os.path.join(os.path.dirname(__file__), "fonts-src")
OUT = os.path.join(os.path.dirname(__file__), "..", "qml", "fonts")

def hexagon(cx, cy, r, clockwise):
    pts = [(cx + r * math.cos(math.radians(90 - 60 * i)), cy + r * math.sin(math.radians(90 - 60 * i))) for i in range(6)]
    return pts if clockwise else pts[::-1]          # y-up: going 90, 30, -30 … is clockwise

def chip(font):
    cmap = font.getBestCmap()
    glyf, hmtx = font["glyf"], font["hmtx"]
    zero = cmap[ord("0")]
    adv = hmtx[zero][0]
    os2 = font["OS/2"]
    cap = getattr(os2, "sCapHeight", 0) or int(font["head"].unitsPerEm * 0.7)
    cx, cy = adv / 2, cap / 2
    r = min(cap * 0.40, adv * 0.42)
    t = cap * 0.12                                   # stroke
    pen = TTGlyphPen(None)
    def poly(points):
        pen.moveTo(tuple(map(round, points[0])))
        for p in points[1:]: pen.lineTo(tuple(map(round, p)))
        pen.closePath()
    poly(hexagon(cx, cy, r, True))                   # outer
    poly(hexagon(cx, cy, r - t * 1.15, False))       # the hole
    bw, ext = t * 0.95, cap * 0.16                   # bars poking out top and bottom, like $
    for y0, y1 in ((cy + r - t, cy + r + ext), (cy - r - ext, cy - r + t)):
        poly([(cx - bw / 2, y0), (cx - bw / 2, y1), (cx + bw / 2, y1), (cx + bw / 2, y0)])
    name = cmap.get(0xA4) or "currency"
    glyf[name] = pen.glyph()
    glyf[name].recalcBounds(glyf)
    hmtx[name] = (adv, glyf[name].xMin)
    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap[0xA4] = name
    return name

def rename(font, family):
    for rec in font["name"].names:
        if rec.nameID in (1, 16):
            rec.string = family
        elif rec.nameID == 4:
            rec.string = family + (" Bold" if "Bold" in str(rec) else "")
        elif rec.nameID == 6:
            rec.string = family.replace(" ", "") + ("-Bold" if "Bold" in str(rec) else "-Regular")
        elif rec.nameID == 3:
            rec.string = "NeonCasino:" + family

for src, dst, family in (("ChakraPetch-Bold.ttf", "NeonDisplay.ttf", "Neon Display"),
                         ("ShareTechMono-Regular.ttf", "NeonMono.ttf", "Neon Mono")):
    f = TTFont(os.path.join(SRC, src))
    chip(f)
    rename(f, family)
    f.save(os.path.join(OUT, dst))
    print("wrote", dst)
for lic in ("OFL-ChakraPetch.txt", "OFL-ShareTechMono.txt"):
    shutil.copy(os.path.join(SRC, lic), os.path.join(OUT, lic))
