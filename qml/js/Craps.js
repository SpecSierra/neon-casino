.pragma library
// Craps. Bets stay on the table between rolls; resolve() settles whatever a roll decides.
// Pass / Don't Pass: come-out 7-11 / 2-3-12, then the point (Don't Pass pushes on 12).
// Odds behind Pass (after a point, up to 3× the Pass bet) pay true odds: no house edge.
// One-roll bets: Field 3,4,9,10,11 1:1, 2 pays 2:1, 12 pays 3:1 · Any 7 4:1 · Any Craps 7:1.

function roll() { return [1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)] }
var trueOdds = { 4: 2, 10: 2, 5: 1.5, 9: 1.5, 6: 1.2, 8: 1.2 }
var oneRoll = ["field", "any7", "anycraps"]

function canPlace(state, key) {
    if (key === "pass" || key === "dontpass") return state.point === 0
    if (key === "odds") return state.point !== 0 && (state.table.pass || 0) > 0
    return true
}
function oddsLimit(state) { return 3 * (state.table.pass || 0) - (state.table.odds || 0) }

// state: { point, table: { key: stake } } (not modified). Returns
// { state: new state, staked: stakes that were decided, returned, events: [text], outcome: "natural"|"craps"|"point"|"seven"|"made"|"" }
function resolve(state, dice) {
    var t = dice[0] + dice[1], table = {}, k
    for (k in state.table) table[k] = state.table[k]
    var point = state.point, staked = 0, returned = 0, events = [], outcome = ""
    function settle(key, ret) { staked += table[key]; returned += ret; delete table[key] }
    // one-roll bets
    if (table.field) settle("field", t === 2 ? table.field * 3 : t === 12 ? table.field * 4 : [3, 4, 9, 10, 11].indexOf(t) >= 0 ? table.field * 2 : 0)
    if (table.any7) settle("any7", t === 7 ? table.any7 * 5 : 0)
    if (table.anycraps) settle("anycraps", [2, 3, 12].indexOf(t) >= 0 ? table.anycraps * 8 : 0)
    if (point === 0) {
        if (t === 7 || t === 11) {
            outcome = "natural"; events.push("NATURAL " + t)
            if (table.pass) settle("pass", table.pass * 2)
            if (table.dontpass) settle("dontpass", 0)
        } else if (t === 2 || t === 3 || t === 12) {
            outcome = "craps"; events.push("CRAPS " + t)
            if (table.pass) settle("pass", 0)
            if (table.dontpass) settle("dontpass", t === 12 ? table.dontpass : table.dontpass * 2)
        } else {
            point = t; outcome = "point"; events.push("POINT IS " + t)
        }
    } else if (t === point) {
        outcome = "made"; events.push("POINT " + t + " MADE")
        if (table.pass) settle("pass", table.pass * 2)
        if (table.odds) settle("odds", table.odds * (1 + trueOdds[point]))
        if (table.dontpass) settle("dontpass", 0)
        point = 0
    } else if (t === 7) {
        outcome = "seven"; events.push("SEVEN OUT")
        if (table.pass) settle("pass", 0)
        if (table.odds) settle("odds", 0)
        if (table.dontpass) settle("dontpass", table.dontpass * 2)
        point = 0
    }
    return { state: { point: point, table: table }, staked: staked, returned: Math.round(returned * 100) / 100,
             events: events, outcome: outcome, total: t }
}
