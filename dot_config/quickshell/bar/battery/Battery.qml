import QtQuick
import qs.services as Services
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property var fallback: ({
            value: -1,
            charging: false
        })
    readonly property var backend: Services.Details.battery
    readonly property var snapshot: backend.snapshot
    readonly property string error: backend.error
    visible: fallback.value >= 0
    onVisibleChanged: {
        if (!visible)
            popupOpen = false
    }
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 360
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : Theme.barHeight

    onPopupOpenChanged: backend.setViewer(root, popupOpen)
    Component.onDestruction: backend.setViewer(root, false)
    function openPopup() {
        popupHover.open()
    }
    PopupHover {
        id: popupHover
        triggerHovered: barHover.hovered
        popupHovered: popupClient.hovered
        available: !!root.parentWindow && root.visible
        onOpenRequested: root.popupOpen = true
        onCloseRequested: root.popupOpen = false
    }
    HoverHandler {
        id: barHover
    }
    PopupFrame {
        anchors.fill: parent
        visible: root.popupVisible
    }
    BarModuleWrapper {
        id: module
        anchors.centerIn: parent
        horizontalPadding: Theme.moduleHorizontalPadding
        verticalPadding: Theme.moduleVerticalPadding
        moduleColor: root.popupVisible ? "transparent" : Theme.base
        mouseEnabled: true
        onClicked: root.openPopup()
        tooltipText: Services.Status.error || Services.Status.errors.battery || ""
        Row {
            id: batteryRow
            spacing: Theme.spacing
            BarText {
                id: batteryIcon
                property var icons: ["󱉞", "󰁺", "󰁼", "󰁾", "󰂀", "󰂂", "󰁹"]
                property var chargingIcons: ["󰢟", "󰢜", "󰂇", "󰢝", "󰢞", "󰂋", "󰂅"]
                property int chargeIndex: Math.min(6, Math.max(0, Math.floor(root.fallback.value / (100 / 7))))
                text: root.fallback.charging ? chargingIcons[chargeIndex] : icons[chargeIndex]
                font.pixelSize: Theme.barFontSize
                color: root.fallback.charging ? Theme.green : root.fallback.value <= 15 ? Theme.red : root.fallback.value <= 30 ? Theme.yellow : Theme.text
            }
            BarText {
                text: root.fallback.value + "%"
                color: batteryIcon.color
                y: (batteryRow.height - implicitHeight) / 2
            }
        }
    }
    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: root.popupWidth
        opened: root.popupOpen
        contentItem: content
        onDismissed: root.popupOpen = false
        BatteryPanel {
            id: content
            details: root.snapshot.battery
            fallback: root.fallback
            profiles: root.snapshot.profiles
            activeProfile: root.snapshot.activeProfile
            error: root.error
            onSelectProfile: profile => root.backend.execute(["profile", profile])
        }
    }
}
