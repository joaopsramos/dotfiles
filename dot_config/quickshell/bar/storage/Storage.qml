import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property real usage: 0
    property var snapshot: ({ root: {}, volumes: [], devices: [] })
    property string error: ""
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 440
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : 34

    function refresh() {
        if (!request.running) {
            request.command = ["python3", Quickshell.shellPath("bar/storage/storage.py")]
            request.running = true
        }
    }
    Process {
        id: request
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) { root.snapshot = response.data; root.error = "" }
                    else if (root.popupOpen) root.error = response.error
                } catch (error) {
                    if (root.popupOpen) root.error = "Could not read storage information."
                }
            }
        }
    }
    Timer { interval: 5000; running: root.popupOpen; repeat: true; onTriggered: root.refresh() }
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
        BarText { text: "  " + root.usage + "%"; color: Theme.disk }
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
        StoragePanel {
            id: content
            snapshot: root.snapshot
            fallback: root.usage
            error: root.error
        }
    }
}
