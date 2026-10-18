.pragma library
// DATA HEIST engine, mirroring tools/machinesim.py `heist`.
// 5×3, 10 lines (line bet = bet / 10). Data chips carry a value (× bet); 6+ chips start the heist:
// chips lock, 3 respins, every new chip resets them to 3; a full board adds the GRAND.

function pick(m) {
    var total = 0, k
    for (k in m.weights) total += m.weights[k]
    var r = Math.random() * total
    for (k in m.weights) { r -= m.weights[k]; if (r < 0) return k }
    return m.symbols[0]
}
function chipValue(m) {
    var total = m.chipWeights.reduce(function (a, b) { return a + b }, 0), r = Math.random() * total
    for (var i = 0; i < m.chipValues.length; ++i) { r -= m.chipWeights[i]; if (r < 0) return m.chipValues[i] }
    return m.chipValues[0]
}
function tierName(m, v) {
    return v >= 150 ? "MAJOR" : v >= 50 ? "MINOR" : v >= 25 ? "MINI" : ""
}
// grid[reel][row] = symbol; values[reel][row] = chip value (0 for non-chips)
function spinGrid(m) {
    var g = [], v = []
    for (var i = 0; i < m.reels; ++i) {
        var col = [], vc = []
        for (var j = 0; j < m.rows; ++j) { var s = pick(m); col.push(s); vc.push(s === "chip" ? chipValue(m) : 0) }
        g.push(col); v.push(vc)
    }
    return { grid: g, values: v }
}
// { total (× bet), wins: [{ line, n, sym }] }
function lines(m, g) {
    var total = 0, wins = []
    for (var l = 0; l < m.lines.length; ++l) {
        var line = m.lines[l], s = g[0][line[0]]
        if (s === "chip") continue
        var n = 1
        while (n < m.reels && g[n][line[n]] === s) ++n
        if (n >= 3) { total += m.pay[s][n - 3] / m.lines.length; wins.push({ line: l, n: n, sym: s }) }
    }
    return { total: total, wins: wins }
}
// Play out the heist from the locked chips: { steps: [{ added: [{ reel, row, value }], left }], total, grand }
function heist(m, locked) {
    var cells = m.reels * m.rows, have = {}, values = 0, i
    for (i = 0; i < locked.length; ++i) { have[locked[i].reel + "," + locked[i].row] = true; values += locked[i].value }
    var count = locked.length, left = m.respins, steps = []
    while (left > 0 && count < cells) {
        left -= 1
        var added = []
        for (var r = 0; r < m.reels; ++r)
            for (var c = 0; c < m.rows; ++c)
                if (!have[r + "," + c] && Math.random() < m.respinChance) {
                    var v = chipValue(m)
                    added.push({ reel: r, row: c, value: v }); have[r + "," + c] = true; values += v; ++count
                }
        if (added.length) left = m.respins
        steps.push({ added: added, left: left })
    }
    var grand = count >= cells
    return { steps: steps, total: Math.min(values + (grand ? m.grand : 0), m.maxWin), grand: grand }
}
// a bought heist starts with `trigger` chips in random cells
function boughtStart(m) {
    var cells = [], out = []
    for (var r = 0; r < m.reels; ++r) for (var c = 0; c < m.rows; ++c) cells.push([r, c])
    for (var i = 0; i < m.trigger; ++i) {
        var k = Math.floor(Math.random() * cells.length), cell = cells.splice(k, 1)[0]
        out.push({ reel: cell[0], row: cell[1], value: chipValue(m) })
    }
    return out
}
