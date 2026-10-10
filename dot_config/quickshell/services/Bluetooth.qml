pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var state: ({
            adapter: "",
            name: "Bluetooth",
            enabled: false,
            devices: []
        })
    property bool ready: false
    property string error: ""
    property var viewers: []
    property var currentRequest: []
    property var pendingActions: []
    readonly property var action: currentRequest[0] === "status" ? [] : currentRequest
    readonly property bool busy: action.length > 0 || pendingActions.some(args => args[0] !== "scan")
    readonly property bool scanning: scan.running || pendingActions.some(args => args[0] === "scan")

    function setViewer(viewer, opened) {
        const wasActive = viewers.length > 0
        viewers = viewers.filter(item => item !== viewer)
        if (opened) {
            viewers = [...viewers, viewer]
            if (!wasActive)
                refresh()
        } else if (viewers.length === 0)
            error = ""
    }
    function refresh() {
        if (!request.running && currentRequest.length === 0 && pendingActions.length === 0)
            startRequest(["status"])
    }
    function runAction(arguments) {
        if (arguments[0] === "scan" && scanning)
            return
        error = ""
        pendingActions = [...pendingActions, arguments]
        nextRequest()
    }
    function startRequest(arguments) {
        currentRequest = arguments
        request.command = ["python3", Quickshell.shellPath("bar/bluetooth/bluetooth.py")].concat(arguments)
        request.running = true
    }
    function nextRequest() {
        if (request.running || currentRequest.length || pendingActions.length === 0)
            return
        const next = pendingActions[0]
        pendingActions = pendingActions.slice(1)
        if (next[0] === "scan") {
            if (!scan.running)
                scan.running = true
            Qt.callLater(root.nextRequest)
        } else
            startRequest(next)
    }
    Process {
        id: request
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.state = response.data
                        root.ready = true
                        root.error = ""
                        if (root.action[0] === "power" && root.action[1] === "true" && root.state.enabled)
                            root.runAction(["scan"])
                    } else
                        root.error = response.error
                } catch (error) {
                    root.error = "Could not read Bluetooth information."
                    console.warn(root.error, error)
                }
            }
        }
        // Quickshell qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.currentRequest = []
            Qt.callLater(root.nextRequest)
        }
        // qmllint enable signal-handler-parameters
    }
    // Discovery stays independent so snapshots can show devices as they appear.
    Process {
        id: scan
        command: ["python3", Quickshell.shellPath("bar/bluetooth/bluetooth.py"), "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.state = response.data
                        root.ready = true
                        root.error = ""
                    } else
                        root.error = response.error
                } catch (error) {
                    root.error = "Could not scan for devices."
                    console.warn(root.error, error)
                }
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.refresh()
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        interval: root.viewers.length > 0 ? 2000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
