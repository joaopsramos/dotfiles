import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs
import qs.services as Services
import ".."

Item {
    id: root
    property var parentWindow: null
    readonly property var backend: Services.Network
    readonly property var network: backend.network
    readonly property bool networkReady: backend.ready
    property var fallback: ({
            kind: "unknown",
            name: ""
        })
    readonly property bool passwordEditing: popupVisible && panel.passwordSsid !== ""
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property string error: backend.error
    readonly property var connectingUuids: backend.connectingUuids
    readonly property bool scanning: backend.scanning
    readonly property bool turningOn: backend.turningOn
    readonly property string connectingSsid: backend.connectingSsid
    readonly property var failedSsids: backend.failedSsids
    readonly property string kind: fallback.kind
    property string joiningSsid: ""
    onPopupOpenChanged: {
        if (!popupOpen)
            panel.passwordSsid = ""
        backend.setViewer(root, popupOpen)
    }
    onPasswordEditingChanged: backend.setEditor(root, passwordEditing)
    Component.onDestruction: {
        backend.setViewer(root, false)
        backend.setEditor(root, false)
    }
    implicitWidth: icon.implicitWidth + 24
    implicitHeight: parentWindow ? parentWindow.height : Theme.barHeight

    function openPopup() {
        popupHover.open()
    }
    function settings() {
        popupOpen = false
        settingsProcess.running = true
    }
    function joinNetwork(entry, password) {
        if (backend.joinNetwork(entry, password))
            joiningSsid = entry.ssid
    }
    Process {
        id: settingsProcess
        command: ["kitty", "nmtui"]
    }
    Connections {
        target: root.backend
        function onJoinFinished(ssid, success) {
            if (ssid !== root.joiningSsid)
                return
            if (success)
                panel.passwordSsid = ""
            else if (root.popupOpen)
                panel.passwordSsid = ssid
            root.joiningSsid = ""
        }
    }
    PopupHover {
        id: popupHover
        triggerHovered: barMouse.containsMouse
        popupHovered: popupClient.hovered
        available: !!root.parentWindow && root.visible
        onOpenRequested: root.popupOpen = true
        onCloseRequested: root.popupOpen = false
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: root.height
        radius: Theme.radius
        color: Theme.base
        visible: !root.popupVisible
    }
    PopupFrame {
        anchors.fill: parent
        visible: root.popupVisible
    }
    NetworkIcon {
        id: icon
        anchors.centerIn: parent
        kind: root.kind === "unknown" ? "ethernet" : root.kind
        signalStrength: root.fallback.signal ?? -1
        color: root.kind === "down" ? Theme.red : root.kind === "unknown" ? Theme.overlay1 : Theme.network
    }
    MouseArea {
        id: barMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        ToolTip.visible: containsMouse && (Services.Status.error !== "" || !!Services.Status.errors.network)
        ToolTip.text: Services.Status.error || Services.Status.errors.network || ""
        ToolTip.delay: 500
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.settings()
            else
                root.openPopup()
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
            onAction: arguments => root.backend.runAction(arguments)
            onSettings: root.settings()
            onJoinNetwork: (entry, password) => root.joinNetwork(entry, password)
        }
    }
}
