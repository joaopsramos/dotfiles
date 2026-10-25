import QtQuick
import qs
import Quickshell
import qs.services as Services
import Quickshell.Services.SystemTray
import "network" as NetworkWidgets
import "audio" as AudioWidgets
import "battery" as BatteryWidgets
import "system" as SystemWidgets
import "storage" as StorageWidgets
import "bluetooth" as BluetoothWidgets

Item {
    id: root

    property var hiddenTrayApps: ["spotify"]
    readonly property var visibleTrayItems: SystemTray.items.values.filter(item => {
        const identity = [item.id, item.title].join(" ").toLowerCase()
        return !hiddenTrayApps.some(app => identity.includes(app.toLowerCase()))
    })

    property var parentWindow
    property var notifications: null
    readonly property var stats: Services.Status.stats

    implicitWidth: modules.implicitWidth
    implicitHeight: modules.implicitHeight

    Row {
        id: modules
        spacing: Theme.spacing

        AudioWidgets.Audio {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            outputIcon: Services.Audio.outputIcon
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
            horizontalPadding: 10
            verticalPadding: Theme.moduleVerticalPadding
            mouseEnabled: true
            cursorShape: Qt.ArrowCursor
            Row {
                spacing: 10
                Repeater {
                    model: root.visibleTrayItems
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        width: 16
                        height: 20

                        function openMenu() {
                            if (!modelData.hasMenu || !root.parentWindow)
                                return
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

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: modelData.icon
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                        }
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && modelData.onlyMenu))
                                    trayItem.openMenu()
                                else if (mouse.button === Qt.LeftButton)
                                    modelData.activate()
                                else if (mouse.button === Qt.MiddleButton)
                                    modelData.secondaryActivate()
                            }
                        }
                    }
                }
            }
        }

        NotificationBell {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            controller: root.notifications
        }

        BluetoothWidgets.Bluetooth {
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
        }

        NetworkWidgets.Network {
            id: networkWidget
            anchors.verticalCenter: parent.verticalCenter
            parentWindow: root.parentWindow
            fallback: root.stats.network
        }


    }
}
