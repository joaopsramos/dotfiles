import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root
    property string kind: "wifi"
    property real signalStrength: -1
    property color color: Theme.network
    implicitWidth: 20
    implicitHeight: 20

    Shape {
        width: 24
        height: 24
        transform: Scale {
            xScale: root.width / 24
            yScale: root.height / 24
        }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.kind === "ethernet" ? 1.8 : -1
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: root.kind === "ethernet" ? "transparent" : Theme.surface0
            PathSvg {
                path: root.kind === "ethernet"
                    ? "M 7 3 H 17 V 10 H 7 Z M 12 10 V 16 M 4 20 V 16 H 20 V 20 M 12 16 V 20"
                    : "M 12 21 L 1 7 Q 12 -1 23 7 Z"
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.color
            PathSvg {
                path: root.kind !== "wifi" ? ""
                    : root.signalStrength < 0 || root.signalStrength >= 75 ? "M 12 21 L 1 7 Q 12 -1 23 7 Z"
                    : root.signalStrength >= 50 ? "M 12 21 L 3.75 10.5 Q 12 4.5 20.25 10.5 Z"
                    : root.signalStrength >= 25 ? "M 12 21 L 6.5 14 Q 12 10 17.5 14 Z"
                    : "M 12 21 L 9.25 17.5 Q 12 15.5 14.75 17.5 Z"
            }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathSvg {
                path: root.kind === "down" ? "M 3 3 L 21 21" : ""
            }
        }
    }
}
