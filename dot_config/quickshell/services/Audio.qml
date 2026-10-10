pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audioNodes: Pipewire.nodes.values.filter(node => !!node.audio)
    readonly property var linkGroups: Pipewire.linkGroups.values
    readonly property var devices: audioNodes.filter(node => !node.isStream)
    readonly property var playbackNodes: [...new Set(linkGroups.filter(group =>
        group.state === PwLinkState.Active
        && group.source?.type === PwNodeType.AudioOutStream && !!group.source.audio
        && !!group.target?.audio
    ).map(group => group.source))]
    function applicationIcon(node) {
        const props = node.properties
        const entry = DesktopEntries.heuristicLookup(props["application.id"] || props["application.process.binary"] || props["application.name"] || "")
        const icon = props["application.icon-name"] || entry?.icon || "audio-x-generic"
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true)
    }
    readonly property var captureNodes: linkGroups.filter(group =>
        group.state === PwLinkState.Active
        && group.target?.type === PwNodeType.AudioInStream && !!group.target.audio
        && !!group.source?.audio && !group.source.isSink
    ).map(group => group.target)
    readonly property var activeApplications: [...new Set(captureNodes.map(node => node.properties["application.name"] || node.description || node.name || "Unknown application"))]
    readonly property string outputIcon: {
        const name = (sink?.name || "").toLowerCase()
        if (name.includes("bluez"))
            return "󰂯"
        if (name.includes("astro"))
            return "󰋋"
        return "󰓃"
    }
    PwObjectTracker {
        objects: root.audioNodes
    }
    // Link states are only subscribed while their groups are tracked.
    PwObjectTracker {
        objects: root.linkGroups
    }
}
