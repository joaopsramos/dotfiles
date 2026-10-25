import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root
    property real value: 0
    property string label: ""
    property string unit: "%"
    property real maximumValue: 100
    property real warningValue: 90
    property bool available: true
    property color accent: Theme.cpu
    readonly property color gaugeColor: value >= warningValue ? Theme.red : accent
    implicitWidth: 136
    implicitHeight: 136
    property real animatedValue: available ? Math.max(0, Math.min(100, value / maximumValue * 100)) : 0
    Behavior on animatedValue {
        NumberAnimation {
            duration: Theme.slowAnimation
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.transparent
            strokeColor: Theme.surface0
            strokeWidth: 7
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 9
                radiusY: root.height / 2 - 9
                startAngle: 135
                sweepAngle: 270
            }
        }
        ShapePath {
            fillColor: Theme.transparent
            strokeColor: root.gaugeColor
            strokeWidth: 7
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 9
                radiusY: root.height / 2 - 9
                startAngle: 135
                sweepAngle: 270 * root.animatedValue / 100
            }
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 5
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.available ? Math.round(root.value) + root.unit : "—"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 27
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }
    }
}
