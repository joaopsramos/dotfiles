pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

BarModuleWrapper {
    id: root
    verticalPadding: 4
    mouseEnabled: true

    property var screen: null
    readonly property bool multipleScreens: Quickshell.screens.length > 1
    readonly property int firstWorkspaceId: multipleScreens && root.screen?.name !== "HDMI-A-1" ? 6 : 1
    readonly property int workspaceCount: multipleScreens ? 5 : 10
    visible: workspaceCount > 0

    readonly property var workspaceById: {
        const result = {}
        for (const workspace of Hyprland.workspaces.values)
            result[workspace.id] = workspace
        return result
    }

    function getWorkspace(id) {
        return workspaceById[id] || null
    }

    function activateWorkspace(id) {
        const workspace = getWorkspace(id)
        if (workspace)
            workspace.activate()
        else
            Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + id + " })" : "workspace " + id)
    }

    function getColor(workspace, isFocused) {
        if (workspace?.urgent) {
            return Theme.red
        } else if (isFocused) {
            return Theme.mauve
        } else {
            return Theme.transparent
        }
    }

    function getBorderColor(workspace, isFocused, hasWindows) {
        if (workspace?.urgent) {
            return Theme.red
        } else if (isFocused || hasWindows) {
            return Theme.mauve
        } else {
            return Theme.surface1
        }
    }

    Row {
        id: row
        spacing: 0

        Repeater {
            model: root.workspaceCount

            Item {
                id: dot
                required property int index

                property int workspaceId: root.firstWorkspaceId + index
                property var workspace: root.getWorkspace(workspaceId)
                property bool isFocused: Hyprland.focusedWorkspace?.id === workspaceId
                property bool hasWindows: workspace?.toplevels.values.length > 0

                width: 22
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.mantle
                    opacity: dotMouse.containsMouse ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: {
                        const fill = root.getColor(dot.workspace, dot.isFocused)
                        return dotMouse.containsMouse && (dot.isFocused || dot.workspace?.urgent) ? Qt.darker(fill, 1.2) : fill
                    }
                    border.width: 2
                    border.color: root.getBorderColor(dot.workspace, dot.isFocused, dot.hasWindows)
                }
                MouseArea {
                    id: dotMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activateWorkspace(dot.workspaceId)
                }
            }
        }
    }
}
