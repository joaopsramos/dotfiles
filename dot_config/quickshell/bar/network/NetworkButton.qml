import QtQuick
import QtQuick.Controls
import qs

Button {
    id: root
    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    property color textColor: Theme.text
    property color backgroundColor: Theme.mantle
    property bool selected: false
    property bool loading: false
    implicitHeight: 30
    leftPadding: 10
    rightPadding: 10
    contentItem: Row {
        spacing: root.loading ? 6 : 0
        Text {
            visible: root.loading
            text: ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.loading
            }
        }
        Text {
            text: root.text
            textFormat: Text.PlainText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    background: Rectangle {
        radius: 6
        color: root.down ? Qt.darker(root.backgroundColor, 1.2) : root.hovered ? Qt.lighter(root.backgroundColor, 1.15) : root.backgroundColor
        border.color: root.selected ? Theme.mauve : (root.backgroundColor === Theme.red || root.backgroundColor === Theme.green) ? root.backgroundColor : Theme.surface0
    }
}
