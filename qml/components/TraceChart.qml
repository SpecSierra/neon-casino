import QtQuick 2.6
import Sailfish.Silica 1.0
import "../js/Money.js" as Money
import "."

// Net-worth line for the current run, with the tier thresholds as faint guides.
Canvas {
    id: chart
    property var values: []
    property color color: Neon.cyan
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var v = values
        if (!v || v.length < 2) return
        var lo = Math.min.apply(null, v), hi = Math.max.apply(null, v)
        if (hi - lo < 1) { hi += 1; lo = Math.max(0, lo - 1) }
        var pad = 6, w = width - 2 * pad, h = height - 2 * pad
        function X(i) { return pad + w * i / (v.length - 1) }
        function Y(x) { return pad + h * (1 - (x - lo) / (hi - lo)) }
        // tier guides
        ctx.strokeStyle = "rgba(255,43,214,0.25)"; ctx.lineWidth = 1
        for (var t = 1; t < 40; ++t) {
            var th = Money.tierThreshold(t, Game.scale)
            if (th > hi) break
            if (th < lo) continue
            ctx.beginPath(); ctx.moveTo(pad, Y(th)); ctx.lineTo(pad + w, Y(th)); ctx.stroke()
        }
        // start line
        ctx.strokeStyle = "rgba(255,255,255,0.25)"
        ctx.beginPath(); ctx.moveTo(pad, Y(v[0])); ctx.lineTo(pad + w, Y(v[0])); ctx.stroke()
        // area + glow line
        ctx.beginPath(); ctx.moveTo(X(0), Y(v[0]))
        for (var i = 1; i < v.length; ++i) ctx.lineTo(X(i), Y(v[i]))
        ctx.lineTo(X(v.length - 1), pad + h); ctx.lineTo(X(0), pad + h); ctx.closePath()
        var g = ctx.createLinearGradient(0, pad, 0, pad + h)
        g.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.35)); g.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0))
        ctx.fillStyle = g; ctx.fill()
        for (var pass = 0; pass < 2; ++pass) {
            ctx.beginPath(); ctx.moveTo(X(0), Y(v[0]))
            for (var j = 1; j < v.length; ++j) ctx.lineTo(X(j), Y(v[j]))
            ctx.strokeStyle = pass ? Qt.lighter(color, 1.4) : Qt.rgba(color.r, color.g, color.b, 0.35)
            ctx.lineWidth = pass ? 2.5 : 8
            ctx.stroke()
        }
    }
}
