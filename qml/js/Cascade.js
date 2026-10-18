.pragma library
// CHAIN REACTION engine, mirroring tools/machinesim.py `cascade` (which tunes it to ~95%).
// Base game: chain k pays ×2^k (reset every drop). BONUS cores never match; 3+ on the settled
// board start free spins, where the multiplier rises +1 per chain and never resets.
// play() decides the whole spin up front: the start grid and every chain step, so the
// page only animates a result that is already saved.

function draw(m) {
    var total = 0, k
    for (k in m.weights) total += m.weights[k]
    var r = Math.random() * total
    for (k in m.weights) { r -= m.weights[k]; if (r < 0) return k }
    return m.gems[0]
}
function drawGem(m) {          // no cores: decorative boards
    var g
    do { g = draw(m) } while (g === "core")
    return g
}
function sizeFactor(m, n) { return m.size[String(Math.min(n, 10))] }
function chainMult(m, k) { return Math.min(Math.pow(2, k), m.multCap) }

// groups of 3+ orthogonally connected identical gems: [{ gem, cells: [[c, r], …] }]
function clusters(m, grid) {
    var seen = {}, out = []
    for (var c = 0; c < m.cols; ++c) {
        for (var r = 0; r < m.rows; ++r) {
            if (seen[c + "," + r] || grid[c][r] === "core") continue
            var g = grid[c][r], stack = [[c, r]], cells = []
            seen[c + "," + r] = true
            while (stack.length) {
                var p = stack.pop(); cells.push(p)
                var nb = [[p[0] + 1, p[1]], [p[0] - 1, p[1]], [p[0], p[1] + 1], [p[0], p[1] - 1]]
                for (var i = 0; i < 4; ++i) {
                    var x = nb[i][0], y = nb[i][1]
                    if (x >= 0 && x < m.cols && y >= 0 && y < m.rows && !seen[x + "," + y] && grid[x][y] === g) {
                        seen[x + "," + y] = true; stack.push([x, y])
                    }
                }
            }
            if (cells.length >= 3) out.push({ gem: g, cells: cells })
        }
    }
    return out
}

// { start, steps: [{ clusters, mult, win, refill: [[gems for column c, top first]] }], total, capped,
//   cores (on the settled board), bonusMult (after this drop, bonus only) }
// bonusMult: undefined in the base game; the running free-spin multiplier otherwise.
function play(m, bet, bonusMult) {
    var grid = [], c, r
    for (c = 0; c < m.cols; ++c) { var col = []; for (r = 0; r < m.rows; ++r) col.push(draw(m)); grid.push(col) }
    var start = JSON.parse(JSON.stringify(grid))
    var steps = [], total = 0, cap = m.maxWin * bet, capped = false
    for (var k = 0; ; ++k) {
        var cl = clusters(m, grid)
        if (!cl.length) break
        var mult = bonusMult === undefined ? chainMult(m, k) : bonusMult++, base = 0
        for (var i = 0; i < cl.length; ++i) base += m.base[cl[i].gem] * sizeFactor(m, cl[i].cells.length)
        var win = Math.round(base * mult * bet * 100) / 100
        if (total + win >= cap) { win = cap - total; capped = true }
        total += win
        var gone = {}
        for (i = 0; i < cl.length; ++i) for (var j = 0; j < cl[i].cells.length; ++j) gone[cl[i].cells[j][0] + "," + cl[i].cells[j][1]] = true
        var refill = []
        for (c = 0; c < m.cols; ++c) {
            var keep = []
            for (r = 0; r < m.rows; ++r) if (!gone[c + "," + r]) keep.push(grid[c][r])
            var fresh = []
            for (r = 0; r < m.rows - keep.length; ++r) fresh.push(draw(m))
            refill.push(fresh)
            grid[c] = fresh.concat(keep)
        }
        steps.push({ clusters: cl, mult: mult, win: win, refill: refill })
        if (capped) break
    }
    var cores = 0
    for (c = 0; c < m.cols; ++c) for (r = 0; r < m.rows; ++r) if (grid[c][r] === "core") ++cores
    return { start: start, steps: steps, total: Math.round(total * 100) / 100, capped: capped,
             cores: cores, bonusMult: bonusMult }
}
