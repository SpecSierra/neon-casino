.pragma library

function group(n) {
    var s = String(Math.floor(n)), out = ""
    while (s.length > 3) { out = "," + s.slice(-3) + out; s = s.slice(0, -3) }
    return s + out
}
// Neon credits (¤, the generic "currency sign": play money, not a real currency).
// ¤1,234 below a million, then ¤1.25M / ¤3.4B.
var symbol = "\u00a4"
function fmt(v) {
    var neg = v < 0; v = Math.abs(v)
    var s
    if (v >= 1e12) s = (v / 1e12).toFixed(2) + "T"
    else if (v >= 1e9) s = (v / 1e9).toFixed(2) + "B"
    else if (v >= 1e6) s = (v / 1e6).toFixed(2) + "M"
    else if (v < 100 && Math.floor(v) !== v) s = v.toFixed(2)
    else s = group(v)
    return (neg ? "-" : "") + symbol + s
}
// Tier thresholds 0, 250, 500, 1000, 2500, 5000, 10000 … (1-2.5-5 steps).
// `scale` = starting amount / 100: custom runs stretch every threshold and minimum bet.
function tierThreshold(t, scale) {
    if (t <= 0) return 0
    scale = scale || 1
    var steps = [250, 500, 1000], k = t - 1
    var base = steps[k % 3] * Math.pow(10, Math.floor(k / 3))
    return base * scale
}
function minBet(t, scale) {
    scale = scale || 1
    return Math.max(1, Math.round((t <= 0 ? 1 : Math.max(1, Math.floor(tierThreshold(t) / 100))) * scale))
}
function tierFor(peak, scale) {
    var t = 0
    while (tierThreshold(t + 1, scale) <= peak) ++t
    return t
}
