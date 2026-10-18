pragma Singleton
import QtQuick 2.6
import QtMultimedia 5.6
import "../js/MusicTracks.js" as Tracks

// Background music without a seam. Each file is one loop plus a few seconds of release
// tail (tools/music.py). Two players alternate: shortly before the loop point the idle one
// is cued up paused at 0, and at exactly loopMs it starts while the other one keeps
// playing its tail. Changing track cross-fades instead.
QtObject {
    id: music
    property bool enabled: true
    property real level: 0.9
    // per-track loudness match from tools/music.py
    readonly property real trackLevel: level * (Tracks.gain && Tracks.gain[track] !== undefined ? Tracks.gain[track] : 0.5)
    property string track: ""            // lobby | slots | tables | bonus
    property bool useA: true
    readonly property bool live: enabled && Qt.application.active && track !== ""
    readonly property int loopMs: Tracks.loopMs[track] || 0
    readonly property int lead: 30       // start the next pass a touch early (output latency)

    // Qt 5.6's QML MediaPlayer reports position only once a second, so the seam is timed
    // on the wall clock: startWall = best (earliest) estimate of when this pass began.
    property MediaPlayer a: MediaPlayer {
        volume: 0
        onStatusChanged: music.ended(music.a)
        onPositionChanged: music.observe(music.a)
    }
    property MediaPlayer b: MediaPlayer {
        volume: 0
        onStatusChanged: music.ended(music.b)
        onPositionChanged: music.observe(music.b)
    }
    property real startWall: 0
    property bool startKnown: false
    function observe(p) {
        if (p !== current() || !playing(p)) return
        var est = Date.now() - p.position
        if (!startKnown || est < startWall) { startWall = est; startKnown = true }
    }
    property NumberAnimation fadeIn: NumberAnimation { property: "volume"; duration: 900 }
    property NumberAnimation fadeOut: NumberAnimation {
        property: "volume"; to: 0; duration: 900
        onStopped: if (target && target.volume === 0) target.stop()
    }
    // coarse watch: cue the idle player ~3 s before the seam, then arm the precise timer
    property Timer watch: Timer {
        interval: 500; repeat: true; running: music.live
        onTriggered: music.check()
    }
    property Timer seam: Timer { onTriggered: music.nextPass() }
    property bool cued: false

    function url(t) { return Qt.resolvedUrl("../music/" + t + ".ogg") }
    function current() { return useA ? a : b }
    function other() { return useA ? b : a }
    function playing(p) { return p.playbackState === MediaPlayer.PlayingState }
    function ended(p) {
        if (p.status === MediaPlayer.EndOfMedia && p !== current()) p.stop()
    }

    onTrackChanged: switchTo()
    // the volume slider: follow it live (not mid-cross-fade, the fade sets the level itself)
    onTrackLevelChanged: if (live && !fadeIn.running && playing(current())) current().volume = trackLevel
    onLiveChanged: {
        if (!live) { seam.stop(); a.pause(); b.pause(); cued = false; startKnown = false; return }
        var p = current()
        if (String(p.source) !== String(url(track))) { switchTo(); return }
        p.volume = trackLevel
        p.play()
    }

    function check() {
        var p = current()
        if (!live || !loopMs || !playing(p) || !startKnown) return
        var left = startWall + loopMs - Date.now()
        if (!cued && left < 3000) {
            var n = other()
            fadeOut.stop()
            n.stop()
            n.source = url(track)
            n.volume = trackLevel
            n.pause()                    // prerolls the pipeline at 0
            cued = true
        }
        if (cued && left < 1200 && !seam.running) {
            seam.interval = Math.max(1, left - lead)
            seam.start()
        }
    }
    function nextPass() {
        if (!live) return
        var n = other()
        n.volume = trackLevel
        n.play()
        startWall = Date.now() + lead; startKnown = true   // refined by position updates
        useA = !useA                     // the old player keeps going through its tail
        cued = false
    }
    function switchTo() {
        seam.stop(); cued = false
        if (!live) return
        // settle any fade from a switch moments ago FIRST: stopping fadeOut stops its (silent)
        // target, and if that target were already re-loaded with the new track (two quick
        // track changes inside one cross-fade) the new track would be cut off
        fadeIn.stop(); fadeOut.stop()
        var next = other(), prev = current()
        if (String(prev.source) === String(url(track)) && playing(prev)) return
        next.stop()
        next.source = url(track)
        next.volume = 0
        next.play()
        startKnown = false
        fadeIn.target = next; fadeIn.to = trackLevel; fadeIn.start()
        if (playing(prev)) { fadeOut.target = prev; fadeOut.start() }
        useA = !useA
    }
}
