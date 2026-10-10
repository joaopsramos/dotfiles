import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services as Services

Scope {
    id: root
    property bool ready: false
    property bool shown: false
    property var targetScreen: null
    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property int brightness: -1
    readonly property real outputVolume: Services.Audio.sink?.audio?.volume ?? 0
    readonly property bool outputMuted: Services.Audio.sink?.audio?.muted ?? false
    readonly property bool microphoneMuted: Services.Audio.source?.audio?.muted ?? false

    function show(kind, level, muted) {
        if (!ready)
            return
        root.kind = kind
        root.level = level
        root.muted = muted
        targetScreen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]
        shown = true
        dismiss.restart()
    }
    onOutputVolumeChanged: show("volume", outputVolume, outputMuted)
    onOutputMutedChanged: show("volume", outputVolume, outputMuted)
    onMicrophoneMutedChanged: show("microphone", Services.Audio.source?.audio?.volume ?? 0, microphoneMuted)
    // Ignore initial PipeWire discovery and default-device changes.
    Connections {
        target: Services.Audio
        function onSinkChanged() {
            root.ready = false
            startup.restart()
        }
        function onSourceChanged() {
            root.ready = false
            startup.restart()
        }
    }
    Timer {
        id: startup
        interval: 800
        running: true
        onTriggered: root.ready = true
    }
    Timer {
        id: dismiss
        interval: 1500
        onTriggered: root.shown = false
    }
    Services.RestartingStream {
        command: ["python3", "-u", Quickshell.shellPath("overlays/brightness.py")]
        onRead: data => {
            const value = Number(data.trim())
            if (!Number.isFinite(value))
                return
            const previous = root.brightness
            root.brightness = value
            if (previous >= 0 && value >= 0 && previous !== value)
                root.show("brightness", value / 100, false)
        }
        onStopped: root.brightness = -1
    }
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: window
        screen: root.targetScreen
        visible: card.opacity > 0
        color: "transparent"
        anchors.bottom: true
        // The installed qmltypes omit the Margins value type.
        // qmllint disable unqualified unresolved-type missing-property
        margins {
            bottom: 64
        }
        // qmllint enable unqualified unresolved-type missing-property
        implicitWidth: 320
        implicitHeight: 104
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Indicator {
            id: card
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            label: root.kind === "brightness" ? "Brightness" : root.kind === "microphone" ? "Microphone" : "Volume"
            icon: root.kind === "brightness" ? "󰃠" : root.kind === "microphone" ? (root.muted ? "" : "") : root.muted ? "󰝟" : root.level < 0.34 ? "" : root.level < 0.67 ? "" : ""
            value: root.level
            muted: root.muted
            showProgress: root.kind !== "microphone"
            accent: root.kind === "brightness" ? Theme.yellow : root.kind === "microphone" ? Theme.sapphire : Theme.volume
            opacity: root.shown ? 1 : 0
            transform: Translate {
                y: root.shown ? 0 : 10
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.fastAnimation
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fastAnimation
                }
            }
        }
    }
}
