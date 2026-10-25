PrivacyIndicator {
    activeApplications: [...new Set(ScreenSharing.activeApplications.concat(
        ScreenSharing.localRecording ? ["wf-recorder"] : []))]
    icon: ScreenSharing.localRecording ? "" : "󰍹"
    clickable: ScreenSharing.localRecording
    onClicked: ScreenSharing.stopRecording()
}
