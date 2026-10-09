import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property var network: ({ enabled: false, device: "", current: { name: "Not connected", kind: "down", device: "", address: "", gateway: "", signal: -1 }, networks: [], profiles: [] })
    property bool networkReady: false
    property var fallback: ({ kind: "down", name: "" })
    readonly property bool passwordEditing: popupVisible && panel.passwordSsid !== ""
    property bool popupOpen: false
    onPopupOpenChanged: {
        if (!popupOpen) {
            panel.passwordSsid = ""
            error = ""
        }
    }
    readonly property bool popupVisible: popupClient.presented
    property string error: ""
    property var pendingActions: []
    property var activeAction: []
    property string connectingSsid: ""
    property string connectionInput: ""
    property var failedSsids: []
    property string joiningSsid: ""
    readonly property var connectingUuids: [activeAction].concat(pendingActions)
        .filter(action => action[0] === "connect").map(action => action[1])
    readonly property bool scanning: [activeAction].concat(pendingActions)
        .some(action => action[0] === "scan" || (action[0] === "radio" && action[1] === "on"))
    readonly property bool turningOn: [activeAction].concat(pendingActions)
        .some(action => action[0] === "radio" && action[1] === "on")
    readonly property string kind: fallback.kind
    implicitWidth: icon.implicitWidth + 24
    implicitHeight: parentWindow ? parentWindow.height : 34

    function refresh() {
        if (!request.running) startRequest(["status"])
    }

    function runAction(arguments) {
        if (request.running)
            pendingActions = pendingActions.concat([arguments])
        else
            startRequest(arguments)
        if (arguments[0] === "radio" && arguments[1] === "on" && network.device)
            pendingActions = pendingActions.concat([["scan", network.device]])
    }

    function startRequest(arguments) {
        activeAction = arguments
        request.command = ["python3", Quickshell.shellPath("bar/network/network.py")].concat(arguments)
        request.running = true
    }

    function openPopup() {
        if (!parentWindow) return
        closeDelay.stop()
        popupOpen = true
        refresh()
    }

    function settings() {
        popupOpen = false
        settingsProcess.running = true
    }

    Process {
        id: request
        // Quickshell qmltypes omit QProcess::ExitStatus; this handler uses no arguments.
        // qmllint disable signal-handler-parameters
        onExited: () => {
        // qmllint enable signal-handler-parameters
            root.activeAction = []
            if (root.pendingActions.length > 0) {
                const next = root.pendingActions[0]
                root.pendingActions = root.pendingActions.slice(1)
                root.startRequest(next)
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.network = response.data
                        root.networkReady = true
                    } else if (root.popupOpen) root.error = response.error
                } catch (error) {
                    if (root.popupOpen) root.error = "Could not read network information."
                }
            }
        }
    }
    Process { id: settingsProcess; command: ["kitty", "nmtui"] }
    function joinNetwork(entry, password) {
        if (connectProcess.running) return
        joiningSsid = entry.ssid
        connectingSsid = entry.ssid
        connectionInput = JSON.stringify({ password: password }) + "\n"
        connectProcess.command = ["python3", Quickshell.shellPath("bar/network/network.py"), "join", entry.ssid, network.device, entry.uuid || ""]
        connectProcess.running = true
    }
    Process {
        id: connectProcess
        stdinEnabled: true
        onStarted: {
            write(root.connectionInput)
            root.connectionInput = ""
        }
        // Quickshell qmltypes omit QProcess::ExitStatus; this handler uses no arguments.
        // qmllint disable signal-handler-parameters
        onExited: () => {
        // qmllint enable signal-handler-parameters
            root.connectingSsid = ""
            root.refresh()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.network = response.data
                        root.networkReady = true
                        root.failedSsids = root.failedSsids.filter(ssid => ssid !== root.joiningSsid)
                        panel.passwordSsid = ""
                    } else {
                        if (!root.failedSsids.includes(root.joiningSsid))
                            root.failedSsids = root.failedSsids.concat([root.joiningSsid])
                        if (root.popupOpen) {
                            root.error = response.error
                            panel.passwordSsid = root.joiningSsid
                        }
                    }
                } catch (error) {
                    if (root.popupOpen) root.error = "Could not connect to the network."
                }
            }
        }
    }
    Timer {
        interval: root.popupOpen ? 5000 : 15000
        running: panel.passwordSsid === ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        id: openDelay
        interval: 150
        onTriggered: root.openPopup()
    }
    Timer {
        id: closeDelay
        interval: 300
        onTriggered: {
            if (!barMouse.containsMouse && !popupClient.hovered)
                root.popupOpen = false
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: icon.implicitHeight + 12
        radius: Theme.radius
        color: Theme.base
        visible: !root.popupVisible
    }
    Shape {
        id: frame
        anchors.fill: parent
        visible: root.popupVisible
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.base
            strokeColor: Theme.surface1
            strokeWidth: Theme.borderWidth
            capStyle: ShapePath.FlatCap
            PathSvg {
                path: "M 0.5 " + frame.height
                    + " L 0.5 8.5 Q 0.5 0.5 8.5 0.5"
                    + " L " + (frame.width - 8.5) + " 0.5"
                    + " Q " + (frame.width - 0.5) + " 0.5 " + (frame.width - 0.5) + " 8.5"
                    + " L " + (frame.width - 0.5) + " " + frame.height
            }
        }
    }
    BarText {
        id: icon
        anchors.centerIn: parent
        text: root.kind === "wifi" ? "" : root.kind === "ethernet" ? "󰒢" : "󰞃"
        color: root.kind === "down" ? Theme.red : Theme.network
    }
    MouseArea {
        id: barMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: { closeDelay.stop(); openDelay.restart() }
        // Quickshell qmltypes omit QProcess::ExitStatus; this handler uses no arguments.
        // qmllint disable signal-handler-parameters
        onExited: () => { openDelay.stop(); closeDelay.restart() }
        // qmllint enable signal-handler-parameters
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.settings()
            else root.openPopup()
        }
    }

    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: 360
        opened: root.popupOpen
        keyboardFocus: root.passwordEditing
        contentItem: panel
        onDismissed: root.popupOpen = false
        onHoveredChanged: { if (hovered) closeDelay.stop(); else closeDelay.restart() }
        NetworkPanel {
            id: panel
            network: root.network
            networkReady: root.networkReady
            error: root.error
            scanning: root.scanning
            turningOn: root.turningOn
            connectingUuids: root.connectingUuids
            connectingSsid: root.connectingSsid
            failedSsids: root.failedSsids
            onAction: arguments => root.runAction(arguments)
            onSettings: root.settings()
            onJoinNetwork: (entry, password) => root.joinNetwork(entry, password)
        }
    }
}
