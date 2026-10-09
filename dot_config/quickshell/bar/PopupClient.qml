import QtQuick

// Keep each module's content alive while the shared surface moves between it.
Item {
    id: root
    property var parentWindow
    property Item triggerItem
    property Item contentItem
    property real popupWidth: 360
    property bool opened: false
    property bool keyboardFocus: false
    property bool grabFocus: false
    readonly property var host: parentWindow ? parentWindow.popupHost : null
    readonly property bool presented: host !== null && host.shown && host.activeClient === root
    readonly property bool hovered: presented && host.hovered
    default property alias panelData: parking.data
    signal dismissed()

    onOpenedChanged: {
        if (!host) return
        if (opened) host.activate(root)
        else host.close(root)
    }
    function park() {
        if (contentItem) contentItem.parent = parking
    }
    Item { id: parking; visible: false }
    Component.onDestruction: { if (host) host.release(root) }
}
