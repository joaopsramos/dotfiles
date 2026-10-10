import QtQuick
import Quickshell
import qs

Rectangle {
    id: root
    required property var record
    signal remove
    implicitHeight: content.implicitHeight + 24
    height: implicitHeight
    radius: Theme.radius
    color: Theme.mantle
    border.width: 1
    border.color: record.critical ? Theme.red : Theme.surface0

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: Theme.spacing
        Row {
            width: parent.width
            height: 22
            spacing: Theme.spacing
            Image {
                id: icon
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                source: !root.record.appIcon ? "" : root.record.appIcon.startsWith("/") ? "file://" + root.record.appIcon : root.record.appIcon.includes(":/") ? root.record.appIcon : Quickshell.iconPath(root.record.appIcon, true)
                sourceSize: Qt.size(24, 24)
                fillMode: Image.PreserveAspectFit
                Text {
                    anchors.centerIn: parent
                    visible: icon.status !== Image.Ready
                    text: "󰂚"
                    color: Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - icon.width - time.width - close.width - 24
                text: root.record.appName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
            Text {
                id: time
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(root.record.receivedAt), "HH:mm")
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
            Rectangle {
                id: close
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                radius: 5
                color: closeMouse.containsMouse ? Theme.surface1 : "transparent"
                Item {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    width: 10
                    height: 10
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 1.2
                        rotation: 45
                        color: Theme.subtext0
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 1.2
                        rotation: -45
                        color: Theme.subtext0
                    }
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.remove()
                }
            }
        }
        Text {
            width: parent.width
            text: root.record.summary
            textFormat: Text.PlainText
            color: Theme.text
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
        Text {
            width: parent.width
            text: root.record.body
            visible: text.length > 0
            textFormat: Text.StyledText
            color: Theme.subtext1
            linkColor: Theme.blue
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }
}
