import QtQuick
import Quickshell.Hyprland
import qs

BarModuleWrapper {
    id: root

    property int persistentWorkspaceCount: 5

    function maxVisibleWorkspaceId() {
        let maxId = 0;

        if (Hyprland.workspaces.values.length > 0) {
            maxId = Math.max(...Hyprland.workspaces.values.map(w => w.id));
        }

        return Math.max(maxId, persistentWorkspaceCount);
    }

    function getWorkspace(id) {
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.id === id)
                return workspace;
        }
        return null;
    }

    function getColor(workspace, isFocused, hasWindows) {
        if (workspace?.urgent) {
            return Theme.red;
        } else if (isFocused) {
            return Theme.mauve;
        } else {
            return Theme.transparent;
        }
    }

    function getBorderColor(workspace, isFocused, hasWindows) {
        if (workspace?.urgent) {
            return Theme.red;
        } else if (isFocused || hasWindows) {
            return Theme.mauve;
        } else {
            return Theme.surface1;
        }
    }

    Row {
        id: row
        spacing: 12

        Repeater {
            model: root.maxVisibleWorkspaceId()

            Rectangle {
                required property int index

                property int workspaceId: index + 1
                property var workspace: root.getWorkspace(workspaceId)
                property bool isFocused: Hyprland.focusedWorkspace?.id === workspaceId
                property bool hasWindows: workspace?.toplevels.values.length > 0

                width: 10
                height: 10
                radius: 5

                color: getColor(workspace, isFocused, hasWindows)

                border {
                    width: 2
                    color: getBorderColor(workspace, isFocused, hasWindows)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + parent.workspaceId)
                }
            }
        }
    }
}
