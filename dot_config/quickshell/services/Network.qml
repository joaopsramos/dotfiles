pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var network: ({
            enabled: false,
            device: "",
            current: {
                name: "Not connected",
                kind: "down",
                device: "",
                address: "",
                gateway: "",
                signal: -1
            },
            networks: [],
            profiles: []
        })
    property bool ready: false
    property string error: ""
    property var viewers: []
    property var editors: []
    property var pendingActions: []
    property var activeAction: []
    property string requestInput: ""
    property var failedSsids: []
    readonly property var actions: [activeAction].concat(pendingActions.map(item => item.arguments))
    readonly property var connectingUuids: actions.filter(action => action[0] === "connect").map(action => action[1])
    readonly property string connectingSsid: actions.find(action => action[0] === "join")?.[1] || ""
    readonly property bool scanning: actions.some(action => action[0] === "scan" || (action[0] === "radio" && action[1] === "on"))
    readonly property bool turningOn: actions.some(action => action[0] === "radio" && action[1] === "on")
    signal joinFinished(string ssid, bool success)

    function setViewer(viewer, opened) {
        const wasActive = viewers.length > 0
        viewers = viewers.filter(item => item !== viewer)
        if (opened)
            viewers = [...viewers, viewer]
        if (opened && !wasActive) {
            error = ""
            refresh()
        }
    }
    function setEditor(viewer, editing) {
        editors = editors.filter(item => item !== viewer)
        if (editing)
            editors = [...editors, viewer]
    }
    function refresh() {
        if (!request.running && pendingActions.length === 0)
            enqueue(["status"])
    }
    function enqueue(arguments, input = "") {
        pendingActions = [...pendingActions,
            {
                arguments: arguments,
                input: input
            }
        ]
        nextRequest()
    }
    function runAction(arguments) {
        error = ""
        enqueue(arguments)
        if (arguments[0] === "radio" && arguments[1] === "on" && network.device)
            enqueue(["scan", network.device])
    }
    function nextRequest() {
        if (request.running || activeAction.length || pendingActions.length === 0)
            return
        const next = pendingActions[0]
        pendingActions = pendingActions.slice(1)
        activeAction = next.arguments
        requestInput = next.input
        request.command = ["python3", Quickshell.shellPath("bar/network/network.py")].concat(activeAction)
        request.running = true
    }
    function acceptResponse(text) {
        const response = JSON.parse(text)
        if (response.ok) {
            network = response.data
            ready = true
            error = ""
            Status.updateNetwork(network.current)
        } else
            error = response.error
        return response.ok
    }
    function joinNetwork(entry, password) {
        if (connectingSsid !== "")
            return false
        error = ""
        enqueue(["join", entry.ssid, network.device, entry.uuid || ""], JSON.stringify({
            password: password
        }) + "\n")
        return true
    }
    Process {
        id: request
        stdinEnabled: true
        environment: ({
                QUICKSHELL_NETWORK_PROFILES: JSON.stringify(root.network.profiles)
            })
        onStarted: {
            if (root.requestInput !== "")
                write(root.requestInput)
            root.requestInput = ""
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let success = false
                try {
                    success = root.acceptResponse(text)
                } catch (error) {
                    root.error = "Could not read network information."
                    console.warn(root.error, error)
                }
                if (root.activeAction[0] === "join") {
                    const ssid = root.activeAction[1]
                    if (success)
                        root.failedSsids = root.failedSsids.filter(item => item !== ssid)
                    else if (!root.failedSsids.includes(ssid))
                        root.failedSsids = [...root.failedSsids, ssid]
                    root.joinFinished(ssid, success)
                }
            }
        }
        // Quickshell qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.activeAction = []
            root.requestInput = ""
            Qt.callLater(root.nextRequest)
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        interval: 5000
        running: root.viewers.length > 0 && root.editors.length === 0
        repeat: true
        onTriggered: root.refresh()
    }
}
