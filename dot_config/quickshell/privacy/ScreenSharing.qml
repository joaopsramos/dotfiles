pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root
    property bool localRecording: false

    function stopRecording() {
        if (localRecording && !stopProcess.running)
            stopProcess.running = true
    }

    Process {
        id: stopProcess
        // Stop only: never invoke the toggle script, which could start a recording.
        command: ["bash", "-c", "[[ -n ${XDG_RUNTIME_DIR:-} ]] || exit 0; read -r recording_pid < \"$XDG_RUNTIME_DIR/hypr-recording/pid\" || exit 0; [[ $recording_pid =~ ^[1-9][0-9]*$ && $recording_pid -gt 1 ]] || exit 0; recording_comm=$(ps -p \"$recording_pid\" -o comm= 2>/dev/null) || exit 0; [[ $recording_comm == wf-recorder ]] || exit 0; kill -INT -- \"$recording_pid\""]
    }

    IpcHandler {
        target: "recording"
        function started(): void {
            root.localRecording = true
        }
        function stopped(): void {
            root.localRecording = false
        }
    }

    readonly property var videoNodes: Pipewire.nodes.values.filter(node =>
        node.type === PwNodeType.VideoSource || node.type === PwNodeType.VideoSink
        || (node.properties["media.class"] || "").includes("/Video"))
    readonly property var linkGroups: Pipewire.linkGroups.values

    function isScreenSource(node) {
        if (!node)
            return false
        const props = node.properties
        if (props["media.role"] === "Screen")
            return true
        if (node.type !== PwNodeType.VideoSource || props["media.role"] === "Camera"
            || props["device.id"] !== undefined || props["api.v4l2.path"])
            return false
        // Portal backends do not all set media.role on their capture sources.
        return /xdg-desktop-portal|screencast|screen.?cast|screen.?capture/i.test(
            [node.name, node.description, props["application.name"]].join(" "))
    }

    readonly property var activeApplications: [...new Set(linkGroups.filter(group =>
        group.state === PwLinkState.Active && root.isScreenSource(group.source) && group.target
    ).map(group => group.target.properties["application.name"]
        || group.target.description || group.target.name || "Screen capture application"))]

    PwObjectTracker { objects: root.videoNodes }
    PwObjectTracker { objects: root.linkGroups }
}
