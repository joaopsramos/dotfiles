import QtQuick
import QtQuick.Controls
import qs
import qs.bar

Item {
    id: root

    property var activeApplications: []
    property string icon: ""
    property string tooltipTitle: ""
    readonly property string applications: activeApplications.join("\n")
    property real reveal: activeApplications.length > 0 ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    visible: reveal > 0
    implicitWidth: (microphone.implicitWidth + 24) * reveal
    implicitHeight: Theme.barHeight

    Rectangle {
        id: bubble
        anchors.centerIn: parent
        height: root.implicitHeight * root.reveal
        width: height + (root.width - height) * root.reveal
        radius: Math.min(width, height) / 2 * (1 - root.reveal) + Theme.radius * root.reveal
        color: Theme.red
    }

    BarText {
        id: microphone
        anchors.centerIn: parent
        text: root.icon
        color: Theme.base
        opacity: Math.max(0, (root.reveal - 0.65) / 0.35)
        scale: 0.8 + root.reveal * 0.2
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.activeApplications.length > 0
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        ToolTip.visible: containsMouse && root.activeApplications.length > 0
        ToolTip.text: root.tooltipTitle + ":\n" + root.applications
        ToolTip.delay: 500
    }
}
