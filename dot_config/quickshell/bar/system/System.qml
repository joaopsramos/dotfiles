import QtQuick
import qs.services as Services
import qs
import ".."

Item {
    id: root
    property var parentWindow: null
    property var cpuUsage: null
    property var memoryUsage: null
    readonly property var backend: Services.Details.system
    readonly property var snapshot: backend.snapshot
    readonly property string error: backend.error
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property int popupWidth: 600
    implicitWidth: modules.implicitWidth
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
    Row {
        id: modules
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacing
        BarModuleWrapper {
            horizontalPadding: Theme.moduleHorizontalPadding
            verticalPadding: Theme.moduleVerticalPadding
            moduleColor: root.popupVisible ? Theme.transparent : Theme.base
            mouseEnabled: true
            onClicked: root.openPopup()
            tooltipText: Services.Status.error || Services.Status.errors.cpu || ""
            BarText {
                text: "  " + (root.cpuUsage == null ? "—" : root.cpuUsage + "%")
                color: Theme.cpu
            }
        }
        BarModuleWrapper {
            horizontalPadding: Theme.moduleHorizontalPadding
            verticalPadding: Theme.moduleVerticalPadding
            moduleColor: root.popupVisible ? Theme.transparent : Theme.base
            mouseEnabled: true
            onClicked: root.openPopup()
            tooltipText: Services.Status.error || Services.Status.errors.memory || ""
            BarText {
                text: "  " + (root.memoryUsage == null ? "—" : root.memoryUsage + "%")
                color: Theme.memory
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
        SystemPanel {
            id: content
            snapshot: root.snapshot
            cpuFallback: root.cpuUsage
            memoryFallback: root.memoryUsage
            error: root.error
        }
    }
}
