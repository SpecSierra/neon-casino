.pragma library
// NEURAL WAYS engine, mirroring tools/machinesim.py `ways`.
// 6 reels of 2-7 rows. A symbol pays when it (or a wild) shows on 3+ adjacent reels from the
// left; ways = product of how many times it shows on each of those reels. Wilds only land on
// the middle reels. 4+ scatters start free spins with a multiplier that rises +1 per win.

function pick(m) {
    var total = 0, k
    for (k in m.weights) total += m.weights[k]
    var r = Math.random() * total
    for (k in m.weights) { r -= m.weights[k]; if (r < 0) return k }
    return m.symbols[0]
}
function grid(m) {
    var g = []
    for (var i = 0; i < m.reels; ++i) {
        var h = m.minRows + Math.floor(Math.random() * (m.maxRows - m.minRows + 1)), col = []
        for (var j = 0; j < h; ++j) {
            var s = pick(m)
            if (s === "wild" && (i === 0 || i === m.reels - 1)) s = m.symbols[0]
            col.push(s)
        }
        g.push(col)
    }
    return g
}
function waysCount(g) { var w = 1; for (var i = 0; i < g.length; ++i) w *= g[i].length; return w }
// { total (× bet), wins: [{ sym, n, ways, pay, cells: [[reel, row]] }], scatters }
function evaluate(m, g) {
    var total = 0, wins = []
    for (var si = 0; si < m.symbols.length; ++si) {
        var s = m.symbols[si], ways = 1, n = 0, cells = []
        for (var i = 0; i < g.length; ++i) {
            var hit = []
            for (var j = 0; j < g[i].length; ++j) if (g[i][j] === s || g[i][j] === "wild") hit.push([i, j])
            if (!hit.length) break
            if (n === 0 && g[i].indexOf(s) < 0) break
            ways *= hit.length; n += 1; cells = cells.concat(hit)
        }
        if (n >= 3) {
            var pay = m.pay[s][n - 3] * ways
            total += pay
            wins.push({ sym: s, n: n, ways: ways, pay: pay, cells: cells })
        }
    }
    var sc = 0
    for (i = 0; i < g.length; ++i) for (j = 0; j < g[i].length; ++j) if (g[i][j] === "scatter") ++sc
    return { total: total, wins: wins, scatters: sc }
}
