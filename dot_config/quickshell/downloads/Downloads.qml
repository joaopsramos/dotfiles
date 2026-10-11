pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services as Services

Scope {
    id: root
    readonly property int edgeMargin: 10
    readonly property int contentPadding: 12
    property var entries: []
    property var dismissed: ({})
    property string folderUrl: ""
    property string openedScreen: ""
    property var hoveredScreens: ({})
    readonly property var visibleEntries: entries.filter(entry => dismissed[entry.path] !== entry.revision + ":" + entry.arrived)

    function show(screenName) {
        openedScreen = screenName
        if (hoveredScreens[screenName])
            autoClose.stop()
        else
            autoClose.restart()
    }
    Services.RestartingStream {
        // The watcher supplies up to 20 files from the last 24 hours.
        command: ["python3", "-u", Quickshell.shellPath("downloads/watch.py")]
        onRead: data => {
            try {
                const response = JSON.parse(data)
                if (response.error) {
                    console.warn("Downloads:", response.error)
                    return
                }
                root.entries = response.entries
                root.folderUrl = response.folderUrl
                if (response.arrived)
                    root.show(Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "")
            } catch (error) {
                console.warn("Could not read Downloads events:", error)
            }
        }
    }
    Timer {
        id: autoClose
        interval: 6000
        onTriggered: {
            if (!root.hoveredScreens[root.openedScreen])
                root.openedScreen = ""
        }
    }
    Variants {
        model: Quickshell.screens
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            id: window
            required property var modelData
            screen: modelData
            readonly property bool opened: root.openedScreen === modelData.name
            property real reveal: opened ? 1 : 0
            Behavior on reveal {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            function updateHover() {
                const hovered = edgeHover.hovered || cardHover.hovered || bridgeHover.hovered
                const screens = Object.assign({}, root.hoveredScreens)
                screens[modelData.name] = hovered
                root.hoveredScreens = screens
                if (hovered && opened) {
                    autoClose.stop()
                    leaveDelay.stop()
                } else if (opened) {
                    autoClose.stop()
                    leaveDelay.restart()
                }
            }
            Timer {
                id: leaveDelay
                interval: Theme.popupCloseDelay
                onTriggered: {
                    if (window.opened && !edgeHover.hovered && !cardHover.hovered && !bridgeHover.hovered)
                        root.openedScreen = ""
                }
            }
            anchors { right: true; bottom: true }
            implicitWidth: Math.min(404, modelData.width)
            implicitHeight: Math.min(440, modelData.height)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-downloads"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                Region { item: edge }
                Region { item: card }
                Region { item: bridge }
            }
            Item {
                id: edge
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 6; height: 40
                HoverHandler {
                    id: edgeHover
                    onHoveredChanged: {
                        if (hovered)
                            openDelay.restart()
                        else
                            openDelay.stop()
                        Qt.callLater(window.updateHover)
                    }
                }
                Timer {
                    id: openDelay
                    interval: 180
                    onTriggered: {
                        root.show(window.modelData.name)
                        window.updateHover()
                    }
                }
            }
            Item {
                id: bridge
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: window.opened ? root.edgeMargin : 0
                height: card.height + root.edgeMargin
                HoverHandler {
                    id: bridgeHover
                    onHoveredChanged: Qt.callLater(window.updateHover)
                }
            }
            Rectangle {
                id: card
                readonly property real fullWidth: Math.max(0, window.width - root.edgeMargin * 2)
                readonly property real fullHeight: Math.min(window.height - root.edgeMargin * 2, content.implicitHeight + root.contentPadding * 2)
                width: height + (fullWidth - height) * window.reveal
                height: fullHeight * window.reveal
                visible: window.reveal > 0
                x: window.width - width - root.edgeMargin
                y: window.height - height - root.edgeMargin
                radius: Math.min(width, height) / 2 * (1 - window.reveal) + 12 * window.reveal
                color: Theme.base
                border.width: Theme.borderWidth
                border.color: Theme.surface1
                clip: true
                HoverHandler {
                    id: cardHover
                    onHoveredChanged: Qt.callLater(window.updateHover)
                }
                DownloadPanel {
                    id: content
                    x: root.contentPadding
                    y: root.contentPadding
                    width: card.fullWidth - root.contentPadding * 2
                    opacity: Math.max(0, (window.reveal - 0.65) / 0.35)
                    enabled: window.opened && window.reveal > 0.95
                    entries: root.visibleEntries
                    folderUrl: root.folderUrl
                    onCloseRequested: root.openedScreen = ""
                    onDismissFile: (path, revision, arrived) => {
                        const dismissed = Object.assign({}, root.dismissed)
                        dismissed[path] = revision + ":" + arrived
                        root.dismissed = dismissed
                    }
                }
            }
        }
    }
}
