pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
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
