pragma ComponentBehavior: Bound

import QtQuick
import qs
import "../system" as SystemWidgets

Column {
    id: root
    property var snapshot: ({ root: {}, volumes: [], devices: [] })
    property real fallback: 0
    property string error: ""
    readonly property var disk: snapshot.root || ({})
    spacing: 12

    function size(bytes) {
        if (bytes == null) return "—"
        const unit = bytes >= 1099511627776 ? 1099511627776 : bytes >= 1073741824 ? 1073741824 : 1048576
        return (bytes / unit).toFixed(1) + (unit === 1099511627776 ? " TiB" : unit === 1073741824 ? " GiB" : " MiB")
    }
    function accent(value) { return value >= 90 ? Theme.red : value >= 80 ? Theme.yellow : Theme.disk }

    Column {
        width: parent.width; spacing: 6
        Text {
            text: "Storage"
            color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            text: root.disk.source ? root.disk.source + " · " + root.disk.filesystem : "Local disks and filesystems"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.subtext0
            font.family: Theme.fontFamily; font.pixelSize: 11
        }
    }
    Rectangle {
        width: parent.width; height: 160; radius: Theme.radius
        color: Theme.mantle
        SystemWidgets.UsageGauge {
            x: 8; anchors.verticalCenter: parent.verticalCenter
            label: "ROOT /"
            value: root.disk.usage ?? root.fallback
            accent: Theme.disk
        }
        Column {
            x: 158; width: parent.width - x - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Detail { label: "In use"; value: root.size(root.disk.used); accent: Theme.disk }
            Detail { label: "Available"; value: root.size(root.disk.available); accent: Theme.green }
            Detail { label: "Total"; value: root.size(root.disk.total) }
            Detail { visible: root.disk.reserved > 0; label: "Reserved"; value: root.size(root.disk.reserved) }
        }
    }

    Text {
        visible: (root.snapshot.devices || []).length > 0
        text: "Drives"
        color: Theme.subtext0
        font.family: Theme.fontFamily; font.pixelSize: 12
    }
    Repeater {
        model: root.snapshot.devices || []
        Rectangle {
            id: drive
            required property var modelData
            width: root.width; height: 76; radius: Theme.radius
            color: Theme.mantle
            Column {
                x: 12; y: 12; width: parent.width - 24; spacing: 10
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - temperature.width - 8
                        text: "  " + drive.modelData.model
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 12
                    }
                    Text {
                        id: temperature
                        text: drive.modelData.temperature != null ? Math.round(drive.modelData.temperature) + "°C" : "—"
                        color: drive.modelData.temperature >= 70 ? Theme.red : Theme.disk
                        font.family: Theme.fontFamily; font.pixelSize: 13
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        width: parent.width * 0.65
                        text: drive.modelData.kind + " · /dev/" + drive.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.subtext0
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                    Text {
                        width: parent.width * 0.35
                        text: root.size(drive.modelData.size)
                        horizontalAlignment: Text.AlignRight
                        color: Theme.subtext0
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                }
            }
        }
    }

    Text {
        text: "Mounted filesystems"
        color: Theme.subtext0
        font.family: Theme.fontFamily; font.pixelSize: 12
    }
    Repeater {
        model: root.snapshot.volumes || []
        Rectangle {
            id: volume
            required property var modelData
            width: root.width
            height: volumeContent.implicitHeight + 24
            radius: Theme.radius
            color: Theme.mantle
            Column {
                id: volumeContent
                x: 12; y: 12; width: parent.width - 24; spacing: 9
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - percent.width - 12
                        text: volume.modelData.mountpoints.join(" · ")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    Text {
                        id: percent
                        text: Math.round(volume.modelData.usage) + "%"
                        color: root.accent(volume.modelData.usage)
                        font.family: Theme.fontFamily; font.pixelSize: 13
                    }
                }
                Text {
                    width: parent.width
                    text: volume.modelData.source + " · " + volume.modelData.filesystem.toUpperCase()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.overlay1
                    font.family: Theme.fontFamily; font.pixelSize: 11
                }
                Rectangle {
                    width: parent.width; height: 6; radius: 3
                    color: Theme.surface0
                    Rectangle {
                        width: parent.width * volume.modelData.usage / 100
                        height: parent.height; radius: 3
                        color: root.accent(volume.modelData.usage)
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        width: parent.width / 2
                        text: root.size(volume.modelData.used) + " used"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                    Text {
                        width: parent.width / 2
                        text: root.size(volume.modelData.available) + " free"
                        horizontalAlignment: Text.AlignRight
                        color: Theme.green
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                }
            }
        }
    }
    Text {
        width: parent.width
        visible: root.error.length > 0
        text: root.error
        wrapMode: Text.Wrap
        color: Theme.red
        font.family: Theme.fontFamily; font.pixelSize: 11
    }

    component Detail: Row {
        property string label
        property string value
        property color accent: Theme.text
        width: parent.width
        Text { width: parent.width * 0.43; text: parent.label; color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: 12 }
        Text { width: parent.width * 0.57; text: parent.value; horizontalAlignment: Text.AlignRight; color: parent.accent; font.family: Theme.fontFamily; font.pixelSize: 13 }
    }
}
