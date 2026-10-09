import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "network" as NetworkWidgets
import "audio" as AudioWidgets
import "battery" as BatteryWidgets
import "system" as SystemWidgets
import "storage" as StorageWidgets

Item {
    id: root

    property var hiddenTrayApps: ["spotify"]
    readonly property var visibleTrayItems: SystemTray.items.values.filter(item => {
        const identity = [item.id, item.title].join(" ").toLowerCase()
        return !hiddenTrayApps.some(app => identity.includes(app.toLowerCase()))
    })

    property var parentWindow
    property var stats: ({ cpu: 0, memory: 0, disk: 0, volume: 0, muted: false,
        sound: "󰓃", network: { kind: "down", name: "" }, battery: { value: -1, charging: false } })

    implicitWidth: modules.implicitWidth
    implicitHeight: modules.implicitHeight

    function refresh() {
        statsProcess.running = true
    }

    Process {
        id: statsProcess
        command: ["python3", "/home/joao/.config/quickshell/bar/status.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.stats = JSON.parse(text) } catch (e) { }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Row {
        id: modules
        spacing: 8

        AudioWidgets.Audio {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            outputIcon: root.stats.sound
        }

        SystemWidgets.System {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            cpuUsage: root.stats.cpu
            memoryUsage: root.stats.memory
        }
        StorageWidgets.Storage {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            usage: root.stats.disk
        }

        BatteryWidgets.Battery {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            fallback: root.stats.battery
        }

        BarModuleWrapper {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.visibleTrayItems.length > 0
            horizontalPadding: 10; verticalPadding: 6
            mouseEnabled: true
            cursorShape: Qt.ArrowCursor
            Row {
                spacing: 10
                Repeater {
                    model: root.visibleTrayItems
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        width: 16; height: 20

                        function openMenu() {
                            if (!modelData.hasMenu || !root.parentWindow) return
                            const point = mapToItem(root.parentWindow.contentItem, 0, height)
                            trayMenu.anchor.rect.x = Math.round(point.x)
                            trayMenu.anchor.rect.y = Math.round(point.y)
                            trayMenu.open()
                        }

                        QsMenuAnchor {
                            id: trayMenu
                            menu: trayItem.modelData.hasMenu ? trayItem.modelData.menu : null
                            anchor.window: root.parentWindow
                        }

                        Image { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon; sourceSize: Qt.size(32, 32); fillMode: Image.PreserveAspectFit }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton ||
                                        (mouse.button === Qt.LeftButton && modelData.onlyMenu))
                                    trayItem.openMenu()
                                else if (mouse.button === Qt.LeftButton) modelData.activate()
                                else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                            }
                        }
                    }
                }
            }
        }

        NetworkWidgets.Network {
            id: networkWidget
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            fallback: root.stats.network
        }
    }

}
