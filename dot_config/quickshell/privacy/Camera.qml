pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

Singleton {
    id: root
    readonly property var videoNodes: Pipewire.nodes.values.filter(node =>
        node.type === PwNodeType.VideoSource || node.type === PwNodeType.VideoSink
        || (node.properties["media.class"] || "").startsWith("Stream/") && (node.properties["media.class"] || "").includes("/Video"))
    readonly property var linkGroups: Pipewire.linkGroups.values
    property var directApplications: []
    readonly property var captureNodes: linkGroups.filter(group => {
        if (group.state !== PwLinkState.Active || !group.source || !group.target)
            return false
        const props = group.source.properties
        const camera = group.source.type === PwNodeType.VideoSource
            && (props["device.id"] !== undefined || !!props["api.v4l2.path"]
                || /v4l2|libcamera/.test(group.source.name || "") || props["media.role"] === "Camera")
        return camera
    }).map(group => group.target)
    readonly property var activeApplications: [...new Set([
        ...captureNodes.map(node => node.properties["application.name"] || node.description || node.name || "Camera application"),
        ...directApplications.map(name => DesktopEntries.heuristicLookup(name)?.name || name)
    ])]
    PwObjectTracker { objects: root.videoNodes }
    PwObjectTracker { objects: root.linkGroups }
    RestartingStream {
        command: ["python3", "-u", Quickshell.shellPath("privacy/camera.py")]
        onRead: data => {
            try {
                root.directApplications = JSON.parse(data)
            } catch (error) {
                console.warn("Could not read camera activity:", error)
            }
        }
        onStopped: root.directApplications = []
    }
}
