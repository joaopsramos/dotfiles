import QtQuick
import Quickshell.Io
import qs.services as Services
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property string outputIcon: "󰓃"
    readonly property var sink: Services.Audio.sink
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 360
    implicitWidth: modules.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : Theme.barHeight

    Process {
        id: settingsProcess
        command: ["pavucontrol"]
    }

    function openPopup() {
        popupHover.open()
    }
    PopupHover {
        id: popupHover
        triggerHovered: barHover.hovered
        popupHovered: popupClient.hovered
        available: !!root.parentWindow && root.visible
        onOpenRequested: root.popupOpen = true
        onCloseRequested: root.popupOpen = false
    }
    HoverHandler {
        id: barHover
    }
    PopupFrame {
        anchors.fill: parent
        visible: root.popupVisible
    }
    Row {
        id: modules
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing
        BarModuleWrapper {
            horizontalPadding: Theme.moduleHorizontalPadding
            verticalPadding: Theme.moduleVerticalPadding
            moduleColor: root.popupVisible ? Theme.transparent : Theme.base
            mouseEnabled: true
            onClicked: Services.Audio.cycleSink()
            BarText {
                text: root.outputIcon
                color: Theme.soundOutput
                font.pixelSize: 18
                transform: Translate {
                    y: -1
                }
            }
        }
        BarModuleWrapper {
            horizontalPadding: 14
            verticalPadding: Theme.moduleVerticalPadding
            moduleColor: root.popupVisible ? Theme.transparent : Theme.base
            mouseEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onWheel: wheel => {
                if (!root.sink?.audio)
                    return
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                if (delta === 0)
                    return
                root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (delta > 0 ? 0.01 : -0.01)))
                wheel.accepted = true
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    settingsProcess.running = true
                else if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted
            }
            Row {
                spacing: Theme.spacing
                BarText {
                    property bool muted: !root.sink?.audio || root.sink.audio.muted
                    text: muted ? "󰝟" : root.sink.audio.volume < 0.34 ? "" : root.sink.audio.volume < 0.67 ? "" : ""
                    color: muted ? Theme.red : Theme.volume
                    transform: Translate {
                        y: 0
                    }
                }
                BarText {
                    text: !root.sink?.audio || root.sink.audio.muted ? "" : Math.round(root.sink.audio.volume * 100) + "%"
                    color: Theme.volume
                }
                BarText {
                    visible: Services.Audio.source?.audio?.muted ?? false
                    text: ""
                    color: Theme.overlay1
                    leftPadding: 2
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
        AudioPanel {
            id: content
            onSettings: {
                root.popupOpen = false
                settingsProcess.running = true
            }
        }
    }
}
