import QtQuick
import qs

BarModuleWrapper {
    horizontalPadding: 0
    verticalPadding: 0

    mouseEnabled: true
    onClicked: text.onlyTime = !text.onlyTime

    Item {
        implicitWidth: text.implicitWidth + (Theme.padding + 2) * 2
        implicitHeight: text.implicitHeight + Theme.padding * 2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height

            color: Theme.base
            radius: Theme.radius

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBack
                }
            }
        }

        BarText {
            id: text

            property bool onlyTime: true

            anchors.centerIn: parent
            text: onlyTime ? Qt.formatTime(Time.date, "hh:mm") : Qt.formatDateTime(Time.date, "dd/MM hh:mm")
        }
    }
}
