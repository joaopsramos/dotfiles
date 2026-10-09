import QtQuick
import QtQuick.Controls
import qs

Button {
    id: root
    property bool selected: false
    property color backgroundColor: Theme.mantle
    property color textColor: root.selected ? Theme.mauve : Theme.text
    implicitHeight: 30
    leftPadding: 10
    rightPadding: 10
    contentItem: Text {
        text: root.text
        color: root.textColor
        font.family: Theme.fontFamily
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
    background: Rectangle {
        radius: 6
        color: root.down ? Qt.darker(root.backgroundColor, 1.2)
            : root.hovered ? Qt.lighter(root.backgroundColor, 1.15) : root.backgroundColor
        border.color: root.selected ? Theme.mauve
            : (root.backgroundColor === Theme.red || root.backgroundColor === Theme.green) ? root.backgroundColor : Theme.surface0
    }
}
