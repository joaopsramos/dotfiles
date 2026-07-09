import QtQuick
import Quickshell.Widgets
import qs

WrapperMouseArea {
    id: root

    property color moduleColor: Theme.base
    property int horizontalPadding: Theme.padding + 2
    property int verticalPadding: Theme.padding
    property bool mouseEnabled: false
    default property alias contentItem: rect.child

    enabled: mouseEnabled
    cursorShape: mouseEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    WrapperRectangle {
        id: rect

        color: root.moduleColor
        radius: Theme.radius
        leftMargin: root.horizontalPadding
        rightMargin: root.horizontalPadding
        topMargin: root.verticalPadding
        bottomMargin: root.verticalPadding
    }
}
