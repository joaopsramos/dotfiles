import Quickshell
import QtQuick

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 30

            margins {
                left: 10
                right: 10
            }

            Workspaces {}

            DateTime {
                anchors.centerIn: parent
            }
        }
    }
}
