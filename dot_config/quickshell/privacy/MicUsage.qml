import qs.services as Services

PrivacyIndicator {
    readonly property var source: Services.Audio.source
    readonly property bool muted: source?.audio?.muted ?? false
    activeApplications: Services.Audio.activeApplications
    icon: muted ? "" : ""
    tooltipTitle: "Microphone in use"
}
