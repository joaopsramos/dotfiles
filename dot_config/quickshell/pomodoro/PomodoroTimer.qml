import QtQuick

Item {
    id: root
    visible: false
    property int focusMinutes: 25
    property int shortMinutes: 5
    property int longMinutes: 15
    property string phase: "focus"
    property int completedShortBreaks: 0
    property bool running: false
    property real deadline: 0
    property real remaining: duration
    readonly property int duration: minutes(phase) * 60
    readonly property real progress: Math.max(0, Math.min(1, 1 - remaining / duration))
    readonly property string label: phase === "focus" ? "Focus" : phase === "short" ? "Short break" : "Long break"
    readonly property string clockText: {
        const seconds = Math.max(0, Math.ceil(remaining))
        return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
    }
    signal transitioned(string phase)

    function minutes(mode) {
        return mode === "focus" ? focusMinutes : mode === "short" ? shortMinutes : longMinutes
    }
    function selectPhase(mode) {
        running = false
        phase = mode
        remaining = duration
    }
    function toggle() {
        if (running) {
            remaining = Math.max(0, (deadline - Date.now()) / 1000)
            running = false
        } else {
            if (remaining <= 0)
                remaining = duration
            deadline = Date.now() + remaining * 1000
            running = true
        }
    }
    function reset() {
        running = false
        remaining = duration
    }
    function configure(mode, value) {
        value = Math.max(1, Math.min(180, Math.round(value)))
        if (mode === "focus") focusMinutes = value
        else if (mode === "short") shortMinutes = value
        else longMinutes = value
        if (phase === mode) {
            remaining = duration
            if (running)
                deadline = Date.now() + remaining * 1000
        }
    }
    function advance() {
        if (phase === "focus")
            phase = completedShortBreaks >= 3 ? "long" : "short"
        else {
            if (phase === "short")
                completedShortBreaks = Math.min(3, completedShortBreaks + 1)
            else
                completedShortBreaks = 0
            phase = "focus"
        }
        remaining = duration
        deadline = Date.now() + remaining * 1000
        running = true
        transitioned(phase)
    }
    function tick() {
        remaining = Math.max(0, (deadline - Date.now()) / 1000)
        if (remaining <= 0)
            advance()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }
}
