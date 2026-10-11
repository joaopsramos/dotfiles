pragma ComponentBehavior: Bound

import QtQuick
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

    PopupHover {
        triggerHovered: clockModule.containsMouse
        popupHovered: popupClient.hovered
        available: !!root.parentWindow && root.visible
        onOpenRequested: root.calendarOpen = true
        onCloseRequested: root.calendarOpen = false
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
        onClicked: root.onlyTime = !root.onlyTime

        Item {
            implicitWidth: clockText.implicitWidth + (Theme.padding + 2) * 2
            implicitHeight: root.parentWindow ? root.parentWindow.height : Theme.barHeight

            Rectangle {
                visible: !root.calendarVisible
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                color: Theme.base
                radius: Theme.radius
            }

            PopupFrame {
                anchors.fill: parent
                visible: root.calendarVisible
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
        contentItem: calendarContent
        onDismissed: root.calendarOpen = false
        CalendarPanel {
            id: calendarContent
        }
    }
}
