import QtQuick
import QtQuick.Shapes

// The open contour joins the trigger's sides; there is no divider across the neck.
Shape {
    id: surface

    property real neckWidth: 80
    property real neckCenter: width / 2
    property real neckDepth: 10
    property real radius: 8
    property color fillColor: "#24273a"
    property color strokeColor: "#494d64"
    property real strokeWidth: 1

    readonly property real inset: strokeWidth / 2
    readonly property real leftSpace: Math.max(0, neckLeft - inset) / 2
    readonly property real rightSpace: Math.max(0, rightEdge - neckRight) / 2
    readonly property real leftCurve: Math.min(neckDepth, leftSpace, height / 4)
    readonly property real rightCurve: Math.min(neckDepth, rightSpace, height / 4)
    readonly property real curve: Math.max(leftCurve, rightCurve)
    readonly property real leftCorner: Math.min(radius, leftSpace, height / 4)
    readonly property real rightCorner: Math.min(radius, rightSpace, height / 4)
    readonly property real bottomCorner: Math.min(radius, height / 4)
    readonly property real neckLeft: neckCenter - neckWidth / 2 + inset
    readonly property real neckRight: neckCenter + neckWidth / 2 - inset
    readonly property real rightEdge: width - inset
    readonly property real bottomEdge: Math.max(inset, height - inset)

    visible: height > strokeWidth
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: surface.fillColor
        strokeColor: surface.strokeColor
        strokeWidth: surface.strokeWidth
        capStyle: ShapePath.FlatCap

        startX: surface.neckLeft
        startY: 0
        PathQuad {
            x: surface.neckLeft - surface.leftCurve
            y: surface.curve
            controlX: surface.neckLeft
            controlY: surface.curve
        }
        PathLine {
            x: surface.inset + surface.leftCorner
            y: surface.curve
        }
        PathQuad {
            x: surface.inset
            y: surface.curve + surface.leftCorner
            controlX: surface.inset
            controlY: surface.curve
        }
        PathLine {
            x: surface.inset
            y: surface.bottomEdge - surface.bottomCorner
        }
        PathQuad {
            x: surface.inset + surface.bottomCorner
            y: surface.bottomEdge
            controlX: surface.inset
            controlY: surface.bottomEdge
        }
        PathLine {
            x: surface.rightEdge - surface.bottomCorner
            y: surface.bottomEdge
        }
        PathQuad {
            x: surface.rightEdge
            y: surface.bottomEdge - surface.bottomCorner
            controlX: surface.rightEdge
            controlY: surface.bottomEdge
        }
        PathLine {
            x: surface.rightEdge
            y: surface.curve + surface.rightCorner
        }
        PathQuad {
            x: surface.rightEdge - surface.rightCorner
            y: surface.curve
            controlX: surface.rightEdge
            controlY: surface.curve
        }
        PathLine {
            x: surface.neckRight + surface.rightCurve
            y: surface.curve
        }
        PathQuad {
            x: surface.neckRight
            y: 0
            controlX: surface.neckRight
            controlY: surface.curve
        }
    }

}
