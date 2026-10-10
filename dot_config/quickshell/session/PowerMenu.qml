pragma ComponentBehavior: Bound

import QtQuick
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    property bool opened: false
    property bool cornerMode: false
    property bool cornerPointerInside: true
    property real expansion: opened ? 1 : 0
    Behavior on expansion {
        NumberAnimation {
            duration: Theme.normalAnimation
            easing.type: Easing.OutCubic
        }
    }
    property var targetScreen: null
    property string hostname: ""
    property string uptime: ""

    function openAt(screen, fromCorner) {
        cornerMode = fromCorner
        targetScreen = screen
        menu.reset()
        opened = true
        closeDelay.stop()
        // The pointer starts inside the trigger. Wait for an actual exit,
        // rather than relying on hover delivery while the surface maps.
        cornerPointerInside = true
        hoverCloseDelay.stop()
        information.running = true
        Qt.callLater(() => menu.forceActiveFocus())
    }
    function updateCornerHover(position) {
        if (!opened || !cornerMode)
            return
        cornerPointerInside = position.x >= 0 && position.y >= 0
            && position.x < reveal.fullWidth && position.y < menu.height
        if (cornerPointerInside || menu.confirming)
            hoverCloseDelay.stop()
        else if (!hoverCloseDelay.running)
            hoverCloseDelay.start()
    }
    function open() {
        openAt(Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0], false)
    }
    function close() {
        if (!opened)
            return
        hoverCloseDelay.stop()
        // Keep the native window mapped continuously while fading out.
        closeDelay.restart()
        opened = false
    }
    function toggle() {
        if (opened)
            close()
        else
            open()
    }
    function execute(index) {
        const commands = [["hyprlock"], ["systemctl", "suspend"], ["hyprshutdown", "-t", "Logging out..."], ["hyprshutdown", "-t", "Rebooting...", "--post-cmd", "reboot"], ["hyprshutdown", "-t", "Shutting down...", "--post-cmd", "shutdown -P 0"]]
        if (index < 0 || index >= commands.length)
            return
        close()
        Quickshell.execDetached(commands[index])
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            root.toggle()
        }
        function open(): void {
            root.open()
        }
        function close(): void {
            root.close()
        }
    }
    Process {
        id: information
        command: ["sh", "-c", "hostname; uptime -p"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.hostname = lines[0] || ""
                root.uptime = (lines[1] || "").replace(/^up /, "")
            }
        }
    }
    Timer {
        id: closeDelay
        interval: 230
    }
    Timer {
        id: hoverCloseDelay
        interval: 300
        onTriggered: {
            if (root.opened && root.cornerMode && !menu.confirming && !root.cornerPointerInside)
                root.close()
        }
    }

    Variants {
        model: Quickshell.screens
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            id: corner
            required property var modelData
            screen: modelData
            visible: !root.opened && !closeDelay.running
            color: "transparent"
            anchors {
                top: true
                left: true
            }
            implicitWidth: 6
            implicitHeight: 28
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-power-corner"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            HoverHandler {
                id: cornerHover
                onHoveredChanged: {
                    if (hovered)
                        cornerDelay.restart()
                    else
                        cornerDelay.stop()
                }
            }
            Timer {
                id: cornerDelay
                interval: 180
                onTriggered: {
                    if (!cornerHover.hovered || root.opened || closeDelay.running)
                        return
                    root.openAt(corner.modelData, true)
                }
            }
        }
    }

    // The installed qmltypes incorrectly mark PanelWindow uncreatable.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: window
        screen: root.targetScreen
        visible: root.opened || closeDelay.running
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-powermenu"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // This area stays fixed while the card expands from the corner.
        // Tracking the entire surface also catches movement outside the card.
        HoverHandler {
            parent: window.contentItem
            margin: 1
            onPointChanged: root.updateCornerHover(point.position)
            onHoveredChanged: {
                if (hovered)
                    root.updateCornerHover(point.position)
                else if (root.opened && root.cornerMode) {
                    root.cornerPointerInside = false
                    if (!menu.confirming)
                        hoverCloseDelay.restart()
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#70000000"
            opacity: root.opened ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
        Item {
            id: reveal
            readonly property real fullWidth: Math.min(420, window.width)
            x: root.cornerMode ? 0 : (window.width - fullWidth) / 2
            y: root.cornerMode ? 0 : (window.height - menu.height) / 2
            width: root.cornerMode ? fullWidth * root.expansion : fullWidth
            height: root.cornerMode ? menu.height * root.expansion : menu.height
            clip: root.cornerMode
            PowerMenuPanel {
                id: menu
                width: reveal.fullWidth
                edgeAttached: root.cornerMode
                hostname: root.hostname
                uptime: root.uptime
                // The corner menu closes by clipping back into the edge,
                // keeping its contents opaque throughout the collapse.
                opacity: root.cornerMode || root.opened ? 1 : 0
                scale: root.cornerMode ? 1 : root.opened ? 1 : 0.96
                Behavior on opacity {
                    enabled: !root.cornerMode
                    NumberAnimation {
                        duration: 160
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                onDismissRequested: root.close()
                onConfirmingChanged: hoverCloseDelay.stop()
                onExecuteRequested: index => root.execute(index)
            }
        }
    }
}
