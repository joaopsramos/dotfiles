import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property var fallback: ({ value: -1, charging: false })
    property var snapshot: ({ battery: {}, profiles: [], activeProfile: "" })
    property string error: ""
    visible: fallback.value >= 0
    onVisibleChanged: { if (!visible) popupOpen = false }
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 360
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : 34

    function refresh() {
        if (!request.running) {
            request.command = ["python3", Quickshell.shellPath("bar/battery/battery.py")]
            request.running = true
        }
    }
    Process {
        id: request
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) root.snapshot = response.data
                    else if (root.popupOpen) root.error = response.error
                } catch (error) {
                    if (root.popupOpen) root.error = "Could not read battery information."
                }
            }
        }
    }
    Timer { interval: 10000; running: root.popupOpen; repeat: true; onTriggered: root.refresh() }
    onPopupOpenChanged: { if (!popupOpen) error = "" }
    function openPopup() {
        if (!parentWindow || !visible) return
        closeDelay.stop()
        popupOpen = true
        refresh()
    }
    Timer { id: openDelay; interval: 150; onTriggered: root.openPopup() }
    Timer {
        id: closeDelay
        interval: 300
        onTriggered: { if (!barHover.hovered && !popupClient.hovered) root.popupOpen = false }
    }
    HoverHandler {
        id: barHover
        onHoveredChanged: {
            if (hovered) { closeDelay.stop(); openDelay.restart() }
            else { openDelay.stop(); closeDelay.restart() }
        }
    }
    Shape {
        id: frame
        anchors.fill: parent
        visible: root.popupVisible
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.base; strokeColor: Theme.surface1; strokeWidth: Theme.borderWidth
            capStyle: ShapePath.FlatCap
            PathSvg {
                path: "M 0.5 " + frame.height + " L 0.5 8.5 Q 0.5 0.5 8.5 0.5 L "
                    + (frame.width - 8.5) + " 0.5 Q " + (frame.width - 0.5) + " 0.5 "
                    + (frame.width - 0.5) + " 8.5 L " + (frame.width - 0.5) + " " + frame.height
            }
        }
    }
    BarModuleWrapper {
        id: module
        anchors.centerIn: parent
        horizontalPadding: 12; verticalPadding: 6
        moduleColor: root.popupVisible ? "transparent" : Theme.base
        mouseEnabled: true
        onClicked: root.openPopup()
        Row {
            id: batteryRow
            spacing: 8
            BarText {
                id: batteryIcon
                property var icons: ["󱉞", "󰁺", "󰁼", "󰁾", "󰂀", "󰂂", "󰁹"]
                property var chargingIcons: ["󰢟", "󰢜", "󰂇", "󰢝", "󰢞", "󰂋", "󰂅"]
                property int chargeIndex: Math.min(6, Math.max(0, Math.floor(root.fallback.value / (100 / 7))))
                text: root.fallback.charging ? chargingIcons[chargeIndex] : icons[chargeIndex]
                font.pixelSize: 16
                color: root.fallback.charging ? Theme.green : root.fallback.value <= 15 ? Theme.red : root.fallback.value <= 30 ? Theme.yellow : Theme.text
            }
            BarText { text: root.fallback.value + "%"; color: batteryIcon.color; y: (batteryRow.height - implicitHeight) / 2 }
        }
    }
    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: root.popupWidth
        opened: root.popupOpen
        contentItem: content
        onDismissed: root.popupOpen = false
        onHoveredChanged: { if (hovered) closeDelay.stop(); else closeDelay.restart() }
        BatteryPanel {
            id: content
            details: root.snapshot.battery
            fallback: root.fallback
            profiles: root.snapshot.profiles
            activeProfile: root.snapshot.activeProfile
            error: root.error
            onSelectProfile: profile => {
                if (request.running) return
                request.command = ["python3", Quickshell.shellPath("bar/battery/battery.py"), "profile", profile]
                request.running = true
            }
        }
    }
}
