import QtQuick
import qs
import qs.session.work

Item {
    id: root
    readonly property bool active: WorkMode.displayedActive
    readonly property color accent: active ? Theme.red : Theme.green
    property real progress: 0
    property bool completed: false
    readonly property int holdDuration: 1000
    implicitWidth: glyph.implicitWidth + (Theme.padding + 2) * 2
    implicitHeight: Theme.barHeight

    function cancelHold() {
        hold.stop()
        progress = 0
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.base
    }
    BarText {
        id: glyph
        anchors.centerIn: parent
        text: root.active ? "󱙙" : "󰠔"
        color: root.accent
        opacity: WorkMode.busy ? 0.5 : 1
    }
    Canvas {
        id: border
        anchors.fill: parent
        visible: root.progress > 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            if (root.progress <= 0) return
            const inset = 1
            const left = inset, top = inset
            const right = width - inset, bottom = height - inset
            const radius = Math.min(Theme.radius, (right - left) / 2, (bottom - top) / 2)
            const points = [[width / 2, top], [right - radius, top]]
            function corner(cx, cy, start) {
                for (let i = 1; i <= 16; i++) {
                    const angle = (start + i * 90 / 16) * Math.PI / 180
                    points.push([cx + radius * Math.cos(angle), cy + radius * Math.sin(angle)])
                }
            }
            corner(right - radius, top + radius, -90)
            points.push([right, bottom - radius])
            corner(right - radius, bottom - radius, 0)
            points.push([left + radius, bottom])
            corner(left + radius, bottom - radius, 90)
            points.push([left, top + radius])
            corner(left + radius, top + radius, 180)
            points.push([width / 2, top])
            let total = 0
            for (let i = 1; i < points.length; i++)
                total += Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1])
            let remaining = total * root.progress
            ctx.beginPath()
            ctx.moveTo(points[0][0], points[0][1])
            for (let i = 1; i < points.length && remaining > 0; i++) {
                const a = points[i - 1], b = points[i]
                const length = Math.hypot(b[0] - a[0], b[1] - a[1])
                const fraction = Math.min(1, remaining / length)
                ctx.lineTo(a[0] + (b[0] - a[0]) * fraction, a[1] + (b[1] - a[1]) * fraction)
                remaining -= length
            }
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.strokeStyle = root.accent
            ctx.stroke()
        }
    }
    onProgressChanged: border.requestPaint()
    onAccentChanged: border.requestPaint()
    NumberAnimation {
        id: hold
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.holdDuration
        onFinished: {
            if (!mouse.pressed || !mouse.containsMouse || root.completed) return
            root.completed = true
            WorkMode.completeHold()
            root.progress = 0
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !WorkMode.busy
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.completed = false
            root.progress = 0
            hold.restart()
        }
        onReleased: root.cancelHold()
        onCanceled: root.cancelHold()
        onExited: root.cancelHold()
    }
}
