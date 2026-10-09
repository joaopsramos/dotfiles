pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root

    property var parentWindow
    property bool calendarOpen: false
    readonly property bool calendarVisible: popupClient.presented
    property bool onlyTime: true

    width: clockModule.implicitWidth
    height: clockModule.implicitHeight
    implicitWidth: clockModule.implicitWidth
    implicitHeight: clockModule.implicitHeight

    Timer {
        id: openDelay
        interval: 150
        onTriggered: {
            root.calendarOpen = true
        }
    }
    Timer {
        id: closeDelay
        interval: 300
        onTriggered: {
            if (!clockModule.containsMouse && !popupClient.hovered)
                root.calendarOpen = false
        }
    }

    BarModuleWrapper {
        id: clockModule
        anchors.fill: parent
        moduleColor: Theme.transparent
        horizontalPadding: 0
        verticalPadding: 0
        mouseEnabled: true
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        onEntered: { closeDelay.stop(); openDelay.restart() }
        onExited: { openDelay.stop(); closeDelay.restart() }
        onClicked: root.onlyTime = !root.onlyTime

        Item {
            implicitWidth: clockText.implicitWidth + (Theme.padding + 2) * 2
            implicitHeight: root.parentWindow ? root.parentWindow.height : 34

            Rectangle {
                visible: !root.calendarVisible
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                color: Theme.base
                radius: Theme.radius
            }

            Shape {
                id: clockFrame
                anchors.fill: parent
                visible: root.calendarVisible
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Theme.base
                    strokeColor: Theme.surface1
                    strokeWidth: Theme.borderWidth
                    capStyle: ShapePath.FlatCap
                    // Leave the bottom open so its outline continues into the calendar.
                    PathSvg {
                        path: "M 0.5 " + clockFrame.height
                            + " L 0.5 " + (Theme.radius + 0.5)
                            + " Q 0.5 0.5 " + (Theme.radius + 0.5) + " 0.5"
                            + " L " + (clockFrame.width - Theme.radius - 0.5) + " 0.5"
                            + " Q " + (clockFrame.width - 0.5) + " 0.5 "
                            + (clockFrame.width - 0.5) + " " + (Theme.radius + 0.5)
                            + " L " + (clockFrame.width - 0.5) + " " + clockFrame.height
                    }
                }
            }

            BarText {
                id: clockText
                anchors.centerIn: parent
                text: root.onlyTime ? Qt.formatTime(Time.date, "hh:mm") : Qt.formatDateTime(Time.date, "dd/MM hh:mm")
            }
        }
    }

    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: 292
        opened: root.calendarOpen
        grabFocus: true
        contentItem: calendarContent
        onDismissed: root.calendarOpen = false
        onHoveredChanged: { if (hovered) closeDelay.stop(); else closeDelay.restart() }
        CalendarPanel { id: calendarContent }
    }
}
