pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: root
    property string openedScreen: ""
    readonly property string focusFinishedSound: Quickshell.shellPath("pomodoro/sounds/focus-finished.ogg")
    readonly property string breakFinishedSound: Quickshell.shellPath("pomodoro/sounds/break-finished.ogg")
    PomodoroTimer {
        id: controller
        onTransitioned: phase => {
            Quickshell.execDetached(["pw-play", "--media-role", "Notification", "--volume", "0.65", phase === "focus" ? root.breakFinishedSound : root.focusFinishedSound])
            const message = phase === "focus" ? "Break finished." : phase === "long" ? "Take a long break." : "Take a short break."
            Quickshell.execDetached(["notify-send", "--app-name=Pomodoro", "--icon=alarm-clock", "", message])
        }
    }
    Variants {
        model: Quickshell.screens
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            id: window
            required property var modelData
            screen: modelData
            readonly property bool opened: root.openedScreen === modelData.name
            onOpenedChanged: {
                if (opened)
                    Qt.callLater(() => keyboard.forceActiveFocus())
                else {
                    leaveDelay.stop()
                    panel.configuring = false
                }
            }
            readonly property bool hovered: edgeHover.hovered || panelHover.hovered
            property real expansion: opened ? 1 : 0
            Behavior on expansion {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            onHoveredChanged: {
                if (hovered) {
                    leaveDelay.stop()
                } else if (opened)
                    leaveDelay.restart()
            }
            anchors.top: true
            implicitWidth: Math.min(380, modelData.width)
            implicitHeight: Math.min(560, modelData.height)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-pomodoro"
            WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            FocusScope {
                id: keyboard
                anchors.fill: parent
                focus: window.opened
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space) {
                        if (!event.isAutoRepeat)
                            controller.toggle()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.openedScreen = ""
                        event.accepted = true
                    }
                }
            }
            mask: Region {
                Region { item: edge }
                Region { item: card }
            }
            Timer {
                id: leaveDelay
                interval: Theme.popupCloseDelay
                onTriggered: if (window.opened && !window.hovered) root.openedScreen = ""
            }
            Item {
                id: edge
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 120
                height: 8
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 3
                    bottomLeftRadius: 3
                    bottomRightRadius: 3
                    visible: controller.running
                    color: Theme.surface0
                    clip: true
                    Rectangle {
                        width: parent.width * controller.progress
                        height: parent.height
                        radius: 3
                        color: controller.phase === "focus" ? Theme.mauve : controller.phase === "long" ? Theme.blue : Theme.green
                        Behavior on width { NumberAnimation { duration: Theme.fastAnimation } }
                    }
                }
                HoverHandler {
                    id: edgeHover
                    onHoveredChanged: {
                        if (hovered) openDelay.restart()
                        else openDelay.stop()
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openedScreen = window.modelData.name
                }
                Timer {
                    id: openDelay
                    interval: Theme.popupOpenDelay
                    onTriggered: root.openedScreen = window.modelData.name
                }
            }
            Rectangle {
                id: card
                x: (window.width - width) / 2
                y: 0
                width: 120 + (window.width - 120) * window.expansion
                height: Math.min(window.height, panel.implicitHeight + 24) * window.expansion
                visible: window.expansion > 0
                radius: 16
                topLeftRadius: 0
                topRightRadius: 0
                color: Theme.base
                border.width: Theme.borderWidth
                border.color: Theme.surface1
                clip: true
                HoverHandler { id: panelHover }
                PomodoroPanel {
                    id: panel
                    x: (parent.width - width) / 2
                    y: 12
                    width: window.width - 24
                    timer: controller
                    opacity: Math.max(0, (window.expansion - 0.6) / 0.4)
                    enabled: window.opened && window.expansion > 0.95
                }
            }
        }
    }
}
