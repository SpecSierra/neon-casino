.pragma library
// ABYSS engine: a fruit machine with fixed reel strips, HOLDs and NUDGEs. The machine and its
// paytable come from AbyssConfig.js (tools/abysssim.py, exact RTP under best play).
// A reel sits at `pos`; its window shows strip[pos+1] (top), strip[pos] (centre), strip[pos-1].
// A nudge steps a reel to pos+1: the symbol above drops onto the line.

function sym(m, r, pos) { var n = m.strips[r].length; return m.strips[r][((pos % n) + n) % n] }
function column(m, r, pos) { return [sym(m, r, pos + 1), sym(m, r, pos), sym(m, r, pos - 1)] }
function line(m, pos) { return [sym(m, 0, pos[0]), sym(m, 1, pos[1]), sym(m, 2, pos[2])] }

function linePay(m, a, b, c) {
    var syms = [a, b, c], pearls = syms.filter(function (s) { return s === "pearl" }).length, p = 0
    if (pearls) p = m.pearls[String(pearls)] || 0
    else {
        var base = syms.filter(function (s) { return s !== "wild" })
        if (!base.length) p = m.pay3.wild
        else if (base.every(function (s) { return s === base[0] })) p = m.pay3[base[0]]
    }
    if (!p && a === "shell") p = (b === "shell" || b === "wild") ? m.shell2 : m.shell1
    return p
}
function payAt(m, pos) { var l = line(m, pos); return linePay(m, l[0], l[1], l[2]) }

// One spin. `held`: [bool×3] with the positions to keep in `from`. A held spin has no feature.
function spin(m, held, from) {
    var pos = []
    for (var r = 0; r < 3; ++r) pos.push(held && held[r] ? from[r] : Math.floor(Math.random() * m.strips[r].length))
    var feature = { type: "none", nudges: 0 }
    var anyHeld = held && (held[0] || held[1] || held[2])
    if (!anyHeld) {
        var x = Math.random()
        if (x < m.nudge.p) {
            var tot = m.nudge.w.reduce(function (a, b) { return a + b }, 0), y = Math.random() * tot
            for (var i = 0; i < m.nudge.n.length; ++i) { y -= m.nudge.w[i]; if (y < 0) { feature = { type: "nudge", nudges: m.nudge.n[i] }; break } }
        } else if (x < m.nudge.p + m.holdP) feature = { type: "hold", nudges: 0 }
    }
    return { pos: pos, feature: feature }
}

// Best line reachable with up to n nudges: { pay, steps: [per reel] } (the hint)
function bestNudge(m, pos, n) {
    var best = { pay: payAt(m, pos), steps: [0, 0, 0] }
    for (var a = 0; a <= n; ++a)
        for (var b = 0; a + b <= n; ++b)
            for (var c = 0; a + b + c <= n; ++c) {
                var p = payAt(m, [pos[0] + a, pos[1] + b, pos[2] + c])
                if (p > best.pay) best = { pay: p, steps: [a, b, c] }
            }
    return best
}
// The hold (up to two reels) with the best average next-spin pay: { held: [bool×3], ev }
function bestHold(m, pos) {
    var n = m.strips[0].length, best = { held: [false, false, false], ev: -1 }
    var sets = [[false, false, false], [true, false, false], [false, true, false], [false, false, true],
                [true, true, false], [true, false, true], [false, true, true]]
    for (var s = 0; s < sets.length; ++s) {
        var h = sets[s], tot = 0, cnt = 0
        for (var i = 0; i < (h[0] ? 1 : n); ++i)
            for (var j = 0; j < (h[1] ? 1 : n); ++j)
                for (var k = 0; k < (h[2] ? 1 : n); ++k) {
                    tot += payAt(m, [h[0] ? pos[0] : i, h[1] ? pos[1] : j, h[2] ? pos[2] : k]); cnt++
                }
        if (tot / cnt > best.ev + 1e-9) best = { held: h, ev: tot / cnt }
    }
    return best
}
