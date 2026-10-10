import QtQuick
import qs

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property real value: 0
    property bool muted: false
    property bool showProgress: true
    property color accent: Theme.volume
    implicitWidth: 300
    implicitHeight: showProgress ? 84 : 64
    radius: 16
    color: Theme.base
    border.width: Theme.borderWidth
    border.color: Theme.surface1

    Text {
        x: 18
        width: 34
        height: parent.height
        text: root.icon
        color: root.muted ? Theme.red : root.accent
        font.family: Theme.fontFamily
        font.pixelSize: 26
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
    Column {
        x: 68
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 20
        spacing: 12
        Row {
            width: parent.width
            Text {
                width: parent.width - amount.width
                text: root.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
            Text {
                id: amount
                text: root.muted ? "Muted" : root.showProgress ? Math.round(root.value * 100) + "%" : "Unmuted"
                color: root.muted ? Theme.red : root.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
        Rectangle {
            visible: root.showProgress
            width: parent.width
            height: 5
            radius: 3
            color: Theme.surface0
            Rectangle {
                width: parent.width * (root.muted ? 0 : Math.max(0, Math.min(1, root.value)))
                height: parent.height
                radius: parent.radius
                color: root.accent
                Behavior on width {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
