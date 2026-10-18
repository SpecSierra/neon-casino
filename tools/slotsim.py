#!/usr/bin/env python3
"""Slot machines: definitions, exact RTP, tuning, and the generated qml/js/SlotThemes.js.

    python3 tools/slotsim.py            # report RTP of every machine
    python3 tools/slotsim.py --tune     # rescale paytables to TARGET and write SlotThemes.js
    python3 tools/slotsim.py --mc N     # Monte-Carlo cross-check (N spins per machine)

RTP is computed exactly: cells are independent draws from the reel weights, so one line's
expected pay is a sum over every symbol triple, and the bonus (free spins, multiplier
ladder, retriggers) is a small dynamic program. The 5000x-style max-win cap is ignored
(it only matters in the far tail), so the figure is a hair optimistic.
"""
import itertools, json, random, sys

TARGET = 0.95
LINES = [(1, 1, 1), (0, 0, 0), (2, 2, 2), (0, 1, 2), (2, 1, 0), (0, 1, 0), (2, 1, 2), (1, 0, 1), (1, 2, 1)]

# Regular symbols are listed low → high. `low2` pays when its symbol fills the first two
# cells of a line. `top` is the symbol the Lucky Seven / Neon Jackpot perks act on.
THEMES = [
    {
        "id": "classic", "name": "NEON SLOTS", "tagline": "The original. Free-spin multipliers climb a ladder to ×100.", "music": "slots",
        "color": "#FF2BD6", "unlock": 0, "volatility": 3, "prefix": "sym-",
        "symbols": ["chip", "cherry", "bar", "bolt", "diamond", "seven"],
        "weights": {"chip": 30, "cherry": 24, "bar": 16, "bolt": 11, "diamond": 7, "seven": 3},
        "pay3": {"chip": 8, "cherry": 12, "bar": 25, "bolt": 60, "diamond": 150, "seven": 700, "wild": 1000},
        "low2": {"symbol": "cherry", "pay": 2}, "top": "seven", "fixed": True,
        "feature": {"type": "ladder",
                    "text": "LADDER: each free spin rolls its own multiplier; retriggers climb the ladder."},
        "bonus": {"scatter": 6, "bonusScatter": 12, "spins": 8, "retrigger": 5, "scatterPay": 2,
                  "ladders": [[2, 3, 5, 10], [3, 5, 10, 25], [5, 10, 25, 50], [10, 25, 50, 100]],
                  "ladderWeights": [50, 30, 15, 5], "maxWin": 5000},
    },
    {
        "id": "hacker", "name": "HACKER GRID", "tagline": "Low risk. OVERFLOW: centre-line wins stack up to ×5 on your next spin.", "music": "hacker",
        "color": "#39FF88", "unlock": 1500, "volatility": 1, "prefix": "sym-hacker-",
        "symbols": ["bit", "brace", "tag", "hash", "dollar", "skull"],
        "weights": {"bit": 40, "brace": 28, "tag": 14, "hash": 8, "dollar": 5, "skull": 3},
        "pay3": {"bit": 5, "brace": 10, "tag": 16, "hash": 30, "dollar": 70, "skull": 230, "wild": 370},
        "low2": {"symbol": "bit", "pay": 1}, "top": "skull",
        "feature": {"type": "combo", "max": 5,
                    "text": "OVERFLOW: every centre-line win stacks the multiplier (up to ×5) for your next spin; a miss resets it."},
        "bonus": {"scatter": 8, "bonusScatter": 14, "spins": 12, "retrigger": 6, "scatterPay": 1,
                  "ladders": [[1, 2, 3, 5], [2, 3, 5, 8], [3, 5, 8, 12], [5, 8, 12, 20]],
                  "ladderWeights": [45, 30, 17, 8], "maxWin": 2000},
    },
    {
        "id": "tokyo", "name": "NEO TOKYO", "tagline": "High risk. In free spins the multiplier stacks and never drops.", "music": "tokyo",
        "color": "#FF3355", "unlock": 6000, "volatility": 5, "prefix": "sym-tokyo-",
        "symbols": ["yen", "sakura", "fortune", "oni", "samurai", "dragon"],
        "weights": {"yen": 26, "sakura": 24, "fortune": 18, "oni": 12, "samurai": 6, "dragon": 2},
        "pay3": {"yen": 5, "sakura": 9, "fortune": 30, "oni": 70, "samurai": 260, "dragon": 1700, "wild": 3100},
        "low2": {"symbol": "sakura", "pay": 2}, "top": "dragon", "fixed": True,
        "feature": {"type": "stack", "increments": [1, 2, 3, 5], "weights": [50, 30, 15, 5],
                    "text": "STACKING SPIRIT: in free spins the multiplier never drops; every spin adds +1, +2, +3 or +5 to it."},
        "bonus": {"scatter": 5, "bonusScatter": 10, "spins": 6, "retrigger": 4, "scatterPay": 3,
                  "ladders": [[3, 5, 10, 25], [5, 10, 25, 50], [10, 25, 50, 100], [25, 50, 100, 200]],
                  "ladderWeights": [55, 28, 12, 5], "maxWin": 10000},
    },
    {
        "id": "sunset", "name": "SUNSET DRIVE", "tagline": "Suns fill the fuel gauge; five of them fire a ×5 TURBO spin.", "music": "sunset",
        "color": "#FF9F14", "unlock": 20000, "volatility": 4, "prefix": "sym-sunset-",
        "symbols": ["note", "palm", "cassette", "eighty", "heart", "sun"],
        "weights": {"note": 28, "palm": 24, "cassette": 16, "eighty": 11, "heart": 7, "sun": 3},
        "pay3": {"note": 5, "palm": 9, "cassette": 20, "eighty": 50, "heart": 140, "sun": 920, "wild": 1550},
        "low2": {"symbol": "palm", "pay": 2}, "top": "sun",
        "feature": {"type": "turbo", "symbol": "sun", "fuel": 5, "mult": 5,
                    "text": "TURBO: every spin showing a sun adds fuel; at 5 fuel your next spin is a TURBO spin paying ×5."},
        "bonus": {"scatter": 6, "bonusScatter": 12, "spins": 10, "retrigger": 5, "scatterPay": 2,
                  "ladders": [[2, 3, 5, 15], [3, 5, 15, 30], [5, 15, 30, 75], [15, 30, 75, 150]],
                  "ladderWeights": [50, 30, 15, 5], "maxWin": 7500},
    },
]

# ------------------------------------------------------------------ exact maths
def probs(t, bonus=False, wild=False):
    w = dict(t["weights"])
    w["scatter"] = t["bonus"]["bonusScatter" if bonus else "scatter"]
    if wild:
        w["wild"] = 1
    tot = sum(w.values())
    return {k: v / tot for k, v in w.items()}

def line_pay(t, a, b, c, perks=()):
    s2 = t["low2"]["symbol"]
    low2 = (a == s2 and b in (s2, "wild")) or (a == "wild" and b == s2)
    if "scatter" in (a, b, c):
        return t["low2"]["pay"] if low2 else 0
    base = [s for s in (a, b, c) if s != "wild"]
    if not base:
        return t["pay3"]["wild"]
    if all(s == base[0] for s in base):
        m = t["pay3"][base[0]]
        if base[0] == t["top"]:
            if "jackpot" in perks: m *= 3
            if "lucky7" in perks: m *= 2
        return m
    return t["low2"]["pay"] if low2 else 0

def line_rtp(t, bonus=False, wild=False, perks=()):
    p = probs(t, bonus, wild)
    return sum(p[a] * p[b] * p[c] * line_pay(t, a, b, c, perks) for a, b, c in itertools.product(p, repeat=3))

def p_scatter_all_reels(t, bonus=False, wild=False):
    ps = probs(t, bonus, wild)["scatter"]
    return (1 - (1 - ps) ** 3) ** 3

def line_hit(t, bonus=False):
    p = probs(t, bonus)
    return sum(p[a] * p[b] * p[c] for a, b, c in itertools.product(p, repeat=3) if line_pay(t, a, b, c) > 0)

def base_mult(t):
    """Average multiplier the machine's base-game feature applies to line wins."""
    f = t.get("feature", {})
    if f.get("type") == "combo":
        h = line_hit(t)                      # centre line pays
        n = f["max"]; pi = [1.0 / n] * n
        for _ in range(500):                 # stationary distribution of the combo level
            nxt = [0.0] * n
            for k in range(n):
                nxt[min(k + 1, n - 1)] += pi[k] * h
                nxt[0] += pi[k] * (1 - h)
            pi = nxt
        return sum(pi[k] * (k + 1) for k in range(n))
    if f.get("type") == "turbo":
        p = probs(t)[f["symbol"]]
        ps = 1 - (1 - p) ** 9                # a sun anywhere in the window
        # states: fuel 0..fuel-1, then one turbo spin; expected spins per cycle
        cycle = f["fuel"] / ps + 1
        frac = 1 / cycle
        return 1 + (f["mult"] - 1) * frac
    return 1.0

def mean_mult(t, level, perks=()):
    lad = t["bonus"]["ladders"][min(level, len(t["bonus"]["ladders"]) - 1)]
    f = 2 if "overdrive" in perks else 1
    return sum(v * w for v, w in zip(lad, t["bonus"]["ladderWeights"])) / 100 * f

def bonus_ev(t, wild=False, perks=()):
    """Expected bonus winnings in units of the total bet (excluding the trigger's own pay)."""
    b = t["bonus"]
    f = t.get("feature", {})
    if f.get("type") == "stack":
        lr = line_rtp(t, True, wild, perks)
        q = p_scatter_all_reels(t, True, wild)
        ed = sum(v * w for v, w in zip(f["increments"], f["weights"])) / sum(f["weights"])
        if "overdrive" in perks: ed *= 2
        S, I = 200, 400
        nxt = [0.0] * (S + 1)                # E(s, i+1) for every s
        for i in range(I - 1, -1, -1):
            cur = [0.0] * (S + 1)
            M = 1 + (i + 1) * ed
            for s_ in range(1, S + 1):
                cur[s_] = lr * M + q * (b["scatterPay"] + nxt[min(s_ - 1 + b["retrigger"], S)]) + (1 - q) * nxt[s_ - 1]
            nxt = cur
        return nxt[b["spins"]]
    lr = line_rtp(t, True, wild, perks)
    q = p_scatter_all_reels(t, True, wild)
    top = len(b["ladders"]) - 1
    S = 400
    E = [[0.0] * (top + 1) for _ in range(S + 1)]
    for s in range(1, S + 1):
        for L in range(top, -1, -1):
            nxt = min(s - 1 + b["retrigger"], S)
            E[s][L] = lr * mean_mult(t, L, perks) + q * (b["scatterPay"] + E[nxt][min(L + 1, top)]) + (1 - q) * E[s - 1][L]
    # E[s] for s>=nxt uses values filled later in the loop for larger s: iterate to converge
    for _ in range(30):
        for s in range(1, S + 1):
            for L in range(top, -1, -1):
                nxt = min(s - 1 + b["retrigger"], S)
                E[s][L] = lr * mean_mult(t, L, perks) + q * (b["scatterPay"] + E[nxt][min(L + 1, top)]) + (1 - q) * E[s - 1][L]
    return E[b["spins"]][0]

def rtp(t, wild=False, perks=()):
    base = line_rtp(t, False, wild, perks) * base_mult(t)
    pt = p_scatter_all_reels(t, False, wild)
    return base + pt * (t["bonus"]["scatterPay"] + bonus_ev(t, wild, perks)), base, pt

def buy_price(t):
    """Bonus-buy price in units of the total bet, so a bought bonus also returns ~TARGET."""
    ev = t["bonus"]["scatterPay"] + bonus_ev(t)
    return max(10, int(round(ev / TARGET)))

def nice(v):
    if v < 20: return max(1, round(v))
    if v < 100: return int(round(v / 5) * 5)
    if v < 1000: return int(round(v / 10) * 10)
    return int(round(v / 50) * 50)

def tune(t):
    if t.get("fixed") or abs(rtp(t)[0] - TARGET) < 0.015:
        return                       # already tuned: keep the paytable stable
    for _ in range(12):
        r, _, _ = rtp(t)
        if abs(r - TARGET) < 0.004: break
        k = TARGET / r
        t["pay3"] = {s: nice(v * k) for s, v in t["pay3"].items()}

def report():
    for t in THEMES:
        r, base, pt = rtp(t)
        bp = buy_price(t)
        print("%-12s RTP %.4f  lines %.3f  bonus 1/%-4.0f  bonus EV %6.1fx  hit freq/line %.3f  buy %dx (RTP %.3f)" % (
            t["id"], r, base, 1 / pt, bonus_ev(t), hit_freq(t), bp, (t["bonus"]["scatterPay"] + bonus_ev(t)) / bp))
        for perk in ("lucky7", "jackpot", "overdrive"):
            print("    +%-9s %.4f" % (perk, rtp(t, perks=(perk,))[0]))
        print("    +wild      %.4f" % rtp(t, wild=True)[0])

def hit_freq(t):
    p = probs(t)
    return sum(p[a] * p[b] * p[c] for a, b, c in itertools.product(p, repeat=3) if line_pay(t, a, b, c) > 0)

# ------------------------------------------------------------------ Monte Carlo check
def mc(t, n, nl=5):
    pool = [s for s, w in probs(t).items() for _ in range(int(round(w * 1000)))]
    bpool = [s for s, w in probs(t, True).items() for _ in range(int(round(w * 1000)))]
    b = t["bonus"]; tot = 0.0
    def spin(pool):
        g = [[random.choice(pool) for _ in range(3)] for _ in range(3)]
        m = sum(line_pay(t, g[0][x], g[1][y], g[2][z]) for x, y, z in LINES[:nl]) / nl
        return m, all("scatter" in r for r in g)
    for _ in range(n):
        m, s = spin(pool)
        tot += m
        if s:
            won = b["scatterPay"]; left = b["spins"]; L = 0
            while left and won < b["maxWin"]:
                left -= 1
                fm, fs = spin(bpool)
                lad = b["ladders"][min(L, 3)]
                won += fm * random.choices(lad, b["ladderWeights"])[0]
                if fs: left += b["retrigger"]; L += 1; won += b["scatterPay"]
            tot += min(won, b["maxWin"])
    return tot / n

# ------------------------------------------------------------------ JS export
def write_js():
    out = [".pragma library", "// Generated by tools/slotsim.py --tune. Edit the machines there, not here.", ""]
    for t in THEMES:
        t["bonus"]["buy"] = buy_price(t)
    out.append("var themes = " + json.dumps([{k: v for k, v in t.items() if k != "fixed"} for t in THEMES], indent=1) + "")
    out.append("")
    out.append("function byId(id) { for (var i = 0; i < themes.length; ++i) if (themes[i].id === id) return themes[i]; return themes[0] }")
    with open("qml/js/SlotThemes.js", "w") as f:
        f.write("\n".join(out) + "\n")

if __name__ == "__main__":
    if "--tune" in sys.argv:
        for t in THEMES:
            tune(t)
        write_js()
        for t in THEMES:
            print(t["id"], json.dumps(t["pay3"]))
    if "--mc" in sys.argv:
        n = int(sys.argv[sys.argv.index("--mc") + 1])
        random.seed(3)
        for t in THEMES:
            print("%-12s MC RTP %.4f" % (t["id"], mc(t, n)))
    report()
