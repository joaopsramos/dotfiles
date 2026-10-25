import QtQuick
import qs
import qs.notifications

Item {
    id: root
    property var parentWindow: null
    property var controller: null
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    visible: !!controller?.service
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : Theme.barHeight
    onVisibleChanged: {
        if (!visible)
            popupOpen = false
    }
    onPopupVisibleChanged: {
        if (controller && parentWindow)
            controller.setHistoryOpen(parentWindow.screen.name, popupVisible)
    }
    Component.onDestruction: {
        if (controller && parentWindow)
            controller.setHistoryOpen(parentWindow.screen.name, false)
    }
    PopupHover {
        id: hover
        triggerHovered: barHover.hovered
        popupHovered: popupClient.hovered
        available: !!root.parentWindow && root.visible
        onOpenRequested: root.popupOpen = true
        onCloseRequested: root.popupOpen = false
    }
    HoverHandler { id: barHover }
    PopupFrame {
        anchors.fill: parent
        visible: root.popupVisible
    }
    BarModuleWrapper {
        id: module
        anchors.centerIn: parent
        horizontalPadding: Theme.moduleHorizontalPadding
        verticalPadding: Theme.moduleVerticalPadding
        moduleColor: root.popupVisible ? Theme.transparent : Theme.base
        mouseEnabled: true
        onClicked: {
            if (root.controller?.service)
                root.controller.service.notificationsDisabled = !root.controller.service.notificationsDisabled
        }
        BarText {
            text: root.controller?.service?.notificationsDisabled ? "󰂛" : "󰂚"
            color: root.controller?.service?.notificationsDisabled ? Theme.red : Theme.yellow
        }
    }
    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: 390
        opened: root.popupOpen
        contentItem: panel
        onDismissed: root.popupOpen = false
        HistoryPanel {
            id: panel
            service: root.controller?.service ?? null
        }
    }
}
