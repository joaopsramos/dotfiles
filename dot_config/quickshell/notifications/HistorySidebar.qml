pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: root
    required property var targetScreen
    required property NotificationService service
    property bool opened: false
    readonly property int sidebarWidth: Math.min(390, targetScreen.width - 20)

    Timer { id: openDelay; interval: 150; onTriggered: root.opened = true }
    Timer {
        id: closeDelay
        interval: 300
        onTriggered: { if (!surfaceHover.hovered) root.opened = false }
    }

    // A fixed surface and a narrow input mask leave the desktop clickable.
    // qmllint disable uncreatable-type
    PanelWindow {
    // qmllint enable uncreatable-type
        id: window
        screen: root.targetScreen
        color: "transparent"
        anchors { top: true; right: true }
        implicitWidth: root.sidebarWidth + 10
        implicitHeight: root.targetScreen.height - 10
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notification-history"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            Region { item: edge }
            Region { item: panel }
            Region { item: bridge }
        }

        HoverHandler {
            id: surfaceHover
            onHoveredChanged: {
                if (hovered) closeDelay.stop()
                else { openDelay.stop(); closeDelay.restart() }
            }
        }
        Item {
            id: edge
            anchors.right: parent.right
            y: 0
            width: 6
            height: Math.floor(root.targetScreen.height / 3)
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) { closeDelay.stop(); openDelay.restart() }
                    else openDelay.stop()
                }
            }
        }
        Item {
            id: bridge
            anchors.right: parent.right
            y: panel.y
            width: root.opened ? 10 : 0
            height: panel.height
        }
        Rectangle {
            id: panel
            x: root.opened ? 0 : window.width
            y: 54
            width: root.sidebarWidth
            height: Math.min(window.height - y, scroll.y + 12
                + (root.service.history.length ? historyList.implicitHeight : 72))
            radius: Theme.radius
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: Theme.surface1
            clip: true
            Behavior on x {
                NumberAnimation { duration: root.opened ? 200 : 140; easing.type: Easing.OutCubic }
            }

            Row {
                id: header
                x: 16; y: 14
                width: parent.width - 32
                height: 30
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - clearButton.width - 10
                    text: "Notifications" + (root.service.history.length ? " · " + root.service.history.length : "")
                    color: Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true
                }
                Rectangle {
                    id: clearButton
                    width: 72; height: 30; radius: 6
                    color: clearMouse.containsMouse ? Theme.surface1 : Theme.surface0
                    opacity: root.service.history.length ? 1 : 0.4
                    Text {
                        anchors.centerIn: parent
                        text: "Clear all"; color: Theme.red
                        font.family: Theme.fontFamily; font.pixelSize: 11
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        enabled: root.service.history.length > 0
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.clearHistory()
                    }
                }
            }
            Rectangle {
                x: 16; y: header.y + header.height + 10
                width: parent.width - 32; height: 1
                color: Theme.surface0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: scroll.y + (scroll.height - height) / 2
                visible: root.service.history.length === 0
                text: "No notifications yet"
                color: Theme.overlay1
                font.family: Theme.fontFamily; font.pixelSize: 13
            }
            Flickable {
                id: scroll
                x: 12; y: header.y + header.height + 22
                width: parent.width - 24
                height: parent.height - y - 12
                contentHeight: historyList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Column {
                    id: historyList
                    width: scroll.width
                    spacing: 8
                    Repeater {
                        model: ScriptModel { values: root.service.history; objectProp: "id" }
                        HistoryCard {
                            required property var modelData
                            record: modelData
                            width: historyList.width
                            onRemove: root.service.removeHistory(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
