#!/usr/bin/env python3
"""Render the neon PNG art (slot symbols, suits, textures, icons). Run from the repo root."""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

CYAN = (0, 240, 255); PINK = (255, 43, 214); YELLOW = (248, 255, 58)
GREEN = (57, 255, 136); RED = (255, 51, 85); VIOLET = (160, 90, 255); WHITE = (255, 255, 255)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
IMG = "qml/images/"
S = 4  # supersampling

def neon(mask, color, glow=10, core=True):
    """mask: L image. Returns RGBA with coloured glow, coloured body and a white-hot core."""
    w, h = mask.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for radius, alpha in ((glow * 2, 0.55), (glow, 0.8)):
        g = mask.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * alpha * 1.6)))
        layer = Image.new("RGBA", (w, h), color + (0,)); layer.putalpha(g)
        out = Image.alpha_composite(out, layer)
    body = Image.new("RGBA", (w, h), color + (0,)); body.putalpha(mask)
    out = Image.alpha_composite(out, body)
    if core:
        inner = mask.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(3))
        hot = Image.new("RGBA", (w, h), (255, 255, 255, 0)); hot.putalpha(inner.point(lambda v: int(v * 0.55)))
        out = Image.alpha_composite(out, hot)
    return out

def canvas(n=128):
    m = Image.new("L", (n * S, n * S), 0)
    return m, ImageDraw.Draw(m)

def finish(mask, color, n=128, glow=6):
    m = mask.resize((n, n), Image.LANCZOS)
    return neon(m, color, glow)

def text_mask(txt, size, n=128, font=BOLD, dy=0):
    m, d = canvas(n)
    f = ImageFont.truetype(font, size * S)
    bb = d.textbbox((0, 0), txt, font=f)
    x = (n * S - (bb[2] - bb[0])) / 2 - bb[0]; y = (n * S - (bb[3] - bb[1])) / 2 - bb[1] + dy * S
    d.text((x, y), txt, font=f, fill=255)
    return m

def poly(points, n=128, width=0):
    m, d = canvas(n)
    pts = [(x * S, y * S) for x, y in points]
    if width: d.line(pts + [pts[0]], fill=255, width=width * S, joint="curve")
    else: d.polygon(pts, fill=255)
    return m

def sym_chip():
    m, d = canvas()
    c = 64 * S
    d.ellipse((c - 46 * S, c - 46 * S, c + 46 * S, c + 46 * S), outline=255, width=9 * S)
    d.ellipse((c - 26 * S, c - 26 * S, c + 26 * S, c + 26 * S), outline=255, width=5 * S)
    for i in range(8):
        a = i * math.pi / 4
        x, y = c + math.cos(a) * 46 * S, c + math.sin(a) * 46 * S
        d.ellipse((x - 7 * S, y - 7 * S, x + 7 * S, y + 7 * S), fill=0)
    return finish(m, GREEN)

def sym_cherry():
    m, d = canvas()
    for cx, cy in ((44, 86), (86, 92)):
        d.ellipse(((cx - 19) * S, (cy - 19) * S, (cx + 19) * S, (cy + 19) * S), fill=255)
    d.line([(44 * S, 68 * S), (70 * S, 22 * S), (86 * S, 74 * S)], fill=255, width=6 * S, joint="curve")
    d.line([(70 * S, 22 * S), (98 * S, 18 * S)], fill=255, width=8 * S)
    return finish(m, PINK)

def sym_bar():
    m = text_mask("BAR", 44)
    _, d = None, ImageDraw.Draw(m)
    d.rectangle((14 * S, 30 * S, 114 * S, 36 * S), fill=255); d.rectangle((14 * S, 92 * S, 114 * S, 98 * S), fill=255)
    return finish(m, YELLOW)

def sym_bolt():
    return finish(poly([(74, 10), (30, 72), (60, 72), (48, 118), (98, 50), (66, 50), (82, 10)]), CYAN)

def sym_diamond():
    m = poly([(64, 12), (112, 54), (64, 118), (16, 54)])
    d = ImageDraw.Draw(m)
    for seg in ([(16, 54), (112, 54)], [(42, 30), (64, 54), (86, 30)], [(64, 54), (64, 118)]):
        d.line([(x * S, y * S) for x, y in seg], fill=0, width=3 * S)
    return finish(m, VIOLET)

def sym_seven(): return finish(text_mask("7", 112, dy=2), RED)
def sym_wild():
    m = text_mask("W", 70, dy=-6)
    d = ImageDraw.Draw(m); f = ImageFont.truetype(BOLD, 20 * S)
    bb = d.textbbox((0, 0), "WILD", font=f); d.text(((128 * S - bb[2]) / 2, 96 * S), "WILD", font=f, fill=255)
    return finish(m, WHITE)

ORANGE = (255, 160, 20)
def sym_scatter():
    """Cyber-eye scatter: almond eye, iris ring, pupil, 'BONUS' underneath."""
    m, d = canvas()
    eye = [(10 + i, 50 - 30 * math.sin(math.pi * i / 108)) for i in range(0, 109, 4)]
    eye += [(118 - i, 50 + 30 * math.sin(math.pi * i / 108)) for i in range(0, 109, 4)]
    d.line([(x * S, y * S) for x, y in eye] + [(eye[0][0] * S, eye[0][1] * S)], fill=255, width=7 * S, joint="curve")
    d.ellipse((44 * S, 30 * S, 84 * S, 70 * S), outline=255, width=6 * S)
    d.ellipse((57 * S, 43 * S, 71 * S, 57 * S), fill=255)
    f = ImageFont.truetype(BOLD, 22 * S)
    bb = d.textbbox((0, 0), "BONUS", font=f); d.text(((128 * S - bb[2]) / 2, 90 * S), "BONUS", font=f, fill=255)
    return finish(m, ORANGE)

def suit(ch, color):
    return finish(text_mask(ch, 84, n=96, font=SANS, dy=4), color, n=96, glow=4)

def spark():
    n = 32; im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            r = math.hypot(x - n / 2 + .5, y - n / 2 + .5) / (n / 2)
            a = max(0.0, 1 - r) ** 2
            im.putpixel((x, y), (255, 255, 255, int(255 * a)))
    return im

def hex_tile():
    """Tileable hex mesh, white lines on transparent: tinted/opacity'd in QML."""
    r = 12; w = int(round(math.sqrt(3) * r * 2)); h = r * 3
    big = Image.new("L", (w * S, h * S), 0); d = ImageDraw.Draw(big)
    def hexagon(cx, cy):
        pts = [((cx + r * math.cos(math.pi / 6 + i * math.pi / 3)) * S, (cy + r * math.sin(math.pi / 6 + i * math.pi / 3)) * S) for i in range(6)]
        d.line(pts + [pts[0]], fill=255, width=S)
    hw = math.sqrt(3) * r
    for cy, off in ((0, 0), (1.5 * r, hw / 2), (3 * r, 0)):
        for i in range(-1, 4): hexagon(off + i * hw, cy)
    m = big.resize((w, h), Image.LANCZOS)
    im = Image.new("RGBA", (w, h), (255, 255, 255, 0)); im.putalpha(m); return im

def scan_tile():
    im = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    for x in range(4): im.putpixel((x, 0), (0, 0, 0, 255)); im.putpixel((x, 1), (0, 0, 0, 110))
    return im

def sfos_shape(N, r):
    """Sailfish launcher shape: three large rounded corners, sharp bottom-right."""
    m = Image.new("L", (N, N), 0); d = ImageDraw.Draw(m)
    # a full circle (radius = half the size, so the top and left edges have no flat run),
    # with only the bottom-right quarter squared off, like the stock launcher icons
    d.ellipse((0, 0, N - 1, N - 1), fill=255)
    d.rectangle((N // 2, N // 2, N - 1, N - 1), fill=255)
    return m

def icon(n):
    N = 512 * 2
    # flat vertical gradient magenta → violet, like the stock icons' bright fills
    grad = Image.new("RGBA", (N, N))
    gd = ImageDraw.Draw(grad)
    top, bot = (255, 60, 190), (110, 40, 230)
    for y in range(N):
        t = y / (N - 1)
        gd.line([(0, y), (N, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    # faint synthwave grid in the lower third
    g = Image.new("RGBA", (N, N), (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    hz = int(N * 0.66)
    for i in range(7):
        y = hz + int((N - hz) * (i / 6) ** 1.8)
        d.line([(0, y), (N, y)], fill=(255, 255, 255, 60), width=6)
    for i in range(-8, 9):
        d.line([(N / 2, hz), (N / 2 + i * N / 6, N)], fill=(255, 255, 255, 60), width=6)
    grad = Image.alpha_composite(grad, g)
    # glyph: bold white 7 with a cyan glitch offset and a soft drop shadow
    f = ImageFont.truetype(BOLD, int(N * 0.78))
    def glyph(dx, dy, fill):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0)); dd = ImageDraw.Draw(im)
        bb = dd.textbbox((0, 0), "7", font=f)
        x = (N - (bb[2] - bb[0])) / 2 - bb[0] + dx; y = (N - (bb[3] - bb[1])) / 2 - bb[1] - N * 0.03 + dy
        dd.text((x, y), "7", font=f, fill=fill)
        return im
    shadow = glyph(0, N * 0.025, (40, 0, 80, 110)).filter(ImageFilter.GaussianBlur(N * 0.02))
    grad = Image.alpha_composite(grad, shadow)
    grad = Image.alpha_composite(grad, glyph(-N * 0.025, 0, (0, 240, 255, 230)))
    white = glyph(0, 0, (255, 255, 255, 255))
    # two glitch slices: shift bands of the white glyph sideways
    for y0, h, dx in ((0.30, 0.05, 0.04), (0.52, 0.03, -0.03)):
        band = white.crop((0, int(N * y0), N, int(N * (y0 + h))))
        white.paste((0, 0, 0, 0), (0, int(N * y0), N, int(N * (y0 + h))))
        white.alpha_composite(band, (int(N * dx), int(N * y0)))
    grad = Image.alpha_composite(grad, white)
    grad.putalpha(ImageChops.multiply(grad.getchannel("A"), sfos_shape(N, int(N * 0.42))))
    return grad.resize((n, n), Image.LANCZOS)

# ---------------------------------------------------------------- themed machines
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
CJK = "/opt/sfos-sysroot/usr/share/fonts/wqy-zenhei/wqy-zenhei.ttc"
GOLD = (255, 200, 40)

def label_under(mask, word, size=20):
    d = ImageDraw.Draw(mask); f = ImageFont.truetype(BOLD, size * S)
    bb = d.textbbox((0, 0), word, font=f); d.text(((128 * S - bb[2]) / 2, 96 * S), word, font=f, fill=255)
    return mask

def glyph(txt, size, font, dy=0, color=CYAN, word=None):
    m = text_mask(txt, size, font=font, dy=dy)
    if word: label_under(m, word)
    return finish(m, color)

def palm():
    m, d = canvas()
    # trunk: gentle S-curve, segmented
    trunk = [(58 + 10 * math.sin(u * 2.2), 120 - 78 * u) for u in [i / 20 for i in range(21)]]
    d.line([(x * S, y * S) for x, y in trunk], fill=255, width=8 * S, joint="curve")
    for x, y in trunk[2:-2:3]:
        d.line([((x - 6) * S, y * S), ((x + 6) * S, (y - 3) * S)], fill=0, width=2 * S)
    tx, ty = trunk[-1]
    def bez(p0, p1, p2, n=24):
        return [((1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * p1[0] + u * u * p2[0],
                 (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * p1[1] + u * u * p2[1]) for u in [k / n for k in range(n + 1)]]
    for dx, dy in ((-52, 14), (-44, 34), (-24, -26), (52, 12), (44, 32), (22, -28)):
        ctrl = (tx + dx * 0.45, ty - 26)
        pts = bez((tx, ty), ctrl, (tx + dx, ty + dy))
        for k in range(len(pts) - 1):        # taper
            w = int((7 - 5 * k / len(pts)) * S)
            d.line([(pts[k][0] * S, pts[k][1] * S), (pts[k + 1][0] * S, pts[k + 1][1] * S)], fill=255, width=w)
    return finish(m, GREEN)

def cassette():
    m, d = canvas()
    d.rounded_rectangle((12 * S, 28 * S, 116 * S, 100 * S), radius=8 * S, outline=255, width=7 * S)
    d.rounded_rectangle((30 * S, 42 * S, 98 * S, 70 * S), radius=10 * S, outline=255, width=5 * S)
    for cx in (48, 80):
        d.ellipse(((cx - 8) * S, 48 * S, (cx + 8) * S, 64 * S), outline=255, width=4 * S)
    d.polygon([(34 * S, 100 * S), (42 * S, 84 * S), (86 * S, 84 * S), (94 * S, 100 * S)], outline=255, width=5 * S)
    return finish(m, CYAN)

def sun():
    m, d = canvas()
    d.pieslice((14 * S, 22 * S, 114 * S, 122 * S), 180, 360, fill=255)
    for i, y in enumerate((52, 62, 70, 77)):
        d.rectangle((10 * S, y * S, 118 * S, (y + 3 + i) * S), fill=0)
    d.rectangle((10 * S, 72 * S, 118 * S, 128 * S), fill=0)
    m2 = Image.new("L", m.size, 0); ImageDraw.Draw(m2).line([(8 * S, 90 * S), (120 * S, 90 * S)], fill=255, width=4 * S)
    hor = finish(m2, PINK)
    top = finish(m, (255, 180, 40))
    return Image.alpha_composite(top, hor)

THEME_ART = {
    "hacker": {
        "bit": lambda: glyph("01", 64, MONO, color=GREEN),
        "brace": lambda: glyph("{}", 76, MONO, color=CYAN),
        "tag": lambda: glyph("</>", 50, MONO, color=(120, 255, 120)),
        "hash": lambda: glyph("#!", 64, MONO, color=YELLOW),
        "dollar": lambda: glyph("$", 92, MONO, color=GOLD),
        "skull": lambda: glyph("\u2620", 100, SANS, dy=4, color=RED),
        "wild": lambda: glyph("ROOT", 36, MONO, dy=-8, color=WHITE, word="WILD"),
        "scatter": lambda: glyph("0DAY", 36, MONO, dy=-8, color=ORANGE, word="BONUS"),
    },
    "tokyo": {
        "yen": lambda: glyph("\u5186", 84, CJK, color=GOLD),
        "sakura": lambda: glyph("\u685c", 84, CJK, color=PINK),
        "fortune": lambda: glyph("\u798f", 84, CJK, color=ORANGE),
        "oni": lambda: glyph("\u9b3c", 84, CJK, color=RED),
        "samurai": lambda: glyph("\u4f8d", 84, CJK, color=CYAN),
        "dragon": lambda: glyph("\u9f8d", 88, CJK, color=VIOLET),
        "wild": lambda: glyph("\u795e", 66, CJK, dy=-10, color=WHITE, word="WILD"),
        "scatter": lambda: glyph("\u732b", 66, CJK, dy=-10, color=ORANGE, word="BONUS"),
    },
    "sunset": {
        "note": lambda: glyph("\u266a", 96, SANS, dy=2, color=VIOLET),
        "palm": palm,
        "cassette": cassette,
        "eighty": lambda: glyph("88", 74, BOLD, color=CYAN),
        "heart": lambda: glyph("\u2665", 96, SANS, dy=4, color=PINK),
        "sun": sun,
        "wild": lambda: glyph("TURBO", 30, BOLD, dy=-8, color=WHITE, word="WILD"),
        "scatter": lambda: glyph("\u2605", 70, SANS, dy=-10, color=ORANGE, word="BONUS"),
    },
}


# ---------------------------------------------------------------- VOID RUNNER / PIXEL ARCADE / ABYSS
def planet_ring():
    m, d = canvas()
    d.ellipse((38 * S, 38 * S, 90 * S, 90 * S), fill=255)
    d.ellipse((8 * S, 52 * S, 120 * S, 78 * S), outline=255, width=6 * S)
    d.ellipse((40 * S, 40 * S, 88 * S, 64 * S), fill=255)     # re-cover the ring behind the top half
    return finish(m, (255, 180, 60))

def rocket():
    m, d = canvas()
    d.polygon([(64 * S, 6 * S), (86 * S, 40 * S), (86 * S, 92 * S), (42 * S, 92 * S), (42 * S, 40 * S)], fill=255)
    d.ellipse((54 * S, 36 * S, 74 * S, 56 * S), fill=0)
    d.polygon([(42 * S, 70 * S), (22 * S, 102 * S), (42 * S, 96 * S)], fill=255)
    d.polygon([(86 * S, 70 * S), (106 * S, 102 * S), (86 * S, 96 * S)], fill=255)
    d.polygon([(50 * S, 96 * S), (78 * S, 96 * S), (64 * S, 124 * S)], fill=255)
    return finish(m, CYAN)

def alien():
    m, d = canvas()
    d.ellipse((24 * S, 14 * S, 104 * S, 96 * S), fill=255)
    d.polygon([(40 * S, 80 * S), (88 * S, 80 * S), (64 * S, 118 * S)], fill=255)
    d.ellipse((36 * S, 44 * S, 60 * S, 66 * S), fill=0)
    d.ellipse((68 * S, 44 * S, 92 * S, 66 * S), fill=0)
    return finish(m, GREEN)

def portal():
    m, d = canvas()
    for i, r in enumerate((58, 44, 30, 16)):
        d.ellipse(((64 - r) * S, (64 - r) * S, (64 + r) * S, (64 + r) * S), outline=255, width=(6 - i) * S)
    d.ellipse((58 * S, 58 * S, 70 * S, 70 * S), fill=255)
    return finish(m, VIOLET, glow=9)

PIXELS = {   # 12x12 sprites for PIXEL ARCADE ('#' = lit)
    "coin": ["....####....", "..##....##..", ".#..####..#.", ".#.#....#.#.", "#.#..##..#.#", "#.#..##..#.#",
             "#.#..##..#.#", "#.#..##..#.#", ".#.#....#.#.", ".#..####..#.", "..##....##..", "....####...."],
    "mushroom": ["....####....", "..########..", ".###..###.#.", "####..######", "############", "#.########.#",
                 "............", "...######...", "...#.##.#...", "...######...", "...######...", "....####...."],
    "ghost": ["....####....", "..########..", ".##########.", ".#..###..##.", ".#..###..##.", "############",
              "############", "############", "############", "############", "##.###.###.#", "#...#...#..."],
    "invader": ["..#......#..", "...#....#...", "..########..", ".##.####.##.", "############", "#.########.#",
                "#.#......#.#", "...##..##...", "............", "............", "............", "............"],
    "joystick": ["....####....", "...######...", "...######...", "....####....", ".....##.....", ".....##.....",
                 ".....##.....", "..########..", ".##########.", "##.######.##", "############", ".##########."],
    "crown": ["............", "#....##....#", "##..####..##", "###.####.###", "############", "############",
              "##.##..##.##", "############", "############", "............", "############", "############"],
    "mystery": ["############", "#..........#", "#...####...#", "#..##..##..#", "#......##..#", "#.....##...#",
                "#....##....#", "#....##....#", "#..........#", "#....##....#", "#..........#", "############"],
}
def pixel(name, color):
    m, d = canvas()
    rows = PIXELS[name]; cell = 112 / 12
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                d.rectangle(((8 + x * cell) * S, (8 + y * cell) * S, (8 + (x + 1) * cell - 1) * S, (8 + (y + 1) * cell - 1) * S), fill=255)
    if name == "invader":             # centre the 8-row sprite
        m = ImageChops.offset(m, 0, int(2 * cell * S))
    return finish(m, color, glow=5)

def scallop():
    m, d = canvas()
    d.pieslice((10 * S, 18 * S, 118 * S, 126 * S), 200, 340, fill=255)
    d.polygon([(64 * S, 112 * S), (14 * S, 56 * S), (114 * S, 56 * S)], fill=255)
    for k in range(-3, 4):             # ribs
        ang = math.radians(270 + k * 18)
        d.line([(64 * S, 112 * S), ((64 + 58 * math.cos(ang)) * S, (72 + 58 * math.sin(ang)) * S)], fill=0, width=3 * S)
    d.rectangle((48 * S, 104 * S, 80 * S, 118 * S), fill=255)
    return finish(m, (255, 170, 200))

def comet():
    m, d = canvas()
    for k in range(7):
        w = (14 - k * 1.6) * S
        d.line([((40 + k * 10) * S, (88 - k * 10) * S), ((52 + k * 10) * S, (76 - k * 10) * S)], fill=255, width=int(w))
    for dx, dy in ((14, -2), (-2, 14)):
        d.line([((44 + dx) * S, (84 + dy) * S), ((112 + dx) * S, (16 + dy) * S)], fill=255, width=3 * S)
    d.ellipse((16 * S, 82 * S, 54 * S, 120 * S), fill=255)
    return finish(m, CYAN)

def fish():
    m, d = canvas()
    d.ellipse((16 * S, 36 * S, 92 * S, 92 * S), fill=255)
    d.polygon([(84 * S, 64 * S), (118 * S, 36 * S), (118 * S, 92 * S)], fill=255)
    d.ellipse((30 * S, 52 * S, 42 * S, 64 * S), fill=0)
    d.arc((44 * S, 44 * S, 84 * S, 84 * S), 300, 60, fill=0, width=3 * S)
    return finish(m, (255, 150, 40))

def jelly():
    m, d = canvas()
    d.pieslice((22 * S, 14 * S, 106 * S, 98 * S), 180, 360, fill=255)
    d.rectangle((22 * S, 54 * S, 106 * S, 62 * S), fill=255)
    for i, x in enumerate((32, 50, 68, 86, 98)):
        pts = [((x + 6 * math.sin(k / 3.0 + i)) * S, (62 + k * 5) * S) for k in range(12)]
        d.line(pts, fill=255, width=4 * S)
    return finish(m, PINK)

def shark():
    m, d = canvas()
    d.polygon([(6 * S, 70 * S), (40 * S, 50 * S), (58 * S, 18 * S), (70 * S, 48 * S), (104 * S, 54 * S), (124 * S, 34 * S),
               (116 * S, 70 * S), (124 * S, 104 * S), (102 * S, 84 * S), (60 * S, 92 * S), (30 * S, 88 * S)], fill=255)
    d.ellipse((24 * S, 60 * S, 32 * S, 68 * S), fill=0)
    for x in (40, 46, 52):
        d.line([(x * S, 64 * S), ((x - 3) * S, 76 * S)], fill=0, width=2 * S)
    return finish(m, (150, 200, 255))

def kraken():
    m, d = canvas()
    d.ellipse((34 * S, 6 * S, 94 * S, 66 * S), fill=255)
    d.ellipse((46 * S, 32 * S, 58 * S, 44 * S), fill=0); d.ellipse((70 * S, 32 * S, 82 * S, 44 * S), fill=0)
    for i in range(6):
        x0 = 40 + i * 9.6
        pts = [((x0 + (i - 2.5) * k * 1.6 + 6 * math.sin(k / 2.5 + i)) * S, (58 + k * 5) * S) for k in range(13)]
        for k in range(len(pts) - 1):
            d.line([pts[k], pts[k + 1]], fill=255, width=int((7 - k * 0.4) * S))
    return finish(m, VIOLET)

def trident():
    m, d = canvas()
    d.rectangle((60 * S, 34 * S, 68 * S, 92 * S), fill=255)
    for x in (34, 64, 94):
        d.polygon([(x * S, 6 * S), ((x - 9) * S, 26 * S), ((x + 9) * S, 26 * S)], fill=255)
        d.rectangle(((x - 3) * S, 24 * S, (x + 3) * S, 44 * S), fill=255)
    d.rectangle((31 * S, 40 * S, 97 * S, 47 * S), fill=255)
    f = ImageFont.truetype(BOLD, 20 * S); bb = d.textbbox((0, 0), "×2 WILD", font=f)
    d.text(((128 * S - bb[2]) / 2, 98 * S), "×2 WILD", font=f, fill=255)
    return finish(m, WHITE)

THEME_ART.update({
    "void": {
        "comet": comet,
        "moon": lambda: glyph("☾", 100, SANS, dy=2, color=YELLOW),
        "ring": planet_ring,
        "rocket": rocket,
        "alien": alien,
        "star": lambda: glyph("★", 104, SANS, dy=2, color=(255, 220, 90)),
        "portal": portal,
        "wild": lambda: glyph("∞", 80, SANS, dy=-12, color=WHITE, word="WILD"),
        "scatter": lambda: glyph("⚛", 70, SANS, dy=-10, color=ORANGE, word="BONUS"),
    },
    "arcade": {
        "coin": lambda: pixel("coin", YELLOW),
        "mushroom": lambda: pixel("mushroom", RED),
        "ghost": lambda: pixel("ghost", CYAN),
        "invader": lambda: pixel("invader", GREEN),
        "joystick": lambda: pixel("joystick", PINK),
        "crown": lambda: pixel("crown", (255, 200, 40)),
        "mystery": lambda: pixel("mystery", ORANGE),
        "wild": lambda: glyph("1UP", 46, MONO, dy=-10, color=WHITE, word="WILD"),
        "scatter": lambda: glyph("★", 66, SANS, dy=-10, color=ORANGE, word="BONUS"),
    },
    "abyss": {
        "shell": scallop,
        "fish": fish,
        "jelly": jelly,
        "anchor": lambda: glyph("⚓", 100, SANS, dy=2, color=CYAN),
        "shark": shark,
        "kraken": kraken,
        "wild": trident,
        "scatter": lambda: glyph("◉", 70, SANS, dy=-10, color=ORANGE, word="BONUS"),
    },
})

# ---------------------------------------------------------------- cascade gems + overload icon
def gem(shape, color):
    m, d = canvas()
    c = 64
    if shape == "hex":
        pts = [(c + 46 * math.cos(math.pi / 6 + i * math.pi / 3), c + 46 * math.sin(math.pi / 6 + i * math.pi / 3)) for i in range(6)]
    elif shape == "tri":
        pts = [(c, 16), (114, 106), (14, 106)]
    elif shape == "diamond":
        pts = [(c, 12), (112, c), (c, 116), (16, c)]
    elif shape == "star":
        pts = []
        for i in range(10):
            r = 50 if i % 2 == 0 else 22
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((c + r * math.cos(a), c + 4 + r * math.sin(a)))
    elif shape == "tridown":
        pts = [(14, 22), (114, 22), (c, 112)]
    elif shape == "cross":
        a, b = 40, 88
        pts = [(a, 14), (b, 14), (b, a), (114, a), (114, b), (b, b), (b, 114), (a, 114), (a, b), (14, b), (14, a), (a, a)]
    elif shape == "square":
        pts = [(22, 22), (106, 22), (106, 106), (22, 106)]
    else:  # circle
        d.ellipse((18 * S, 18 * S, 110 * S, 110 * S), fill=255)
        d.ellipse((40 * S, 40 * S, 88 * S, 88 * S), fill=0)
        d.ellipse((52 * S, 52 * S, 76 * S, 76 * S), fill=255)
        return finish(m, color)
    d.polygon([(x * S, y * S) for x, y in pts], fill=255)
    inner = [(c + (x - c) * 0.55, c + (y - c) * 0.55 + (4 if shape == "star" else 0)) for x, y in pts]
    d.polygon([(x * S, y * S) for x, y in inner], fill=0)
    inner2 = [(c + (x - c) * 0.3, c + (y - c) * 0.3 + (4 if shape == "star" else 0)) for x, y in pts]
    d.polygon([(x * S, y * S) for x, y in inner2], fill=255)
    return finish(m, color)

GEMS = [("hex", "ruby", RED), ("tri", "topaz", YELLOW), ("diamond", "sapphire", CYAN),
        ("circle", "emerald", GREEN), ("tridown", "solar", ORANGE), ("cross", "frost", WHITE),
        ("square", "amethyst", VIOLET), ("star", "nova", PINK)]

def overload_icon():
    m, d = canvas()
    pts = [(10, 108), (36, 92), (50, 100), (70, 66), (82, 76), (112, 20)]
    d.line([(x * S, y * S) for x, y in pts], fill=255, width=9 * S, joint="curve")
    d.polygon([(100 * S, 14 * S), (120 * S, 12 * S), (116 * S, 34 * S)], fill=255)
    return finish(m, YELLOW)

def petal():
    n = 48; m = Image.new("L", (n * S, n * S), 0); d = ImageDraw.Draw(m)
    d.ellipse((8 * S, 14 * S, 40 * S, 34 * S), fill=255)
    d.polygon([(36 * S, 20 * S), (46 * S, 16 * S), (40 * S, 26 * S)], fill=0)      # notch
    m = m.resize((n, n), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1))
    im = Image.new("RGBA", (n, n), (255, 160, 210, 0)); im.putalpha(m); return im

def keycard():
    m, d = canvas()
    d.rounded_rectangle((14 * S, 30 * S, 114 * S, 98 * S), radius=10 * S, outline=255, width=7 * S)
    d.rectangle((14 * S, 44 * S, 114 * S, 54 * S), fill=255)
    d.rounded_rectangle((26 * S, 64 * S, 50 * S, 86 * S), radius=3 * S, outline=255, width=4 * S)
    d.line([(62 * S, 70 * S), (102 * S, 70 * S)], fill=255, width=4 * S); d.line([(62 * S, 82 * S), (90 * S, 82 * S)], fill=255, width=4 * S)
    return finish(m, CYAN)

def laser():
    m, d = canvas()
    for y0 in (30, 64, 98):
        d.line([(10 * S, y0 * S), (118 * S, (y0 - 14) * S)], fill=255, width=5 * S)
    for x in (10, 118):
        d.ellipse(((x - 7) * S, 14 * S, (x + 7) * S, 110 * S), outline=255, width=4 * S)
    return finish(m, RED)

def mask():
    m, d = canvas()
    outline = [(8, 50), (20, 36), (46, 34), (64, 42), (82, 34), (108, 36), (120, 50),
               (114, 78), (92, 92), (72, 86), (64, 74), (56, 86), (36, 92), (14, 78)]
    d.polygon([(x * S, y * S) for x, y in outline], fill=255)
    d.polygon([(26 * S, 52 * S), (50 * S, 50 * S), (54 * S, 64 * S), (32 * S, 70 * S)], fill=0)
    d.polygon([(78 * S, 50 * S), (102 * S, 52 * S), (96 * S, 70 * S), (74 * S, 64 * S)], fill=0)
    d.line([(8 * S, 50 * S), (0, 40 * S)], fill=255, width=4 * S); d.line([(120 * S, 50 * S), (128 * S, 40 * S)], fill=255, width=4 * S)
    return finish(m, VIOLET)

def safe():
    m, d = canvas()
    d.rounded_rectangle((14 * S, 14 * S, 114 * S, 114 * S), radius=8 * S, outline=255, width=8 * S)
    d.ellipse((40 * S, 40 * S, 88 * S, 88 * S), outline=255, width=6 * S)
    for a in range(0, 360, 45):
        x, y = 64 + 30 * math.cos(math.radians(a)), 64 + 30 * math.sin(math.radians(a))
        d.ellipse(((x - 3) * S, (y - 3) * S, (x + 3) * S, (y + 3) * S), fill=255)
    d.line([(64 * S, 64 * S), (64 * S, 46 * S)], fill=255, width=5 * S)
    return finish(m, GREEN)

def gold():
    m, d = canvas()
    for (x, y) in ((18, 70), (66, 70), (42, 34)):
        d.polygon([((x + 8) * S, y * S), ((x + 36) * S, y * S), ((x + 44) * S, (y + 30) * S), (x * S, (y + 30) * S)], fill=255)
        d.polygon([((x + 12) * S, (y + 6) * S), ((x + 32) * S, (y + 6) * S), ((x + 36) * S, (y + 24) * S), ((x + 8) * S, (y + 24) * S)], fill=0)
    return finish(m, GOLD)

def vault():
    m, d = canvas()
    d.ellipse((10 * S, 10 * S, 118 * S, 118 * S), outline=255, width=8 * S)
    d.ellipse((30 * S, 30 * S, 98 * S, 98 * S), outline=255, width=5 * S)
    for a in range(0, 360, 60):
        x, y = 64 + 34 * math.cos(math.radians(a)), 64 + 34 * math.sin(math.radians(a))
        d.line([(64 * S, 64 * S), (x * S, y * S)], fill=255, width=6 * S)
    d.ellipse((54 * S, 54 * S, 74 * S, 74 * S), fill=255)
    return finish(m, PINK)

def datachip():
    m, d = canvas()
    d.rounded_rectangle((26 * S, 26 * S, 102 * S, 102 * S), radius=8 * S, outline=255, width=7 * S)
    for i in range(4):
        o = 36 + i * 18
        for (x0, y0, x1, y1) in ((o, 8, o, 26), (o, 102, o, 120), (8, o, 26, o), (102, o, 120, o)):
            d.line([(x0 * S, y0 * S), (x1 * S, y1 * S)], fill=255, width=5 * S)
    return finish(m, CYAN)

def core():
    m, d = canvas()
    for r, w in ((46, 6), (30, 5)):
        d.ellipse(((64 - r) * S, (52 - r) * S, (64 + r) * S, (52 + r) * S), outline=255, width=w * S)
    d.ellipse((52 * S, 40 * S, 76 * S, 64 * S), fill=255)
    label_under(m, "BONUS")
    return finish(m, ORANGE)

def crown():
    m, d = canvas()
    d.polygon([(14 * S, 96 * S), (20 * S, 34 * S), (44 * S, 66 * S), (64 * S, 24 * S), (84 * S, 66 * S), (108 * S, 34 * S), (114 * S, 96 * S)], fill=255)
    d.polygon([(26 * S, 86 * S), (30 * S, 54 * S), (46 * S, 76 * S), (64 * S, 44 * S), (82 * S, 76 * S), (98 * S, 54 * S), (102 * S, 86 * S)], fill=0)
    d.rectangle((14 * S, 100 * S, 114 * S, 110 * S), fill=255)
    for x, y in ((20, 30), (64, 20), (108, 30)):
        d.ellipse(((x - 6) * S, (y - 6) * S, (x + 6) * S, (y + 6) * S), fill=255)
    return finish(m, VIOLET)

def baccarat_icon():
    m, d = canvas()
    d.rounded_rectangle((16 * S, 22 * S, 76 * S, 108 * S), radius=8 * S, outline=255, width=5 * S)
    d.rounded_rectangle((52 * S, 14 * S, 112 * S, 100 * S), radius=8 * S, outline=255, width=6 * S)
    f = ImageFont.truetype(BOLD, 54 * S)
    d.text((66 * S, 26 * S), "9", font=f, fill=255)
    return finish(m, GOLD)

def dice_icon():
    m, d = canvas()
    for (x0, y0, ang, pips) in ((12, 40, 0, (2, 4, 6)), (62, 18, 0, (0, 4, 8))):
        d.rounded_rectangle((x0 * S, y0 * S, (x0 + 54) * S, (y0 + 54) * S), radius=10 * S, outline=255, width=6 * S)
        for k in pips:
            px, py = x0 + 13 + (k % 3) * 14, y0 + 13 + (k // 3) * 14
            d.ellipse(((px - 5) * S, (py - 5) * S, (px + 5) * S, (py + 5) * S), fill=255)
    return finish(m, GREEN)

def keno_icon():
    m, d = canvas()
    d.ellipse((14 * S, 14 * S, 114 * S, 114 * S), outline=255, width=7 * S)
    d.ellipse((34 * S, 34 * S, 94 * S, 94 * S), outline=255, width=4 * S)
    f = ImageFont.truetype(BOLD, 36 * S)
    bb = d.textbbox((0, 0), "80", font=f)
    d.text(((128 * S - (bb[2] - bb[0])) / 2 - bb[0], (128 * S - (bb[3] - bb[1])) / 2 - bb[1]), "80", font=f, fill=255)
    return finish(m, PINK)

def mine_icon():
    m, d = canvas()
    d.ellipse((30 * S, 34 * S, 98 * S, 102 * S), fill=255)
    d.ellipse((44 * S, 48 * S, 64 * S, 68 * S), fill=0)
    for a in range(0, 360, 45):
        x, y = 64 + 46 * math.cos(math.radians(a)), 68 + 46 * math.sin(math.radians(a))
        d.line([(64 * S, 68 * S), (x * S, y * S)], fill=255, width=7 * S)
    return finish(m, RED)

def plinko_icon():
    m, d = canvas()
    for r in range(5):
        for c in range(r + 1):
            x, y = 64 + (c - r / 2) * 20, 22 + r * 18
            d.ellipse(((x - 4) * S, (y - 4) * S, (x + 4) * S, (y + 4) * S), fill=255)
    d.ellipse((56 * S, 4 * S, 72 * S, 20 * S), outline=255, width=4 * S)
    for i in range(6):
        d.rectangle(((12 + i * 18) * S, 112 * S, (24 + i * 18) * S, 120 * S), fill=255)
    return finish(m, CYAN)

def sicbo_icon():
    m, d = canvas()
    for (x0, y0, pips) in ((10, 52, (4,)), (66, 52, (0, 4, 8)), (38, 10, (0, 2, 6, 8))):
        d.rounded_rectangle((x0 * S, y0 * S, (x0 + 50) * S, (y0 + 50) * S), radius=9 * S, outline=255, width=5 * S)
        for k in pips:
            px, py = x0 + 12 + (k % 3) * 13, y0 + 12 + (k // 3) * 13
            d.ellipse(((px - 4) * S, (py - 4) * S, (px + 4) * S, (py + 4) * S), fill=255)
    return finish(m, ORANGE)

def hilo_icon():
    m, d = canvas()
    d.rounded_rectangle((34 * S, 26 * S, 94 * S, 108 * S), radius=8 * S, outline=255, width=6 * S)
    d.polygon([(64 * S, 4 * S), (48 * S, 22 * S), (80 * S, 22 * S)], fill=255)
    d.polygon([(64 * S, 126 * S), (48 * S, 110 * S), (80 * S, 110 * S)], fill=255)
    f = ImageFont.truetype(BOLD, 34 * S)
    bb = d.textbbox((0, 0), "A", font=f); d.text(((128 * S - bb[2]) / 2, 46 * S), "A", font=f, fill=255)
    return finish(m, GREEN)

def wheel_icon():
    m, d = canvas()
    d.ellipse((10 * S, 14 * S, 118 * S, 122 * S), outline=255, width=7 * S)
    for a in range(0, 360, 30):
        x, y = 64 + 50 * math.cos(math.radians(a)), 68 + 50 * math.sin(math.radians(a))
        d.line([(64 * S, 68 * S), (x * S, y * S)], fill=255, width=4 * S)
    d.ellipse((54 * S, 58 * S, 74 * S, 78 * S), fill=255)
    d.polygon([(56 * S, 0), (72 * S, 0), (64 * S, 18 * S)], fill=255)
    return finish(m, YELLOW)

def scratch_icon():
    m, d = canvas()
    d.rounded_rectangle((12 * S, 28 * S, 116 * S, 100 * S), radius=8 * S, outline=255, width=6 * S)
    for i in range(3):
        d.rectangle(((24 + i * 30) * S, 44 * S, (46 + i * 30) * S, 84 * S), fill=255)
    d.line([(20 * S, 108 * S), (60 * S, 74 * S), (100 * S, 112 * S)], fill=0, width=10 * S)
    return finish(m, ORANGE)

def coinflip_icon():
    m, d = canvas()
    d.ellipse((14 * S, 14 * S, 114 * S, 114 * S), outline=255, width=7 * S)
    d.ellipse((28 * S, 28 * S, 100 * S, 100 * S), outline=255, width=3 * S)
    f = ImageFont.truetype(BOLD, 44 * S)
    bb = d.textbbox((0, 0), "2×", font=f); d.text(((128 * S - bb[2] - bb[0]) / 2, (128 * S - bb[3] - bb[1]) / 2), "2×", font=f, fill=255)
    return finish(m, YELLOW)

def dice_d20():
    m, d = canvas()
    pts = [(64 + 56 * math.cos(math.radians(90 + 60 * i)), 64 - 56 * math.sin(math.radians(90 + 60 * i))) for i in range(6)]
    d.polygon([(x * S, y * S) for x, y in pts], outline=255, width=6 * S)
    tri = [pts[0], pts[2], pts[4]]
    d.polygon([(x * S, y * S) for x, y in tri], outline=255, width=4 * S)
    for i in range(6):
        d.line([(pts[i][0] * S, pts[i][1] * S), (tri[(i + 1) // 2 % 3][0] * S, tri[(i + 1) // 2 % 3][1] * S)], fill=255, width=3 * S)
    return finish(m, CYAN)

def tower_icon():
    m, d = canvas()
    for i in range(5):
        y = 110 - i * 21
        w = 44 - i * 6
        d.rectangle(((64 - w) * S, (y - 15) * S, (64 + w) * S, y * S), outline=255, width=4 * S)
    d.polygon([(64 * S, 4 * S), (52 * S, 22 * S), (76 * S, 22 * S)], fill=255)
    return finish(m, VIOLET)

def rps_rock():
    return finish(poly([(30, 40), (58, 18), (96, 26), (114, 60), (102, 100), (60, 112), (22, 92), (14, 62)]), CYAN)

def rps_paper():
    m, d = canvas()
    d.polygon([(28 * S, 12 * S), (84 * S, 12 * S), (104 * S, 32 * S), (104 * S, 116 * S), (28 * S, 116 * S)], outline=255, width=7 * S)
    d.line([(84 * S, 12 * S), (84 * S, 32 * S), (104 * S, 32 * S)], fill=255, width=5 * S)
    for y in (50, 66, 82, 98):
        d.line([(42 * S, y * S), (90 * S, y * S)], fill=255, width=4 * S)
    return finish(m, YELLOW)

def race_icon():
    m, d = canvas()
    for i, y in enumerate((30, 64, 98)):
        x = 30 + i * 22
        d.line([(10 * S, y * S), (x * S, y * S)], fill=255, width=4 * S)
        d.polygon([((x + 4) * S, (y - 12) * S), ((x + 34) * S, y * S), ((x + 4) * S, (y + 12) * S)], fill=255)
    d.line([(116 * S, 10 * S), (116 * S, 118 * S)], fill=255, width=4 * S)
    return finish(m, GREEN)

def pearl():
    m, d = canvas()
    d.ellipse((26 * S, 26 * S, 102 * S, 102 * S), fill=255)
    d.ellipse((44 * S, 40 * S, 62 * S, 58 * S), fill=0)
    return finish(m, (230, 230, 255), glow=9)

def penalty_icon():
    m, d = canvas()
    d.rectangle((8 * S, 24 * S, 120 * S, 96 * S), outline=255, width=6 * S)
    for x in range(20, 120, 14): d.line([(x * S, 28 * S), (x * S, 94 * S)], fill=255, width=1 * S)
    for y in range(36, 96, 14): d.line([(12 * S, y * S), (116 * S, y * S)], fill=255, width=1 * S)
    d.ellipse((50 * S, 92 * S, 78 * S, 120 * S), fill=255)
    return finish(m, GREEN)

def reddog_icon():
    m, d = canvas()
    for i, x in enumerate((10, 46, 82)):
        d.rounded_rectangle((x * S, (30 - (i == 1) * 14) * S, (x + 36) * S, (98 - (i == 1) * 14) * S), radius=6 * S, outline=255, width=5 * S)
    f = ImageFont.truetype(BOLD, 26 * S)
    for x, t in ((18, "3"), (55, "?"), (90, "J")):
        d.text((x * S, (48 - (t == "?") * 14) * S), t, font=f, fill=255)
    return finish(m, RED)

def balloon_icon():
    m, d = canvas()
    d.ellipse((28 * S, 8 * S, 100 * S, 92 * S), fill=255)
    d.polygon([(58 * S, 90 * S), (70 * S, 90 * S), (64 * S, 100 * S)], fill=255)
    d.line([(64 * S, 100 * S), (58 * S, 112 * S), (68 * S, 124 * S)], fill=255, width=3 * S)
    d.ellipse((44 * S, 24 * S, 56 * S, 40 * S), fill=0)
    return finish(m, PINK)

def darts_icon():
    m, d = canvas()
    for r, w in ((56, 6), (40, 4), (24, 4)):
        d.ellipse(((64 - r) * S, (64 - r) * S, (64 + r) * S, (64 + r) * S), outline=255, width=w * S)
    d.ellipse((58 * S, 58 * S, 70 * S, 70 * S), fill=255)
    d.line([(64 * S, 64 * S), (112 * S, 16 * S)], fill=255, width=5 * S)
    d.polygon([(104 * S, 10 * S), (122 * S, 6 * S), (118 * S, 24 * S)], fill=255)
    return finish(m, CYAN)

def claw_icon():
    m, d = canvas()
    d.line([(64 * S, 0), (64 * S, 40 * S)], fill=255, width=5 * S)
    d.rectangle((50 * S, 40 * S, 78 * S, 52 * S), fill=255)
    d.line([(52 * S, 52 * S), (36 * S, 76 * S), (46 * S, 94 * S)], fill=255, width=6 * S, joint="curve")
    d.line([(76 * S, 52 * S), (92 * S, 76 * S), (82 * S, 94 * S)], fill=255, width=6 * S, joint="curve")
    d.ellipse((50 * S, 90 * S, 78 * S, 118 * S), outline=255, width=5 * S)
    return finish(m, YELLOW)

def chest_icon():
    m, d = canvas()
    d.rounded_rectangle((14 * S, 30 * S, 114 * S, 62 * S), radius=14 * S, outline=255, width=6 * S)
    d.rectangle((14 * S, 62 * S, 114 * S, 110 * S), outline=255, width=6 * S)
    d.rectangle((56 * S, 52 * S, 72 * S, 76 * S), fill=255)
    return finish(m, ORANGE)

def gen_themes():
    darts_icon().save(IMG + "sym-darts.png")
    claw_icon().save(IMG + "sym-claw.png")
    chest_icon().save(IMG + "sym-chest.png")
    penalty_icon().save(IMG + "sym-penalty.png")
    reddog_icon().save(IMG + "sym-reddog.png")
    balloon_icon().save(IMG + "sym-balloon.png")
    # coin flip faces: centred on the glyph's own bounding box (text_mask), so they sit dead
    # centre on the coin whatever the font's ascent/descent
    glyph("\u00a4", 104, "qml/fonts/NeonDisplay.ttf", color=YELLOW).save(IMG + "coin-heads.png")
    glyph("\u2620", 100, SANS, color=PINK).save(IMG + "coin-tails.png")
    pearl().save(IMG + "sym-abyss-pearl.png")
    race_icon().save(IMG + "sym-race.png")
    rps_rock().save(IMG + "rps-rock.png")
    rps_paper().save(IMG + "rps-paper.png")
    glyph("\u2702", 100, SANS, dy=2, color=PINK).save(IMG + "rps-scissors.png")
    glyph("\u2694", 92, SANS, dy=2, color=RED).save(IMG + "sym-war.png")
    glyph("\u270c", 92, SANS, dy=2, color=PINK).save(IMG + "sym-rps.png")
    coinflip_icon().save(IMG + "sym-coinflip.png")
    dice_d20().save(IMG + "sym-dice.png")
    tower_icon().save(IMG + "sym-tower.png")
    hilo_icon().save(IMG + "sym-hilo.png")
    wheel_icon().save(IMG + "sym-wheel.png")
    scratch_icon().save(IMG + "sym-scratch.png")
    mine_icon().save(IMG + "sym-mines.png")
    plinko_icon().save(IMG + "sym-plinko.png")
    sicbo_icon().save(IMG + "sym-sicbo.png")
    dice_icon().save(IMG + "sym-craps.png")
    keno_icon().save(IMG + "sym-keno.png")
    crown().save(IMG + "sym-poker.png")
    baccarat_icon().save(IMG + "sym-baccarat.png")
    ways = {"j": ("J", CYAN), "q": ("Q", GREEN), "k": ("K", VIOLET), "a": ("A", PINK), "sigma": ("\u03a3", YELLOW), "omega": ("\u03a9", RED)}
    for name, (ch, col) in ways.items():
        glyph(ch, 92, BOLD, color=col).save(IMG + "sym-ways-%s.png" % name)
    glyph("\u221e", 84, SANS, dy=-12, color=WHITE, word="WILD").save(IMG + "sym-ways-wild.png")
    glyph("\u03a8", 72, SANS, dy=-10, color=ORANGE, word="BONUS").save(IMG + "sym-ways-scatter.png")
    for name, fn in (("card", keycard), ("laser", laser), ("mask", mask), ("safe", safe), ("gold", gold), ("vault", vault), ("chip", datachip)):
        fn().save(IMG + "sym-heist-%s.png" % name)
    core().save(IMG + "gem-core.png")
    petal().save(IMG + "petal.png")
    for shape, name, color in GEMS:
        gem(shape, color).save(IMG + "gem-%s.png" % name)
    overload_icon().save(IMG + "sym-overload.png")
    for theme, art in THEME_ART.items():
        for name, fn in art.items():
            fn().save(IMG + "sym-%s-%s.png" % (theme, name))

if __name__ == "__main__":
    gen_themes()
    for name, fn in (("chip", sym_chip), ("cherry", sym_cherry), ("bar", sym_bar), ("bolt", sym_bolt),
                     ("diamond", sym_diamond), ("seven", sym_seven), ("wild", sym_wild), ("scatter", sym_scatter)):
        fn().save(IMG + "sym-%s.png" % name)
    for name, ch, col in (("spades", "♠", CYAN), ("hearts", "♥", PINK), ("diamonds", "♦", PINK), ("clubs", "♣", CYAN)):
        suit(ch, col).save(IMG + "suit-%s.png" % name)
    spark().save(IMG + "spark.png"); hex_tile().save(IMG + "hex.png"); scan_tile().save(IMG + "scan.png")
    for n in (86, 108, 128, 172):
        import os; os.makedirs("icons/%dx%d" % (n, n), exist_ok=True)
        icon(n).save("icons/%dx%d/harbour-neoncasino.png" % (n, n))
    import shutil; shutil.copy("icons/172x172/harbour-neoncasino.png", IMG + "app-icon.png")   # the About page
    icon(512).save("tools/icon-preview.png")
