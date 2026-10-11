pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import qs
import qs.services as Services
import qs.components

Column {
    id: root
    readonly property var backend: Services.Bluetooth
    readonly property var bluetooth: backend.state
    readonly property var saved: bluetooth.devices.filter(device => device.paired || device.connected)
    readonly property var nearby: bluetooth.devices.filter(device => !device.paired && !device.connected)
    spacing: 12

    function deviceIcon(icon) {
        if (icon.includes("headset") || icon.includes("headphone"))
            return "󰋋"
        if (icon.includes("audio"))
            return "󰓃"
        if (icon.includes("mouse"))
            return "󰍽"
        if (icon.includes("keyboard"))
            return "󰌌"
        if (icon.includes("phone"))
            return "󰏲"
        if (icon.includes("computer"))
            return "󰍹"
        if (icon.includes("game"))
            return "󰊴"
        return "󰂯"
    }
    Row {
        width: parent.width
        Text {
            width: parent.width - power.width
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.headingFontSize
            font.weight: Font.DemiBold
        }
        ThemedButton {
            id: power
            text: root.bluetooth.enabled ? "Turn off" : "Turn on"
            backgroundColor: root.bluetooth.enabled ? Theme.red : Theme.green
            textColor: Theme.base
            enabled: root.backend.ready && !!root.bluetooth.adapter && !root.backend.busy
            onClicked: root.backend.runAction(["power", root.bluetooth.enabled ? "false" : "true"])
        }
    }
    Text {
        width: parent.width
        text: !root.backend.ready ? (root.backend.error ? "Bluetooth unavailable" : "Looking for Bluetooth adapters…") : !root.bluetooth.adapter ? "No Bluetooth adapter found" : root.bluetooth.enabled ? root.bluetooth.name : "Bluetooth is turned off"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }
    Column {
        width: parent.width
        spacing: 10
        visible: root.bluetooth.enabled
        Text {
            text: "Connected & saved"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: ScriptModel {
                    values: root.saved
                    objectProp: "path"
                }
                DeviceRow {
                    required property var modelData
                    device: modelData
                    width: root.width
                }
            }
        }
        Text {
            visible: root.saved.length === 0
            text: "No saved devices"
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
        Row {
            width: parent.width
            Text {
                width: parent.width - scan.width
                height: scan.height
                text: "Nearby devices"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                verticalAlignment: Text.AlignVCenter
            }
            ThemedButton {
                horizontalAlignment: Text.AlignLeft
                textFormat: Text.PlainText
                id: scan
                text: "Scan"
                loading: root.backend.scanning
                enabled: !root.backend.scanning && !root.backend.busy
                onClicked: root.backend.runAction(["scan"])
            }
        }
        Flickable {
            width: parent.width
            height: Math.min(contentHeight, 230)
            contentWidth: width
            contentHeight: nearbyList.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: nearbyList
                width: parent.width
                spacing: 6
                Repeater {
                    model: ScriptModel {
                        values: root.nearby
                        objectProp: "path"
                    }
                    DeviceRow {
                        required property var modelData
                        device: modelData
                        width: root.width
                    }
                }
            }
        }
        Text {
            visible: root.nearby.length === 0
            width: parent.width
            text: "Scan to find devices. Make sure they are in pairing mode."
            wrapMode: Text.Wrap
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
    }
    Text {
        width: parent.width
        visible: root.backend.error !== ""
        text: root.backend.error
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }

    component DeviceRow: Row {
        id: row
        required property var device
        readonly property bool working: root.backend.action[1] === device.path
        spacing: 6
        Rectangle {
            width: parent.width - (forget.visible ? forget.width + parent.spacing : 0)
            height: 66
            radius: Theme.radius
            color: mouse.containsMouse ? Theme.surface0 : Theme.mantle
            opacity: row.working ? 0.55 : 1
            Text {
                x: 10
                width: 28
                height: parent.height
                text: row.working ? "" : root.deviceIcon(row.device.icon)
                color: row.device.connected ? Theme.blue : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: 20
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: row.working
                }
                onTextChanged: rotation = 0
            }
            Column {
                x: 48
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 10
                spacing: 5
                Text {
                    width: parent.width
                    text: row.device.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.bodyFontSize
                }
                Text {
                    width: parent.width
                    text: (row.device.connected ? "Connected · click to disconnect" : row.device.paired ? "Saved · click to connect" : "Click to pair & connect") + (row.device.battery != null ? " · " + row.device.battery + "%" : "")
                    elide: Text.ElideRight
                    color: row.device.connected ? Theme.blue : Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.captionFontSize
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !root.backend.busy
                onClicked: root.backend.runAction([row.device.connected ? "disconnect" : row.device.paired ? "connect" : "pair", row.device.path])
            }
        }
        ToolButton {
            id: forget
            HoverHandler {
                enabled: forget.enabled
                cursorShape: Qt.PointingHandCursor
            }
            width: 28
            height: 66
            visible: row.device.paired
            enabled: !root.backend.busy
            ToolTip.visible: hovered
            ToolTip.text: "Forget device"
            contentItem: Text {
                text: "󰆴"
                color: forget.hovered ? Theme.red : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Item {}
            onClicked: root.backend.runAction(["forget", row.device.path])
        }
    }
}
