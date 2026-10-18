#!/usr/bin/env python3
"""ABYSS: a fruit machine with HOLDs and NUDGES. Exact RTP under best play, tuning, and the
generated qml/js/AbyssConfig.js.

    python3 tools/abysssim.py           # report
    python3 tools/abysssim.py --tune    # rescale the paytable to TARGET and write AbyssConfig.js

Three reels, each a fixed strip of 20 stops; only the centre line pays (three of a kind, wild
substitutes; 2-3 pearls anywhere; a shell on reel 1 returns the bet, two from the left pay 2×). Every spin draws one
feature, decided with the spin:
  nudge (n)  if the spin doesn't win, you get n nudges: each steps one reel down one stop
  hold       if the spin doesn't win, the NEXT spin lets you hold up to two reels
Held spins never carry a feature. Best play: nudge to the best reachable line; hold the reels
whose average next-spin pay is highest. RTP = (r_N + q·E_H) / (1 + q), where r_N is a normal
spin's return, q the chance a normal spin hands you a hold, E_H a held spin's return.
"""
import itertools, json, random, sys
import numpy as np

TARGET = 0.95
N = 20
SYMS = ["shell", "fish", "jelly", "anchor", "shark", "kraken", "wild", "pearl"]
COUNTS = [  # per reel, stops of each symbol (sum 20)
    {"shell": 5, "fish": 4, "jelly": 3, "anchor": 3, "shark": 2, "kraken": 1, "wild": 1, "pearl": 1},
    {"shell": 5, "fish": 4, "jelly": 3, "anchor": 2, "shark": 2, "kraken": 1, "wild": 1, "pearl": 2},
    {"shell": 5, "fish": 4, "jelly": 3, "anchor": 3, "shark": 2, "kraken": 1, "wild": 1, "pearl": 1},
]
PAY3 = {"shell": 3, "fish": 4, "jelly": 7, "anchor": 12, "shark": 30, "kraken": 130, "wild": 250}
PEARLS = {2: 3, 3: 45}
SHELL1, SHELL2 = 1, 2            # a shell on reel 1 / two from the left (when nothing else pays)
NUDGE = {"p": 0.07, "n": [1, 2], "w": [80, 20]}
HOLD_P = 0.07

def strips():
    rnd = random.Random(7)
    out = []
    for c in COUNTS:
        s = [k for k in SYMS for _ in range(c[k])]
        # spread: no symbol twice in a row where avoidable
        for _ in range(2000):
            rnd.shuffle(s)
            if all(s[i] != s[(i + 1) % N] for i in range(N)): break
        out.append(s)
    return out
STRIPS = strips()

def line_pay(a, b, c, pay3=None):
    pay3 = pay3 or PAY3
    syms = (a, b, c)
    pearls = syms.count("pearl")
    p = PEARLS.get(pearls, 0)
    if pearls == 0:
        base = [s for s in syms if s != "wild"]
        if not base: p = pay3["wild"]
        elif all(s == base[0] for s in base): p = pay3[base[0]]
    if not p and a == "shell":           # the "cherry" rule: shells from the left
        p = SHELL2 if b in ("shell", "wild") else SHELL1
    return p

def tables(pay3):
    pay = np.zeros((N, N, N))
    for i, j, k in itertools.product(range(N), repeat=3):
        pay[i, j, k] = line_pay(STRIPS[0][i], STRIPS[1][j], STRIPS[2][k], pay3)
    # best pay reachable with up to n nudges (each moves one reel's stop +1)
    best = {0: pay}
    for n in (1, 2, 3):
        b = best[n - 1].copy()
        for ax in range(3):
            b = np.maximum(b, np.roll(best[n - 1], -1, axis=ax))
        best[n] = b
    return pay, best

def rtp(pay3=None, verbose=False):
    pay, best = tables(pay3 or PAY3)
    win = pay > 0
    wsum = sum(NUDGE["w"])
    nudge_val = sum(w / wsum * best[n] for n, w in zip(NUDGE["n"], NUDGE["w"]))
    # normal spin: feature nudge (p), hold (HOLD_P), none
    r_nudge = np.where(win, pay, nudge_val).mean()
    r_plain = pay.mean()
    r_N = NUDGE["p"] * r_nudge + (1 - NUDGE["p"]) * r_plain
    # held spin value from losing positions: best of hold none / one reel / two reels
    h0 = pay.mean()
    h1 = [pay.mean(axis=(1, 2))[:, None, None], pay.mean(axis=(0, 2))[None, :, None], pay.mean(axis=(0, 1))[None, None, :]]
    h2 = [pay.mean(axis=2)[:, :, None], pay.mean(axis=1)[:, None, :], pay.mean(axis=0)[None, :, :]]
    bh = np.full(pay.shape, h0)
    for h in h1 + h2: bh = np.maximum(bh, np.broadcast_to(h, pay.shape))
    lose = ~win
    q = HOLD_P * lose.mean()
    E_H = bh[lose].mean()
    r = (r_N + q * E_H) / (1 + q)
    if verbose:
        print("normal spin %.4f  (plain %.4f, with nudges %.4f)  hold offered %.3f of spins  held spin %.4f" % (r_N, r_plain, r_nudge, q, E_H))
        print("line hit %.3f   RTP (best play) %.4f   RTP (never hold/nudge) %.4f" % (win.mean(), r, r_plain))
    return r

def nice(v):
    if v < 20: return max(1, round(v))
    if v < 100: return int(round(v / 5) * 5)
    return int(round(v / 10) * 10)

def tune():
    global PAY3, PEARLS
    for _ in range(12):
        r = rtp()
        if abs(r - TARGET) < 0.004: break
        k = TARGET / r
        PAY3 = {s: nice(v * k) for s, v in PAY3.items()}
        PEARLS = {n: nice(v * k) for n, v in PEARLS.items()}

def write_js():
    cfg = {"strips": STRIPS, "pay3": PAY3, "shell1": SHELL1, "shell2": SHELL2, "pearls": {str(k): v for k, v in PEARLS.items()}, "nudge": NUDGE, "holdP": HOLD_P,
           "id": "abyss", "type": "abyss", "name": "ABYSS", "color": "#1FA8FF", "unlock": 40000, "volatility": 4, "prefix": "sym-abyss-",
           "tagline": "A fruit machine from the deep: HOLD reels, NUDGE them into line. Your calls decide the pay.",
           "symbols": ["shell", "fish", "jelly", "anchor", "shark", "kraken"], "music": "abyss"}
    with open("qml/js/AbyssConfig.js", "w") as f:
        f.write(".pragma library\n// Generated by tools/abysssim.py --tune. Edit the machine there, not here.\nvar machine = "
                + json.dumps(cfg, indent=1) + "\n")

if __name__ == "__main__":
    if "--tune" in sys.argv:
        tune(); write_js()
        print("pay3", PAY3, "pearls", PEARLS)
    rtp(verbose=True)
