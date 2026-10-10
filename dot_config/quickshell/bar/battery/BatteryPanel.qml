pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs

Column {
    id: root
    property var details: ({})
    property var fallback: ({
            value: -1,
            charging: false
        })
    property var profiles: []
    property string activeProfile: ""
    property string error: ""
    signal selectProfile(string profile)
    readonly property real charge: details.value ?? fallback.value
    readonly property string chargeState: details.state || (fallback.charging ? "Charging" : "Discharging")
    readonly property color accent: chargeState === "Charging" || chargeState === "Full" ? Theme.green : charge <= 15 ? Theme.red : charge <= 30 ? Theme.yellow : Theme.text
    spacing: 12

    function timeLabel(seconds) {
        const minutes = Math.max(1, Math.round(seconds / 60))
        const hours = Math.floor(minutes / 60)
        return (hours ? hours + "h " : "") + (minutes % 60 || !hours ? minutes % 60 + "m" : "")
    }
    Text {
        text: "Battery"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.headingFontSize
        font.weight: Font.DemiBold
    }
    Row {
        width: parent.width
        spacing: 12
        Text {
            text: root.charge >= 0 ? Math.round(root.charge) + "%" : "—"
            color: root.accent
            font.family: Theme.fontFamily
            font.pixelSize: 30
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                text: root.chargeState === "Full" ? "Fully charged" : root.chargeState === "Not charging" ? "Plugged in · Not charging" : root.chargeState
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
            }
            Text {
                visible: root.chargeState === "Charging" || root.chargeState === "Discharging"
                text: root.details.remaining > 0 ? root.timeLabel(root.details.remaining) + (root.chargeState === "Charging" ? " until full" : " remaining") : "Estimating time…"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface0
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.charge)) / 100
            height: parent.height
            radius: 3
            color: root.accent
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }
    Detail {
        label: "Battery health"
        value: root.details.health != null ? root.details.health.toFixed(1) + "%" : "Unavailable"
    }
    Detail {
        label: root.chargeState === "Charging" ? "Charging power" : "Power draw"
        value: root.details.power != null ? root.details.power.toFixed(1) + " W" : "Unavailable"
    }
    Detail {
        label: "Energy"
        value: root.details.energy != null && root.details.full != null ? root.details.energy.toFixed(1) + " / " + root.details.full.toFixed(1) + " Wh" : "Unavailable"
    }
    Detail {
        label: "Charge cycles"
        value: root.details.cycles != null ? String(root.details.cycles) : "Unavailable"
    }
    Column {
        width: parent.width
        spacing: Theme.spacing
        visible: root.profiles.length > 0
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surface0
        }
        Text {
            text: "Power profile"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
        Row {
            spacing: 6
            Repeater {
                model: root.profiles
                delegate: Button {
                    id: button
                    HoverHandler {
                        enabled: button.enabled
                        cursorShape: Qt.PointingHandCursor
                    }
                    required property string modelData
                    readonly property bool selected: root.activeProfile === modelData
                    text: modelData === "power-saver" ? "Power saver" : modelData === "balanced" ? "Balanced" : "Performance"
                    implicitHeight: 30
                    leftPadding: 8
                    rightPadding: 8
                    onClicked: root.selectProfile(modelData)
                    contentItem: Text {
                        text: button.text
                        color: button.selected ? Theme.mauve : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.captionFontSize
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: button.hovered ? Theme.surface0 : Theme.mantle
                        border.color: button.selected ? Theme.mauve : Theme.surface0
                    }
                }
            }
        }
    }
    Text {
        width: parent.width
        visible: root.error !== ""
        text: root.error
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }
    component Detail: Row {
        property string label
        property string value
        width: root.width
        Text {
            width: parent.width * 0.5
            text: parent.label
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
        Text {
            width: parent.width * 0.5
            text: parent.value
            horizontalAlignment: Text.AlignRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
    }
}
