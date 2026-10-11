pragma ComponentBehavior: Bound

import QtQuick
import qs

Column {
    id: root
    property var monthDate: new Date(Time.year, Time.month, 1)
    readonly property int firstWeekday: new Date(monthDate.getFullYear(), monthDate.getMonth(), 1).getDay()
    readonly property int weekCount: Math.ceil((firstWeekday + new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 0).getDate()) / 7)

    spacing: Theme.spacing

    Row {
        width: parent.width
        height: 32

        Item {
            width: 36
            height: 32
            Rectangle {
                anchors.fill: parent
                radius: 7
                color: previousMonth.pressed ? Qt.darker(Theme.mantle, 1.2) : previousMonth.containsMouse ? Qt.lighter(Theme.base, 1.15) : "transparent"
            }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: "‹"
                color: Theme.text
                font.pixelSize: 22
            }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                id: previousMonth
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.monthDate = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth() - 1, 1)
            }
        }

        Text {
            width: parent.width - 72
            height: 32
            text: Qt.formatDate(root.monthDate, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            width: 36
            height: 32
            Rectangle {
                anchors.fill: parent
                radius: 7
                color: nextMonth.pressed ? Qt.darker(Theme.mantle, 1.2) : nextMonth.containsMouse ? Qt.lighter(Theme.base, 1.15) : "transparent"
            }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: "›"
                color: Theme.text
                font.pixelSize: 22
            }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                id: nextMonth
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.monthDate = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth() + 1, 1)
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.surface0
    }

    Grid {
        width: parent.width
        columns: 7
        spacing: 2

        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            Text {
                required property string modelData
                width: (parent.width - 12) / 7
                height: 22
                text: modelData
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Repeater {
            model: root.weekCount * 7
            delegate: Rectangle {
                required property int index
                property int day: index - root.firstWeekday + 1
                property var cellDate: new Date(root.monthDate.getFullYear(), root.monthDate.getMonth(), day)
                property bool inCurrentMonth: cellDate.getMonth() === root.monthDate.getMonth()
                property bool isToday: inCurrentMonth && cellDate.getFullYear() === Time.year && cellDate.getMonth() === Time.month && cellDate.getDate() === Time.day

                width: (parent.width - 12) / 7
                height: 28
                radius: 6
                color: isToday ? Theme.mauve : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.cellDate.getDate()
                    color: parent.isToday ? Theme.base : parent.inCurrentMonth ? Theme.text : Theme.surface2
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.bodyFontSize
                }
            }
        }
    }
}
