.pragma library
// VOID RUNNER engine (infinity reels). Mirrors tools/voidsim.py; machine in VoidConfig.js.
// grid[reel][row]. Ways pay from the left, 3+ reels, wild substitutes (never on reel 1):
// pay = base[s] × (length - 2) × ways. A win reaching the last reel opens one more reel.

function pick(m, first) {
    var tot = 0, k
    for (k in m.weights) if (!(first && k === "wild")) tot += m.weights[k]
    var r = Math.random() * tot
    for (k in m.weights) { if (first && k === "wild") continue; r -= m.weights[k]; if (r < 0) return k }
    return m.symbols[0]
}
function column(m, first) { var c = []; for (var i = 0; i < m.rows; ++i) c.push(pick(m, first)); return c }

// -> { pay (× bet, before multiplier), reach, wins: [{ sym, length, ways, pay, cells: [[reel,row]] }] }
function evaluate(m, grid) {
    var pay = 0, reach = false, wins = []
    for (var si = 0; si < m.symbols.length; ++si) {
        var s = m.symbols[si], ways = 1, len = 0, cells = []
        for (var r = 0; r < grid.length; ++r) {
            var c = 0
            for (var y = 0; y < grid[r].length; ++y) if (grid[r][y] === s || grid[r][y] === "wild") { c++; cells.push([r, y]) }
            if (!c) break
            ways *= c; len++
        }
        if (len >= 3) {
            var p = m.base[s] * (len - 2) * ways
            pay += p
            if (len === grid.length) reach = true
            wins.push({ sym: s, length: len, ways: ways, pay: p, cells: cells.filter(function (cl) { return cl[0] < len }) })
        }
    }
    return { pay: pay, reach: reach, wins: wins }
}
// A whole spin, reels and all: { grid, ev (of the final grid), added, portals }
function play(m) {
    var grid = []
    for (var i = 0; i < m.start; ++i) grid.push(column(m, i === 0))
    var ev = evaluate(m, grid)
    while (ev.reach && grid.length < m.maxReels) {
        grid.push(column(m, false))
        ev = evaluate(m, grid)
    }
    var portals = 0
    for (var r = 0; r < grid.length; ++r) for (var y = 0; y < grid[r].length; ++y) if (grid[r][y] === "portal") portals++
    return { grid: grid, ev: ev, added: grid.length - m.start, portals: portals }
}
