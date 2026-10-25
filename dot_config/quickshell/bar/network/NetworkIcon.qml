import QtQuick
import qs

Item {
    id: root
    property string kind: "ethernet"
    property real signalStrength: -1
    property color color: Theme.network
    implicitWidth: 20
    implicitHeight: 20

    Text {
        anchors.centerIn: parent
        text: root.kind === "ethernet" || root.kind === "unknown" ? "󰒢"
            : root.kind === "down" ? "󰤭"
            : root.signalStrength < 0 ? "󰤯"
            : root.signalStrength >= 75 ? "󰤨"
            : root.signalStrength >= 50 ? "󰤥"
            : root.signalStrength >= 25 ? "󰤢"
            : "󰤟"
        font.family: Theme.fontFamily
        font.pixelSize: Math.min(root.width, root.height)
        color: root.color
    }
}
