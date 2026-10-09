import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Item {
    id: root

    property var source: Pipewire.defaultAudioSource
    readonly property bool muted: source?.audio?.muted ?? false
    PwObjectTracker { objects: root.source ? [root.source] : [] }

    property var activeApplications: []
    readonly property string applications: activeApplications.join("\n")
    property real reveal: muted || activeApplications.length > 0 ? 1 : 0

    Behavior on reveal {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    function updateCaptureState(snapshot) {
        const names = snapshot.filter(node => node.type === "PipeWire:Interface:Node"
            && node.info?.state === "running"
            && node.info.props?.["media.class"] === "Stream/Input/Audio")
            .map(node => node.info.props["application.name"]
                || node.info.props["node.description"]
                || node.info.props["node.name"] || "Unknown application")
        activeApplications = [...new Set(names)]
    }

    visible: reveal > 0
    implicitWidth: (microphone.implicitWidth + 24) * reveal
    implicitHeight: microphone.implicitHeight + 12

    Process {
        id: captureState
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    root.activeApplications = []
                    return
                }
                try {
                    root.updateCaptureState(JSON.parse(text))
                } catch (error) {
                    console.warn("Could not read microphone capture state:", error)
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!captureState.running)
                captureState.running = true
        }
    }

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
        text: root.muted ? "" : ""
        color: Theme.base
        opacity: Math.max(0, (root.reveal - 0.65) / 0.35)
        scale: 0.8 + root.reveal * 0.2
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.muted || root.activeApplications.length > 0
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        ToolTip.visible: containsMouse && root.activeApplications.length > 0
        ToolTip.text: "Microphone in use:\n" + root.applications
        ToolTip.delay: 500
    }
}
