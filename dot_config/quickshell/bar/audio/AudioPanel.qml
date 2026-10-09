pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs

Column {
    id: root
    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource
    property var outputs: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
    property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream)
    signal settings()
    spacing: 12

    Text { text: "Audio"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold }
    AudioLevel { width: parent.width; node: root.sink; label: "Output" }
    Rectangle { width: parent.width; height: 1; color: Theme.surface0 }
    Text { text: "Output device"; color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: 11 }
    Repeater {
        model: root.outputs
        delegate: DeviceRow {
            required property var modelData
            width: root.width
            node: modelData
            selected: root.sink === modelData
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    Text {
        visible: root.outputs.length === 0
        text: "No output devices"
        color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: 11
    }
    Rectangle { width: parent.width; height: 1; color: Theme.surface0 }
    AudioLevel { width: parent.width; node: root.source; label: "Microphone"; accent: Theme.sapphire }
    Column {
        width: parent.width
        spacing: 4
        visible: root.inputs.length > 1
        Repeater {
            model: root.inputs
            delegate: DeviceRow {
                required property var modelData
                width: root.width
                node: modelData
                selected: root.source === modelData
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }
    AudioButton { text: "Audio settings"; onClicked: root.settings() }

    component DeviceRow: Rectangle {
        id: device
        property var node
        property bool selected: false
        signal clicked()
        height: 38
        radius: 7
        color: selected ? Theme.surface0 : mouse.containsMouse ? Theme.mantle : "transparent"
        Text {
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 38
            text: device.node.description || device.node.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: device.selected ? "✓" : ""
            color: Theme.green
            font.family: Theme.fontFamily; font.pixelSize: 12
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: device.clicked()
        }
    }
}
