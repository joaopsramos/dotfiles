pragma ComponentBehavior: Bound

import QtQuick
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    property bool ready: false
    property var historyScreens: []
    readonly property NotificationService service: serviceLoader.item as NotificationService
    function setHistoryOpen(screenName, opened) {
        const others = historyScreens.filter(name => name !== screenName)
        historyScreens = opened ? [...others, screenName] : others
    }

    // Stop the previous daemon before claiming org.freedesktop.Notifications.
    // A missing Dunst process is normal on subsequent shell reloads.
    Process {
        command: ["pkill", "-x", "dunst"]
        running: true
        // Quickshell's qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.ready = true
        }
        // qmllint enable signal-handler-parameters
    }
    Loader {
        id: serviceLoader
        active: root.ready
        sourceComponent: NotificationService {}
    }

    // Quickshell creates PanelWindow at runtime despite its qmltypes annotation.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: window
        screen: Quickshell.screens.find(item => item.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0] || null
        readonly property var entries: root.service ? root.service.entries.filter(entry => !entry.popupSuppressed) : []
        visible: root.ready && !!screen && entries.length > 0 && !root.service.notificationsDisabled && !root.historyScreens.includes(screen.name)
        color: Theme.transparent
        anchors {
            top: true
            right: true
        }
        // The installed Quickshell qmltypes omit the Margins value type.
        // qmllint disable unqualified unresolved-type
        margins {
            top: 34
            right: -10
            bottom: 10
        }
        // qmllint enable unqualified unresolved-type
        implicitWidth: 400
        // Keep the Wayland surface stable while cards animate inside it.
        // Resizing the native window every frame makes dismissal stutter.
        implicitHeight: screen ? screen.height - 44 : 1
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            item: stack
        }

        Flickable {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Math.min(stack.implicitHeight + 40, parent.height)
            contentHeight: stack.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: stack
                x: 20
                y: 20
                width: parent.width - 40
                spacing: Theme.spacing
                move: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Theme.fastAnimation
                        easing.type: Easing.OutCubic
                    }
                }
                Repeater {
                    // Preserve each card when another entry is inserted or removed.
                    // A plain array resets the Repeater and replays every entrance.
                    model: ScriptModel {
                        values: window.entries
                    }
                    PopupNotification {
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
