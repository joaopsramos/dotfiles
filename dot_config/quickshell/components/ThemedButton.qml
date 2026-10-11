import QtQuick
import QtQuick.Controls
import qs

Button {
    id: root
    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
    property bool selected: false
    property bool loading: false
    property int horizontalAlignment: Text.AlignHCenter
    property int textFormat: Text.AutoText
    property color backgroundColor: Theme.mantle
    property color textColor: root.selected ? Theme.mauve : Theme.text
    implicitHeight: 30
    leftPadding: 10
    rightPadding: 10
    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        Row {
            id: content
            anchors.verticalCenter: parent.verticalCenter
            x: root.horizontalAlignment === Text.AlignLeft ? 0
                : root.horizontalAlignment === Text.AlignRight ? parent.width - width
                : (parent.width - width) / 2
            spacing: root.loading ? 6 : 0
            Text {
                visible: root.loading
                text: ""
                color: root.textColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
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
                textFormat: root.textFormat
                color: root.textColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    background: Rectangle {
        radius: 6
        color: root.down ? Qt.darker(root.backgroundColor, 1.2) : root.hovered ? Qt.lighter(root.backgroundColor, 1.15) : root.backgroundColor
        border.color: root.selected ? Theme.mauve : (root.backgroundColor === Theme.red || root.backgroundColor === Theme.green) ? root.backgroundColor : Theme.surface0
    }
}
