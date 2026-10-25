pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs

Item {
    id: root
    property var service: null
    readonly property var history: service?.history || []
    implicitHeight: scroll.y + (history.length ? Math.min(420, scroll.contentHeight) : 72)
    Row {
        id: header
        width: parent.width
        height: 30
        spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - clearButton.width - header.spacing
            text: "Notifications" + (root.history.length ? " · " + root.history.length : "")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
        }
        Rectangle {
            id: clearButton
            width: 72
            height: 30
            radius: 6
            color: root.history.length > 0 && clearMouse.containsMouse ? Theme.surface1 : Theme.surface0
            opacity: root.history.length ? 1 : 0.4
            Text {
                anchors.centerIn: parent
                text: "Clear all"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.history.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.history.length > 0)
                        root.service.clearHistory()
                }
            }
        }
    }
    Rectangle {
        y: header.y + header.height + 10
        width: parent.width
        height: 1
        color: Theme.surface0
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scroll.y + (scroll.height - height) / 2
        visible: root.history.length === 0
        text: "No notifications yet"
        color: Theme.overlay1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
    HistoryList {
        id: scroll
        y: header.y + header.height + 22
        width: parent.width
        height: parent.height - y
        records: root.history
        onRemoveRequested: id => root.service.removeHistory(id)
    }
}
