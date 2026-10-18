#!/usr/bin/env python3
"""Monte-Carlo models for the non-line machines. Each mirrors a JS engine in qml/js/.

    python3 tools/machinesim.py MACHINE [spins]            # report
    python3 tools/machinesim.py MACHINE --tune [spins]     # rescale pays to TARGET, write qml/js/<Config>.js
    MACHINE = cascade | ways | heist

cascade (Cascade.js)  CHAIN REACTION: 5x5 connect-3. Base chains double the multiplier (x1, x2, x4 …
                      reset every spin). 3+ BONUS cores on the settled board start free spins where
                      the multiplier rises +1 per chain and never resets.
ways (Ways.js)        NEURAL WAYS: 6 reels, 2-7 rows each, pays left to right on adjacent reels,
                      ways = product of matches. 4+ scatters: free spins, +1 multiplier per win.
heist (Heist.js)      DATA HEIST: 5x3, 10 lines. 6+ data chips: chips lock, 3 respins, a new chip
                      resets them; a full board adds the GRAND.
"""
import json, random, sys

TARGET = 0.95

# ============================================================== CHAIN REACTION
CAS = {
    "id": "cascade", "type": "cascade", "name": "CHAIN REACTION",
    "tagline": "Connect 3+ gems. They explode, more fall, every chain doubles the multiplier.",
    "color": "#39FF88", "unlock": 3000, "volatility": 3, "music": "cascade", "prefix": "gem-",
    "cols": 5, "rows": 5,
    "gems": ["ruby", "topaz", "sapphire", "emerald", "solar", "frost", "amethyst", "nova"],
    "weights": {"ruby": 16, "topaz": 15, "sapphire": 14, "emerald": 13, "solar": 12, "frost": 11, "amethyst": 10, "nova": 9, "core": 1.1},
    "base": {"ruby": 0.07, "topaz": 0.084, "sapphire": 0.105, "emerald": 0.14, "solar": 0.175, "frost": 0.21, "amethyst": 0.279, "nova": 0.557},
    "size": {"3": 1, "4": 2.5, "5": 6, "6": 12, "7": 25, "8": 50, "9": 100, "10": 200},
    "multCap": 128, "maxWin": 5000,
    "bonus": {"cores": 3, "spins": 8, "extraPerCore": 2, "retrigger": 5},
}

def cas_draw(rng, m):
    keys = list(m["weights"]); w = [m["weights"][k] for k in keys]
    return rng.choices(keys, w)[0]

def cas_clusters(m, g):
    C, R = m["cols"], m["rows"]; seen = set(); out = []
    for c in range(C):
        for r in range(R):
            if (c, r) in seen or g[c][r] == "core":
                continue
            s = g[c][r]; st = [(c, r)]; cells = []; seen.add((c, r))
            while st:
                x, y = st.pop(); cells.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < C and 0 <= ny < R and (nx, ny) not in seen and g[nx][ny] == s:
                        seen.add((nx, ny)); st.append((nx, ny))
            if len(cells) >= 3:
                out.append((s, cells))
    return out

def cas_spin(rng, m, bonus_mult=None):
    """One drop. Base: chain k pays x2^k. Bonus: pays x bonus_mult, which rises +1 per chain.
    Returns (win in bets, cores on the settled board, new bonus_mult)."""
    C, R = m["cols"], m["rows"]
    g = [[cas_draw(rng, m) for _ in range(R)] for _ in range(C)]
    total = 0.0; k = 0
    while True:
        cl = cas_clusters(m, g)
        if not cl:
            break
        base = sum(m["base"][s] * m["size"][str(min(len(cells), 10))] for s, cells in cl)
        if bonus_mult is None:
            total += base * min(2 ** k, m["multCap"])
        else:
            total += base * bonus_mult; bonus_mult += 1
        gone = {cell for _, cells in cl for cell in cells}
        for c in range(C):
            keep = [g[c][r] for r in range(R) if (c, r) not in gone]
            g[c] = [cas_draw(rng, m) for _ in range(R - len(keep))] + keep
        k += 1
    cores = sum(col.count("core") for col in g)
    return total, cores, bonus_mult

def cas_bonus(rng, m, spins):
    b = m["bonus"]; won = 0.0; mult = 1
    while spins > 0 and won < m["maxWin"]:
        spins -= 1
        w, cores, mult = cas_spin(rng, m, mult)
        won += w
        if cores >= b["cores"]:
            spins += b["retrigger"]
    return min(won, m["maxWin"])

def cas_play(rng, m):
    w, cores, _ = cas_spin(rng, m)
    b = m["bonus"]
    if cores >= b["cores"]:
        w += cas_bonus(rng, m, b["spins"] + b["extraPerCore"] * (cores - b["cores"]))
        return min(w, m["maxWin"]), True
    return min(w, m["maxWin"]), False

def cas_scale(m, k):
    m["base"] = {s: round(v * k, 4) for s, v in m["base"].items()}

def cas_buy_ev(m, n, seed=5):
    rng = random.Random(seed)
    return sum(cas_bonus(rng, m, m["bonus"]["spins"]) for _ in range(n)) / n

# ============================================================== NEURAL WAYS
WAYS = {
    "id": "ways", "type": "ways", "name": "NEURAL WAYS",
    "tagline": "6 reels that change height every spin: up to 117,649 ways. Free-spin multiplier climbs with every win.",
    "color": "#00F0FF", "unlock": 8000, "volatility": 4, "music": "ways", "prefix": "sym-ways-",
    "reels": 6, "minRows": 2, "maxRows": 7,
    "symbols": ["j", "q", "k", "a", "sigma", "omega"],
    "weights": {"j": 22, "q": 21, "k": 19, "a": 17, "sigma": 11, "omega": 6, "wild": 3, "scatter": 2.6},
    "pay": {"j": [0.1, 0.2, 0.4, 0.8], "q": [0.1, 0.25, 0.5, 1], "k": [0.15, 0.3, 0.6, 1.2],
            "a": [0.2, 0.4, 0.8, 1.6], "sigma": [0.4, 1, 2, 4], "omega": [1, 2.5, 5, 10]},   # 3,4,5,6 reels
    "maxWin": 10000,
    "bonus": {"scatters": 4, "spins": 10, "extraPerScatter": 2, "retrigger": 5},
}

def ways_grid(rng, m):
    keys = list(m["weights"]); w = [m["weights"][k] for k in keys]
    grid = []
    for i in range(m["reels"]):
        h = rng.randint(m["minRows"], m["maxRows"])
        col = []
        for _ in range(h):
            s = rng.choices(keys, w)[0]
            if s == "wild" and (i == 0 or i == m["reels"] - 1):
                s = m["symbols"][0]               # wilds only on the middle reels
            col.append(s)
        grid.append(col)
    return grid

def ways_eval(m, grid):
    total = 0.0
    for s in m["symbols"]:
        ways = 1; n = 0
        for col in grid:
            c = sum(1 for x in col if x == s or x == "wild")
            if c == 0:
                break
            if n == 0 and col.count(s) == 0:
                break
            ways *= c; n += 1
        if n >= 3:
            total += m["pay"][s][n - 3] * ways
    scat = sum(col.count("scatter") for col in grid)
    return total, scat

def ways_bonus(rng, m, spins):
    b = m["bonus"]; won = 0.0; mult = 1
    while spins > 0 and won < m["maxWin"]:
        spins -= 1
        w, scat = ways_eval(m, ways_grid(rng, m))
        if w > 0:
            won += w * mult; mult += 1
        if scat >= b["scatters"]:
            spins += b["retrigger"]
    return min(won, m["maxWin"])

def ways_play(rng, m):
    w, scat = ways_eval(m, ways_grid(rng, m))
    b = m["bonus"]
    if scat >= b["scatters"]:
        w += ways_bonus(rng, m, b["spins"] + b["extraPerScatter"] * (scat - b["scatters"]))
        return min(w, m["maxWin"]), True
    return min(w, m["maxWin"]), False

def ways_scale(m, k):
    m["pay"] = {s: [round(v * k, 3) for v in vs] for s, vs in m["pay"].items()}

def ways_buy_ev(m, n, seed=5):
    rng = random.Random(seed)
    return sum(ways_bonus(rng, m, m["bonus"]["spins"]) for _ in range(n)) / n

# ============================================================== DATA HEIST
HEIST = {
    "id": "heist", "type": "heist", "name": "DATA HEIST",
    "tagline": "Land 6+ data chips to start a heist: chips lock, every new chip resets 3 respins. Fill the board for the GRAND.",
    "color": "#F8FF3A", "unlock": 12000, "volatility": 4, "music": "heist", "prefix": "sym-heist-",
    "reels": 5, "rows": 3,
    "symbols": ["card", "laser", "mask", "safe", "gold", "vault"],
    "weights": {"card": 20, "laser": 18, "mask": 15, "safe": 12, "gold": 8, "vault": 4, "chip": 11},
    "pay": {"card": [0.2, 0.5, 1.5], "laser": [0.3, 0.7, 2], "mask": [0.4, 1, 3], "safe": [0.6, 1.5, 5],
            "gold": [1, 3, 10], "vault": [2, 8, 40]},                     # 3,4,5 of a kind, x line bet
    "lines": [[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
              [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0]],
    "chipValues": [1, 2, 3, 5, 10, 25, 50, 150],              # x total bet; 25 MINI, 50 MINOR, 150 MAJOR
    "chipWeights": [30, 25, 18, 12, 8, 4, 2, 1],
    "trigger": 6, "respins": 3, "respinChance": 0.075, "grand": 1000, "maxWin": 10000,
}

def chip_value(rng, m):
    return rng.choices(m["chipValues"], m["chipWeights"])[0]

def heist_grid(rng, m):
    keys = list(m["weights"]); w = [m["weights"][k] for k in keys]
    return [[rng.choices(keys, w)[0] for _ in range(m["rows"])] for _ in range(m["reels"])]

def heist_lines(m, g):
    tot = 0.0
    for line in m["lines"]:
        s = g[0][line[0]]
        if s == "chip":
            continue
        n = 1
        while n < m["reels"] and g[n][line[n]] == s:
            n += 1
        if n >= 3:
            tot += m["pay"][s][n - 3] / len(m["lines"])
    return tot

def heist_feature(rng, m, chips):
    """chips: number already locked. Returns total in bets."""
    cells = m["reels"] * m["rows"]
    vals = [chip_value(rng, m) for _ in range(chips)]
    left = m["respins"]
    while left > 0 and len(vals) < cells:
        left -= 1
        new = sum(1 for _ in range(cells - len(vals)) if rng.random() < m["respinChance"])
        if new:
            vals += [chip_value(rng, m) for _ in range(new)]
            left = m["respins"]
    tot = sum(vals) + (m["grand"] if len(vals) >= cells else 0)
    return min(tot, m["maxWin"])

def heist_play(rng, m):
    g = heist_grid(rng, m)
    w = heist_lines(m, g)
    chips = sum(col.count("chip") for col in g)
    if chips >= m["trigger"]:
        w += heist_feature(rng, m, chips)
        return min(w, m["maxWin"]), True
    return w, False

def heist_scale(m, k):
    m["pay"] = {s: [round(v * k, 3) for v in vs] for s, vs in m["pay"].items()}
    m["chipValues"] = m["chipValues"]       # chips keep their face values

def heist_line_ev(m):
    """Exact expected line pay (in total bets): cells are independent draws."""
    W = sum(m["weights"].values())
    e = 0.0
    for sym in m["symbols"]:
        p = m["weights"][sym] / W
        pay = m["pay"][sym]
        e += p * (p ** 2 * (1 - p) * pay[0] + p ** 3 * (1 - p) * pay[1] + p ** 4 * pay[2])
    return e

def heist_feature_part(m, n, seed=3):
    """P(trigger) x feature EV, by Monte Carlo over the trigger spin's chip count."""
    rng = random.Random(seed); tot = 0.0
    for _ in range(n):
        g = heist_grid(rng, m)
        chips = sum(col.count("chip") for col in g)
        if chips >= m["trigger"]:
            tot += heist_feature(rng, m, chips)
    return tot / n

def heist_tune(m, n):
    f = heist_feature_part(m, n * 5)
    k = (TARGET - f) / heist_line_ev(m)
    heist_scale(m, k)
    print("heist: feature part %.4f, lines scaled x%.2f -> line part %.4f" % (f, k, heist_line_ev(m)))

def heist_buy_ev(m, n, seed=5):
    rng = random.Random(seed)
    return sum(heist_feature(rng, m, m["trigger"]) for _ in range(n)) / n

# ============================================================== driver
MACHINES = {
    "cascade": (CAS, cas_play, cas_scale, cas_buy_ev, "CascadeConfig.js"),
    "ways": (WAYS, ways_play, ways_scale, ways_buy_ev, "WaysConfig.js"),
    "heist": (HEIST, heist_play, heist_scale, heist_buy_ev, "HeistConfig.js"),
}

def run(name, n, seed=1):
    m, play, *_ = MACHINES[name]
    rng = random.Random(seed); tot = 0.0; feats = 0; hits = 0; best = 0
    for _ in range(n):
        w, f = play(rng, m); tot += w; feats += f; hits += w > 0; best = max(best, w)
    return tot / n, feats, hits / n, best

def write_js(name):
    m, _, _, buy_ev, fn = MACHINES[name]
    with open("qml/js/" + fn, "w") as f:
        f.write(".pragma library\n// Generated by tools/machinesim.py " + name + " --tune.\nvar machine = "
                + json.dumps(m, indent=1) + "\n")

if __name__ == "__main__":
    name = sys.argv[1]
    args = [a for a in sys.argv[2:] if not a.startswith("--")]
    n = int(args[0]) if args else 100000
    m, play, scale, buy_ev, _ = MACHINES[name]
    if "--tune" in sys.argv and name == "heist":
        heist_tune(m, n)
        ev = buy_ev(m, max(5000, n // 10))
        m["bonus"] = {"buy": max(10, int(round(ev / TARGET)))}
        print("feature EV from 6 chips %.1fx -> buy price %dx" % (ev, m["bonus"]["buy"]))
        write_js(name)
    elif "--tune" in sys.argv:
        for it in range(3):
            r = run(name, n, seed=11 + it)[0]
            scale(m, TARGET / r)
            print("pass %d: %.4f -> scaled" % (it, r))
        ev = buy_ev(m, max(2000, n // 25))
        m.setdefault("bonus", {})["buy"] = max(10, int(round(ev / TARGET)))
        print("bonus EV %.1fx -> buy price %dx" % (ev, m["bonus"]["buy"]))
        write_js(name)
    r, feats, hits, best = run(name, n, seed=99)
    print("%s RTP %.4f  feature 1/%.0f  hit %.3f  best %.0fx" % (name, r, n / max(1, feats), hits, best))
