import QtQuick
import qs
import qs.services as Services
import ".."

Item {
    id: root
    property var parentWindow: null
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property var backend: Services.Bluetooth
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : Theme.barHeight
    onPopupOpenChanged: backend.setViewer(root, popupOpen)
    Component.onDestruction: backend.setViewer(root, false)

    PopupHover {
        id: hover
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
        onClicked: hover.open()
        BarText {
            text: root.backend.state.enabled ? "󰂯" : "󰂲"
            color: root.backend.ready && root.backend.state.enabled ? Theme.blue : Theme.overlay1
        }
    }
    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: 380
        opened: root.popupOpen
        contentItem: panel
        onDismissed: root.popupOpen = false
        BluetoothPanel {
            id: panel
        }
    }
}
