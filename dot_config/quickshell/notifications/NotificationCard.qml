pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

Item {
    id: root
    required property NotificationEntry entry
    signal dismissAll
    property bool appeared: false
    property real retainedHeight: 0
    // Keep the complete card intact while sliding out, including its border.
    // Closing also removes native actions, which must not resize the card.
    implicitHeight: entry.closed ? retainedHeight : card.implicitHeight
    height: implicitHeight
    onImplicitHeightChanged: {
        if (!entry.closed)
            retainedHeight = implicitHeight
    }
    opacity: appeared && !entry.closed ? 1 : 0
    clip: true
    Component.onCompleted: {
        retainedHeight = implicitHeight
        appeared = true
    }
    Behavior on opacity {
        NumberAnimation {
            duration: root.entry.closed ? 140 : 180
        }
    }

    function iconSource(value) {
        if (!value)
            return ""
        if (value.startsWith("/") || value.includes(":/"))
            return value.startsWith("/") ? "file://" + value : value
        return Quickshell.iconPath(value, true)
    }

    Rectangle {
        id: card
        x: root.appeared && !root.entry.closed ? 0 : root.width
        width: root.width
        implicitHeight: content.implicitHeight + 24
        height: root.height
        radius: Theme.radius
        color: Theme.base
        border.width: Theme.borderWidth
        border.color: root.entry.critical ? Theme.red : Theme.surface1
        Behavior on x {
            NumberAnimation {
                duration: root.entry.closed ? 140 : 200
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            onHoveredChanged: root.entry.hovered = hovered
        }
        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.RightButton)
                    root.dismissAll()
                else if (event.button === Qt.MiddleButton)
                    root.entry.dismiss()
                else
                    root.entry.activate()
            }
        }

        Column {
            id: content
            x: 12
            y: 12
            width: parent.width - 24
            spacing: Theme.spacing

            Row {
                width: parent.width
                spacing: 10
                Rectangle {
                    width: 34
                    height: 34
                    radius: 8
                    color: Theme.surface0
                    Image {
                        id: icon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: root.iconSource(root.entry.appIcon)
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !icon.visible
                        text: "󰂚"
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        color: root.entry.critical ? Theme.red : Theme.blue
                    }
                }
                Column {
                    width: parent.width - 34 - 10
                    spacing: 4
                    Row {
                        width: parent.width
                        height: 20
                        spacing: Theme.spacing
                        Text {
                            width: parent.width - timestamp.width - closeButton.width - 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.entry.appName
                            textFormat: Text.PlainText
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                            elide: Text.ElideRight
                        }
                        Text {
                            id: timestamp
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(root.entry.receivedAt, "HH:mm")
                            color: Theme.overlay1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                        }
                        FontMetrics {
                            id: timestampMetrics
                            font: timestamp.font
                        }
                        Rectangle {
                            id: closeButton
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 6
                            color: closeMouse.containsMouse ? Theme.surface1 : "transparent"
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: timestamp.y - closeButton.y + timestamp.baselineOffset + timestampMetrics.tightBoundingRect(timestamp.text).y + timestampMetrics.tightBoundingRect(timestamp.text).height / 2 - height / 2
                                width: 10
                                height: 10
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 1.2
                                    radius: 0.6
                                    rotation: 45
                                    color: Theme.subtext0
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 1.2
                                    radius: 0.6
                                    rotation: -45
                                    color: Theme.subtext0
                                }
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.entry.dismiss()
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: root.entry.summary
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        wrapMode: Text.Wrap
                    }
                }
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.entry.body
                textFormat: Text.StyledText
                color: Theme.text
                linkColor: Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                wrapMode: Text.Wrap
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Rectangle {
                width: parent.width
                height: 5
                radius: 2.5
                visible: root.entry.progress >= 0
                color: Theme.surface0
                Rectangle {
                    width: parent.width * root.entry.progress / 100
                    height: parent.height
                    radius: parent.radius
                    color: Theme.blue
                    Behavior on width {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }
            Flow {
                width: parent.width
                spacing: 6
                visible: childrenRect.height > 0
                Repeater {
                    model: root.entry.actions.filter(action => action.identifier !== "default")
                    Rectangle {
                        id: actionButton
                        required property NotificationAction modelData
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
}
