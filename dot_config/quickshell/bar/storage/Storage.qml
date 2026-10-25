import QtQuick
import qs.services as Services
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property var usage: null
    readonly property var backend: Services.Details.storage
    readonly property var snapshot: backend.snapshot
    readonly property string error: backend.error
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 440
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
        moduleColor: root.popupVisible ? Theme.transparent : Theme.base
        mouseEnabled: true
        onClicked: root.openPopup()
        tooltipText: Services.Status.error || Services.Status.errors.disk || ""
        BarText {
            text: "  " + (root.usage == null ? "—" : root.usage + "%")
            color: Theme.disk
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
        StoragePanel {
            id: content
            snapshot: root.snapshot
            fallback: root.usage
            error: root.error
        }
    }
}
