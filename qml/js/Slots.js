.pragma library
// Slot engine. Every function takes a machine (`theme`) from SlotThemes.js, which
// tools/slotsim.py generates and tunes (≈95% RTP on every machine and line count).

// Paylines in play order: you pick how many (1, 3, 5 or 9) and pay the line bet on each.
var lines = [[1, 1, 1], [0, 0, 0], [2, 2, 2], [0, 1, 2], [2, 1, 0], [0, 1, 0], [2, 1, 2], [1, 0, 1], [1, 2, 1]]
var lineOptions = [1, 3, 5, 9]

function image(theme, sym) { return "../images/" + theme.prefix + sym + ".png" }

function pick(theme, wild, bonus) {
    var w = {}, total = 0, k
    for (k in theme.weights) w[k] = theme.weights[k]
    w.scatter = bonus ? theme.bonus.bonusScatter : theme.bonus.scatter
    if (wild) w.wild = 1
    for (k in w) total += w[k]
    var r = Math.random() * total
    for (k in w) { r -= w[k]; if (r < 0) return k }
    return theme.symbols[0]
}
// grid[reel][row]
function spin(theme, perks, bonus) {
    var wild = perks.indexOf("wild") >= 0
    var g = []
    for (var i = 0; i < 3; ++i) g.push([pick(theme, wild, bonus), pick(theme, wild, bonus), pick(theme, wild, bonus)])
    var nudged = false
    if (perks.indexOf("nudge") >= 0 && g[0][1] === g[1][1] && g[0][1] !== "scatter"
            && g[2][1] !== g[0][1] && Math.random() < 0.12) {
        g[2][1] = g[0][1]; nudged = true
    }
    return { grid: g, nudged: nudged }
}
function topPay(theme, perks) {
    var m = theme.pay3[theme.top]
    if (perks.indexOf("jackpot") >= 0) m *= 3
    if (perks.indexOf("lucky7") >= 0) m *= 2
    return m
}
function linePay(theme, a, b, c, perks) {
    var s2 = theme.low2.symbol
    var low2 = (a === s2 && (b === s2 || b === "wild")) || (a === "wild" && b === s2)
    if (a === "scatter" || b === "scatter" || c === "scatter") return low2 ? theme.low2.pay : 0
    var base = [a, b, c].filter(function (s) { return s !== "wild" })
    if (!base.length) return theme.pay3.wild
    if (base.every(function (s) { return s === base[0] }))
        return base[0] === theme.top ? topPay(theme, perks) : theme.pay3[base[0]]
    return low2 ? theme.low2.pay : 0
}
function scatterHit(grid) {
    for (var i = 0; i < 3; ++i) if (grid[i].indexOf("scatter") < 0) return false
    return true
}
// { multiplier (of the total bet, line wins only), winningLines: [index], scatter: bool }
function evaluate(theme, grid, perks, nLines) {
    var n = nLines || 5
    var total = 0, wins = []
    for (var i = 0; i < n; ++i) {
        var l = lines[i]
        var p = linePay(theme, grid[0][l[0]], grid[1][l[1]], grid[2][l[2]], perks)
        if (p > 0) { total += p; wins.push(i) }
    }
    var mult = total / n
    if (perks.indexOf("overclock") >= 0) mult *= 1.25
    return { multiplier: mult, winningLines: wins, scatter: scatterHit(grid) }
}
function ladder(theme, level, perks) {
    var f = perks.indexOf("overdrive") >= 0 ? 2 : 1
    var l = theme.bonus.ladders
    return l[Math.min(level, l.length - 1)].map(function (v) { return v * f })
}
function rollMultiplier(theme, level, perks) {
    var l = ladder(theme, level, perks), r = Math.random() * 100
    for (var i = 0; i < l.length; ++i) { r -= theme.bonus.ladderWeights[i]; if (r < 0) return l[i] }
    return l[0]
}

// ---- per-machine features (see tools/slotsim.py) ----
function feature(theme) { return theme.feature || { type: "ladder" } }
function symbolAnywhere(grid, sym) {
    for (var i = 0; i < 3; ++i) if (grid[i].indexOf(sym) >= 0) return true
    return false
}
// Base-game feature: returns the multiplier for this spin and updates `st` in place.
// combo: centre-line win stacks the next spin's multiplier; turbo: suns fill fuel.
function applyFeature(theme, st, grid, ev) {
    var f = feature(theme), mult = 1, info = ""
    if (f.type === "combo") {
        mult = st.combo || 1
        var centre = ev.winningLines.indexOf(0) >= 0
        st.combo = centre ? Math.min((st.combo || 1) + 1, f.max) : 1
        if (mult > 1 && ev.multiplier > 0) info = "OVERFLOW ×" + mult
    } else if (f.type === "turbo") {
        if (st.turbo) {
            mult = f.mult; st.turbo = false; st.fuel = 0; info = "TURBO SPIN ×" + f.mult
        } else if (symbolAnywhere(grid, f.symbol)) {
            st.fuel = (st.fuel || 0) + 1
            if (st.fuel >= f.fuel) { st.turbo = true; st.fuel = f.fuel }
        }
    }
    return { mult: mult, info: info }
}
function rollIncrement(theme, perks) {
    var f = feature(theme), r = Math.random() * f.weights.reduce(function (a, b) { return a + b }, 0)
    var k = perks.indexOf("overdrive") >= 0 ? 2 : 1
    for (var i = 0; i < f.increments.length; ++i) { r -= f.weights[i]; if (r < 0) return f.increments[i] * k }
    return f.increments[0] * k
}
