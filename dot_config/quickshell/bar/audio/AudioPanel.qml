pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services as Services

Column {
    id: root
    readonly property var sink: Services.Audio.sink
    readonly property var source: Services.Audio.source
    readonly property var outputs: Services.Audio.devices.filter(node => node.isSink)
    readonly property var inputs: Services.Audio.devices.filter(node => !node.isSink)
    signal settings
    spacing: 12

    Text {
        text: "Audio"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.headingFontSize
        font.weight: Font.DemiBold
    }
    AudioLevel {
        width: parent.width
        node: root.sink
        label: "Output"
    }
    Column {
        width: parent.width
        spacing: 10
        visible: Services.Audio.playbackNodes.length > 0
        Text {
            text: "Applications"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
        Flickable {
            width: parent.width
            height: Math.min(contentHeight, 220)
            contentHeight: applications.height
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: applications
                width: parent.width
                spacing: 12
                Repeater {
                    model: ScriptModel {
                        values: Services.Audio.playbackNodes
                        objectProp: "id"
                    }
                    delegate: AudioLevel {
                        required property var modelData
                        width: applications.width
                        node: modelData
                        label: modelData.properties["application.name"] || modelData.description || modelData.name || "Unknown application"
                        showDescription: false
                        showIcon: true
                        iconSource: Services.Audio.applicationIcon(modelData)
                    }
                }
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }
    Text {
        text: "Output device"
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }
    Rectangle {
        width: parent.width
        height: outputDevices.implicitHeight + 8
        visible: root.outputs.length > 0
        radius: Theme.radius
        color: Theme.mantle
        Column {
            id: outputDevices
            x: 4
            y: 4
            width: parent.width - 8
            spacing: 4
    Repeater {
        model: ScriptModel {
            values: root.outputs
            objectProp: "id"
        }
        delegate: DeviceRow {
            required property var modelData
            width: outputDevices.width
            node: modelData
            selected: root.sink === modelData
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
        }
    }
    Text {
        visible: root.outputs.length === 0
        text: "No output devices"
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }
    AudioLevel {
        width: parent.width
        node: root.source
        label: "Microphone"
        accent: Theme.sapphire
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }
    Text {
        text: "Input device"
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }
    Rectangle {
        width: parent.width
        height: inputDevices.implicitHeight + 8
        visible: root.inputs.length > 0
        radius: Theme.radius
        color: Theme.mantle
        Column {
            id: inputDevices
            x: 4
            y: 4
            width: parent.width - 8
            spacing: 4
        Repeater {
            model: ScriptModel {
                values: root.inputs
                objectProp: "id"
            }
            delegate: DeviceRow {
                required property var modelData
                width: inputDevices.width
                node: modelData
                selected: root.source === modelData
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }
        }
    ThemedButton {
        anchors.right: parent.right
        horizontalAlignment: Text.AlignLeft
        text: "Audio settings"
        onClicked: root.settings()
    }

    component DeviceRow: Rectangle {
        id: device
        property var node
        property bool selected: false
        signal clicked
        height: 38
        radius: 7
        color: selected ? Theme.surface0 : mouse.containsMouse ? Theme.surface1 : Theme.transparent
        Text {
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 38
            text: device.node.description || device.node.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: device.selected ? "" : ""
            color: Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: 18
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
