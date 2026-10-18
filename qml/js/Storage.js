.pragma library
.import QtQuick.LocalStorage 2.0 as LS

var db = null
function open() {
    if (!db) {
        db = LS.LocalStorage.openDatabaseSync("neoncasino", "1.0", "Neon Casino save", 100000)
        db.transaction(function (tx) { tx.executeSql("CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)") })
    }
    return db
}
function load(key, fallback) {
    var out = fallback
    open().readTransaction(function (tx) {
        var r = tx.executeSql("SELECT v FROM kv WHERE k = ?", [key])
        if (r.rows.length) {
            try { out = JSON.parse(r.rows.item(0).v) } catch (e) { console.warn("bad save for", key) }
        }
    })
    return out
}
function save(key, value) {
    open().transaction(function (tx) {
        tx.executeSql("INSERT OR REPLACE INTO kv (k, v) VALUES (?, ?)", [key, JSON.stringify(value)])
    })
}
