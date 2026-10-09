import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Item {
    id: root

    property var sink: Pipewire.defaultAudioSink

    implicitWidth: module.implicitWidth
    implicitHeight: module.implicitHeight

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Process {
        id: audioSettings
        command: ["pavucontrol", "-t", "3"]
    }

    BarModuleWrapper {
        id: module
        horizontalPadding: 14
        verticalPadding: 6
        mouseEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                audioSettings.running = true
            } else if (root.sink?.audio) {
                root.sink.audio.muted = !root.sink.audio.muted
            }
        }

        Row {
            spacing: 8
            BarText {
                property bool muted: !root.sink || !root.sink.audio || root.sink.audio.muted
                text: muted ? "󰝟" : root.sink.audio.volume < 0.34 ? "" : root.sink.audio.volume < 0.67 ? "" : ""
                color: muted ? Theme.red : Theme.volume
            }
            BarText {
                text: !root.sink || !root.sink.audio || root.sink.audio.muted ? "" : Math.round(root.sink.audio.volume * 100) + "%"
                color: Theme.volume
            }
        }

    }
}
