pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool ready: false
    property var historyScreens: []
    readonly property NotificationService service: serviceLoader.item as NotificationService

    // Stop the previous daemon before claiming org.freedesktop.Notifications.
    // A missing Dunst process is normal on subsequent shell reloads.
    Process {
        command: ["pkill", "-x", "dunst"]
        running: true
        // Quickshell's qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => { root.ready = true }
        // qmllint enable signal-handler-parameters
    }
    Loader {
        id: serviceLoader
        active: root.ready
        sourceComponent: NotificationService {}
    }

    Variants {
        // Each monitor gets its own edge trigger for the shared history.
        model: root.service ? Quickshell.screens : []
        HistorySidebar {
            required property var modelData
            targetScreen: modelData
            service: root.service
            onOpenedChanged: {
                const others = root.historyScreens.filter(name => name !== modelData.name)
                root.historyScreens = opened ? [...others, modelData.name] : others
            }
            Component.onDestruction: {
                root.historyScreens = root.historyScreens.filter(name => name !== modelData.name)
            }
        }
    }

    Variants {
        model: root.ready ? Quickshell.screens : []
        // Quickshell creates PanelWindow at runtime despite its qmltypes annotation.
        // qmllint disable uncreatable-type
        PanelWindow {
        // qmllint enable uncreatable-type
            id: window
            required property var modelData
            screen: modelData
            readonly property var entries: root.service
                ? root.service.entries.filter(entry => entry.screenName === modelData.name) : []
            visible: entries.length > 0 && !root.historyScreens.includes(modelData.name)
            color: "transparent"
            anchors { top: true; right: true }
            // The installed Quickshell qmltypes omit the Margins value type.
            // qmllint disable unqualified unresolved-type
            margins { top: 54; right: 10; bottom: 10 }
            // qmllint enable unqualified unresolved-type
            implicitWidth: 360
            // Keep the Wayland surface stable while cards animate inside it.
            // Resizing the native window every frame makes dismissal stutter.
            implicitHeight: modelData.height - 64
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { item: stack }

            Flickable {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: Math.min(stack.implicitHeight, parent.height)
                contentHeight: stack.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: stack
                    width: parent.width
                    spacing: 8
                    move: Transition {
                        NumberAnimation { properties: "y"; duration: 140; easing.type: Easing.OutCubic }
                    }
                    Repeater {
                        // Preserve each card when another entry is inserted or removed.
                        // A plain array resets the Repeater and replays every entrance.
                        model: ScriptModel { values: window.entries }
                        NotificationCard {
                            required property NotificationEntry modelData
                            entry: modelData
                            width: stack.width
                            onDismissAll: root.service.dismissAll()
                        }
                    }
                }
            }
        }
    }
}
