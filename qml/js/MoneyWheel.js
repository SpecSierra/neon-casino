.pragma library
// Money wheel: 51 segments labelled with what they return (stake included). A bet on a label
// pays when the wheel stops on it. Counts give 94-98% on every bet.
var labels = [2, 4, 6, 12, 25, 50]
var counts = { 2: 24, 4: 12, 6: 8, 12: 4, 25: 2, 50: 1 }
var colors = { 2: "#00F0FF", 4: "#39FF88", 6: "#A05AFF", 12: "#FF2BD6", 25: "#F8FF3A", 50: "#FF3355" }
// spread each label evenly round the wheel
var segments = (function () {
    var slots = [], order = labels.slice().reverse()
    var total = 0, k; for (k in counts) total += counts[k]
    var pos = []
    for (var i = 0; i < order.length; ++i) {
        var n = counts[order[i]]
        for (var j = 0; j < n; ++j) pos.push({ v: order[i], at: (j + 0.5) / n + i * 0.013 })
    }
    pos.sort(function (a, b) { return a.at - b.at })
    for (i = 0; i < pos.length; ++i) slots.push(pos[i].v)
    return slots
})()
function spin() { return Math.floor(Math.random() * segments.length) }
