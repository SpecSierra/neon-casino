import QtQuick 2.6
import Sailfish.Silica 1.0
import "components"
import "pages"

ApplicationWindow {
    id: app
    allowedOrientations: Orientation.Portrait
    _defaultPageOrientations: Orientation.Portrait
    initialPage: Component { HubPage { id: hub } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")

    Component.onCompleted: {
        Game.load()
        if (!Game.introSeen) pageStack.push(Qt.resolvedUrl("pages/IntroPage.qml"), {}, PageStackAction.Immediate)
        draftTimer.start()
    }

    // Frame-rate probe: an animation is ticked once per rendered frame, so counting its updates
    // over 2.5 s (starting 2.5 s after launch, once loading has settled) gives the real fps.
    QtObject {
        id: probe
        property real v: 0
        property int frames: 0
        onVChanged: frames++
    }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 2500 }
        ScriptAction { script: probe.frames = 0 }
        NumberAnimation { target: probe; property: "v"; from: 0; to: 1; duration: 2500 }
        ScriptAction {
            script: {
                Game.measuredFps = Math.round(probe.frames / 2.5)
                Game.slowDevice = Game.measuredFps > 0 && Game.measuredFps < 48
                console.log("Neon Casino: " + Game.measuredFps + " fps, " + (Game.lowFx ? "light" : "full") + " effects")
            }
        }
    }

    // Open the perk draft / game-over screen once the stack is idle.
    property bool forceGameOver: false
    Timer {
        id: draftTimer
        interval: 350
        onTriggered: {
            if (pageStack.busy) { restart(); return }
            var top = pageStack.currentPage
            if (top && top.objectName === "intro") return        // wait for the intro (introSeen restarts us)
            if (Game.runOver) {
                // at a table, the losing round stays on screen until the player taps on
                if (top && top.isTable && !forceGameOver) return
                forceGameOver = false
                // only from the hub or a table: never on top of the game-over screen, REBOOT or the
                // new-run menu they open (that made two screens fight over the top of the stack)
                if (!top || top.objectName === "hub" || top.isTable)
                    pageStack.push(Qt.resolvedUrl("pages/GameOverPage.qml"))
            } else if (Game.pendingDrafts > 0 && (!top || top.objectName !== "draft")) {
                pageStack.push(Qt.resolvedUrl("pages/PerkDraftPage.qml"))
            }
        }
    }
    Connections {
        target: Game
        onPendingDraftsChanged: if (Game.pendingDrafts > 0) draftTimer.restart()
        onBusted: draftTimer.restart()
        onGameOverRequested: { forceGameOver = true; draftTimer.restart() }
        onIntroSeenChanged: draftTimer.restart()          // the first-launch intro just closed
    }
    // leaving a table after a bust (back gesture) goes straight to the game-over screen
    Connections {
        target: pageStack
        onCurrentPageChanged: if (Game.runOver) draftTimer.restart()
    }
}
