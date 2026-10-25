pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool active: !Quickshell.screens.some(screen => screen.name === "HDMI-A-1")
    readonly property bool busy: action.running
    property bool actionsEnabled: true
    property bool previewActive: active
    readonly property bool displayedActive: actionsEnabled ? active : previewActive
    property string error: ""
    function completeHold() {
        if (busy) return
        if (actionsEnabled) toggle()
        else previewActive = !previewActive
    }
    function toggle() {
        if (busy) return
        error = ""
        action.command = ["python3", Quickshell.shellPath("session/work/work_mode.py"), active ? "restore" : "activate"]
        action.running = true
    }
    Process {
        id: action
        stderr: StdioCollector {
            onStreamFinished: {
                root.error = text.trim()
                if (root.error) console.warn("Work mode:", root.error)
            }
        }
    }
}
