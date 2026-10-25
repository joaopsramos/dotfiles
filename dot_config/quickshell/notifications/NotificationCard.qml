pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs

Rectangle {
    id: root
    required property var record
    signal remove
    signal activate
    signal dismissAll
    property bool interactive: false
    property var actions: []
    property real progress: -1
    readonly property real receivedTime: new Date(root.record.receivedAt).getTime()
    property bool recent: receivedTime + 60000 > Date.now()
    readonly property string timeLabel: recent ? "now" : Qt.formatDateTime(new Date(receivedTime), "HH:mm")
    function refreshTimestamp() {
        timestampExpiry.stop()
        const remaining = receivedTime + 60000 - Date.now()
        recent = remaining > 0
        if (recent && visible) {
            timestampExpiry.interval = Math.max(1, Math.ceil(remaining))
            timestampExpiry.start()
        }
    }
    onReceivedTimeChanged: Qt.callLater(refreshTimestamp)
    onVisibleChanged: Qt.callLater(refreshTimestamp)
    Component.onCompleted: Qt.callLater(refreshTimestamp)
    Timer {
        id: timestampExpiry
        onTriggered: root.refreshTimestamp()
    }
    implicitHeight: content.implicitHeight + 24
    height: implicitHeight
    radius: Theme.radius
    color: Theme.mantle
    border.width: 1
    border.color: Theme.surface0

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) root.dismissAll()
            else if (event.button === Qt.MiddleButton) root.remove()
            else root.activate()
        }
    }
    Column {
        id: content
        x: 10
        y: 12
        width: parent.width - 22
        spacing: Theme.spacing
        Row {
            width: parent.width
            height: 22
            spacing: 6
            Image {
                id: icon
                width: 24
                height: 24
                y: appName.y + appName.height / 2 - height / 2
                source: !root.record.appIcon ? "" : root.record.appIcon.startsWith("/") ? "file://" + root.record.appIcon : root.record.appIcon.includes(":/") ? root.record.appIcon : Quickshell.iconPath(root.record.appIcon, true)
                sourceSize: Qt.size(24, 24)
                fillMode: Image.PreserveAspectFit
                Text {
                    anchors.centerIn: parent
                    visible: icon.status !== Image.Ready
                    text: root.record.critical ? "" : ""
                    color: root.record.critical ? Theme.red : root.record.low ? Theme.green : Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: root.record.critical ? 20 : 22
                }
            }
            Text {
                id: appName
                anchors.top: parent.top
                width: Math.min(implicitWidth, Math.max(0, parent.width + 5 - icon.width - time.width - close.width - parent.spacing * 4))
                text: root.record.appName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
            Text {
                id: time
                anchors.top: parent.top
                text: "· " + root.timeLabel
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
            Item {
                width: Math.max(0, parent.width + 5 - icon.width - appName.width - time.width - close.width - parent.spacing * 4)
                height: 1
            }
            Rectangle {
                id: close
                width: 20
                height: 20
                y: -5
                radius: 5
                color: closeMouse.containsMouse ? Theme.surface1 : Theme.transparent
                Item {
                    anchors.centerIn: parent
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
            x: 2
            width: parent.width - 2
            text: root.record.summary
            visible: text.length > 0
            textFormat: Text.PlainText
            color: Theme.text
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
        Text {
            x: 2
            width: parent.width - 2
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
        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            visible: root.progress >= 0
            color: Theme.surface0
            Rectangle {
                width: parent.width * root.progress / 100
                height: parent.height
                radius: parent.radius
                color: Theme.blue
                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }
        Flow {
            width: parent.width
            spacing: 6
            visible: childrenRect.height > 0
            Repeater {
                model: root.actions.filter(action => action.identifier !== "default")
                Rectangle {
                    id: actionButton
                    required property var modelData
                    width: Math.min(actionText.implicitWidth + 20, content.width)
                    height: 30
                    radius: 6
                    color: actionMouse.containsMouse ? Theme.surface1 : Theme.surface0
                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, content.width - 20)
                        text: actionButton.modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.bodyFontSize
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actionButton.modelData.invoke()
                    }
                }
            }
        }
    }
}
