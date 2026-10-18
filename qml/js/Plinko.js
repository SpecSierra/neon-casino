.pragma library
// Plinko path: 12 left/right bounces (fair coin each), slot = number of rights.
function path(rows) { var p = []; for (var i = 0; i < rows; ++i) p.push(Math.random() < 0.5 ? 0 : 1); return p }
function slot(p) { var s = 0; for (var i = 0; i < p.length; ++i) s += p[i]; return s }
