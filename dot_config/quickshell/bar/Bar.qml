import Quickshell
import QtQuick
import qs

Scope {
    Variants {
        model: Quickshell.screens

        // Quickshell creates this type at runtime; its installed qmltypes mark it uncreatable.
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            id: panelWindow
            property alias popupHost: popupHost
            required property var modelData
            screen: modelData

            color: "transparent"

            BarPopup {
                id: popupHost
                parentWindow: panelWindow
            }

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Theme.barHeight

            // The installed Quickshell qmltypes omit the Margins value type.
            // qmllint disable unqualified unresolved-type
            margins {
                top: 10
                left: 10
                right: 10
            }
            // qmllint enable unqualified unresolved-type

            Row {
                id: leftModules
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing

                Workspaces {
                    id: workspaces
                    anchors.verticalCenter: parent.verticalCenter
                }

                Spotify {
                    parentWindow: panelWindow
                    anchors.verticalCenter: parent.verticalCenter
                    maximumWidth: Math.max(0, clock.x - workspaces.width - leftModules.spacing - 8 - (micUsage.visible ? micUsage.width + leftModules.spacing : 0))
                }

                MicUsage {
                    id: micUsage
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DateTime {
                id: clock
                parentWindow: panelWindow
                anchors.centerIn: parent
            }

            StatusModules {
                id: statusModules
                parentWindow: panelWindow
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
