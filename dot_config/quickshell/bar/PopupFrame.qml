import QtQuick
import QtQuick.Shapes
import qs

// The bottom stays open where the bar module joins the shared popup surface.
Shape {
    id: root
    property real radius: Theme.radius
    readonly property real inset: Theme.borderWidth / 2
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        fillColor: Theme.base
        strokeColor: Theme.surface1
        strokeWidth: Theme.borderWidth
        capStyle: ShapePath.FlatCap
        startX: root.inset
        startY: root.height
        PathLine {
            x: root.inset
            y: root.radius + root.inset
        }
        PathQuad {
            x: root.radius + root.inset
            y: root.inset
            controlX: root.inset
            controlY: root.inset
        }
        PathLine {
            x: root.width - root.radius - root.inset
            y: root.inset
        }
        PathQuad {
            x: root.width - root.inset
            y: root.radius + root.inset
            controlX: root.width - root.inset
            controlY: root.inset
        }
        PathLine {
            x: root.width - root.inset
            y: root.height
        }
    }
}
