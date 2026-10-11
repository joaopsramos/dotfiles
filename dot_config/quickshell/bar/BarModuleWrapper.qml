import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import qs

WrapperMouseArea {
    id: root

    property color moduleColor: Theme.base
    property int horizontalPadding: Theme.padding + 2
    property int verticalPadding: Theme.padding
    property bool mouseEnabled: false
    property string tooltipText: ""
    hoverEnabled: tooltipText.length > 0
    ToolTip.visible: containsMouse && tooltipText.length > 0
    ToolTip.text: tooltipText
    ToolTip.delay: 500
    default property alias contentItem: rect.child

    enabled: mouseEnabled
    cursorShape: mouseEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    WrapperRectangle {
        id: rect

        color: root.moduleColor
        radius: Theme.radius
        leftMargin: root.horizontalPadding
        rightMargin: root.horizontalPadding
        topMargin: Math.max(root.verticalPadding, (Theme.barHeight - (child?.implicitHeight ?? 0)) / 2)
        bottomMargin: topMargin
    }
}
