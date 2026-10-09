import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property string outputIcon: "󰓃"
    property var sink: Pipewire.defaultAudioSink
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 360
    implicitWidth: modules.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : 34

    PwObjectTracker { objects: Pipewire.nodes.values.filter(node => node.audio && !node.isStream) }
    Process { id: settingsProcess; command: ["pavucontrol"] }

    function openPopup() {
        if (!parentWindow) return
        closeDelay.stop()
        popupOpen = true
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
    Row {
        id: modules
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        BarModuleWrapper {
            horizontalPadding: 12; verticalPadding: 6
            moduleColor: root.popupVisible ? "transparent" : Theme.base
            mouseEnabled: true
            onClicked: root.openPopup()
            BarText { text: root.outputIcon; color: Theme.soundOutput; font.pixelSize: 18 }
        }
        BarModuleWrapper {
            horizontalPadding: 14; verticalPadding: 6
            moduleColor: root.popupVisible ? "transparent" : Theme.base
            mouseEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onWheel: wheel => {
                if (!root.sink?.audio) return
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                if (delta === 0) return
                root.sink.audio.volume = Math.max(0, Math.min(1,
                    root.sink.audio.volume + (delta > 0 ? 0.01 : -0.01)))
                wheel.accepted = true
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) settingsProcess.running = true
                else if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
            Row {
                spacing: 8
                BarText {
                    property bool muted: !root.sink?.audio || root.sink.audio.muted
                    text: muted ? "󰝟" : root.sink.audio.volume < 0.34 ? "" : root.sink.audio.volume < 0.67 ? "" : ""
                    color: muted ? Theme.red : Theme.volume
                }
                BarText {
                    text: !root.sink?.audio || root.sink.audio.muted ? "" : Math.round(root.sink.audio.volume * 100) + "%"
                    color: Theme.volume
                }
            }
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
        AudioPanel {
            id: content
            onSettings: { root.popupOpen = false; settingsProcess.running = true }
        }
    }
}
