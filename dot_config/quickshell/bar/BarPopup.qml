import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

Item {
    id: root
    required property var parentWindow
    property PopupClient activeClient: null
    property PopupClient outgoingClient: null
    property bool expanded: false
    property bool shown: false
    property bool initializing: false
    property int direction: 1
    property real targetCenter: 0
    property real targetNeckWidth: 80
    readonly property bool hovered: cardHover.hovered
    readonly property real targetWidth: activeClient ? Math.min(activeClient.popupWidth, popup.width) : 360
    readonly property real targetLeft: Math.max(0, Math.min(popup.width - targetWidth, targetCenter - targetWidth / 2))
    readonly property real targetHeight: activeClient && activeClient.contentItem
        ? Math.min(activeClient.contentItem.implicitHeight + 34, popup.height) : 0
    property real neckCenter: targetCenter
    property real neckWidth: targetNeckWidth
    Behavior on neckCenter { enabled: root.shown && !root.initializing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on neckWidth { enabled: root.shown && !root.initializing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function syncPosition() {
        if (!activeClient || !activeClient.triggerItem) return
        const trigger = activeClient.triggerItem
        targetCenter = trigger.mapToItem(parentWindow.contentItem, trigger.width / 2, 0).x
        targetNeckWidth = trigger.width
    }
    function finishOutgoing() {
        if (outgoingClient) outgoingClient.park()
        outgoingClient = null
    }
    function activate(client) {
        closeFinished.stop()
        if (client === activeClient) { expanded = true; return }
        contentTransition.stop()
        finishOutgoing()
        const wasShown = shown
        const oldCenter = targetCenter
        const oldClient = activeClient
        if (!wasShown) initializing = true
        if (oldClient) {
            outgoingClient = oldClient
            oldClient.contentItem.parent = outgoingPage
            outgoingPage.width = oldClient.contentItem.width
        }
        activeClient = client
        syncPosition()
        direction = targetCenter >= oldCenter ? 1 : -1
        client.contentItem.parent = incomingPage
        client.contentItem.x = 0
        client.contentItem.y = 0
        client.contentItem.width = targetWidth - 24
        scroll.contentY = 0
        if (oldClient) oldClient.dismissed()
        shown = true
        if (wasShown) {
            expanded = true
            contentTransition.restart()
        } else {
            incomingPage.opacity = 1
            incomingPage.x = 0
            outgoingPage.opacity = 0
            // Resolve the collapsed geometry before starting the opening.
            const initialWidth = card.width
            Qt.callLater(() => {
                if (root.activeClient !== client) return
                if (!client.opened) {
                    client.park()
                    root.shown = false
                    root.activeClient = null
                    root.initializing = false
                    return
                }
                root.initializing = false
                root.expanded = true
            })
        }
    }
    function close(client) {
        if (client !== activeClient || !expanded) return
        expanded = false
        closeFinished.restart()
    }
    function dismiss() {
        if (activeClient) {
            close(activeClient)
            activeClient.dismissed()
        }
    }
    function release(client) {
        if (outgoingClient === client) outgoingClient = null
        if (activeClient === client) { activeClient = null; shown = false; expanded = false }
    }
    Timer { interval: 16; running: root.shown; repeat: true; onTriggered: root.syncPosition() }
    Timer {
        id: closeFinished
        interval: 230
        onTriggered: {
            if (root.expanded) return
            contentTransition.stop()
            root.finishOutgoing()
            if (root.activeClient) root.activeClient.park()
            root.shown = false
            root.activeClient = null
        }
    }
    ParallelAnimation {
        id: contentTransition
        NumberAnimation { target: incomingPage; property: "opacity"; from: 0; to: 1; duration: 180 }
        NumberAnimation { target: incomingPage; property: "x"; from: root.direction * 28; to: 0; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: outgoingPage; property: "opacity"; from: 1; to: 0; duration: 150 }
        NumberAnimation { target: outgoingPage; property: "x"; from: 0; to: -root.direction * 28; duration: 220; easing.type: Easing.OutCubic }
        onFinished: root.finishOutgoing()
    }
    HyprlandFocusGrab {
        windows: [root.parentWindow, popup]
        active: root.expanded && !!root.activeClient && root.activeClient.grabFocus
        onCleared: { if (root.activeClient && root.activeClient.grabFocus) root.dismiss() }
    }
    // Quickshell creates PanelWindow at runtime despite its qmltypes annotation.
    // qmllint disable uncreatable-type
    PanelWindow {
    // qmllint enable uncreatable-type
        id: popup
        screen: root.parentWindow.screen
        anchors.top: true
        anchors.left: true
        // Quickshell's qmltypes omit the Margins value type.
        // qmllint disable unqualified unresolved-type
        margins.top: root.parentWindow.margins.top + root.parentWindow.height
        margins.left: root.parentWindow.margins.left
        // qmllint enable unqualified unresolved-type
        implicitWidth: root.parentWindow.width
        // qmllint disable unresolved-type
        implicitHeight: screen ? Math.max(1, screen.height - margins.top - 10) : 800
        // qmllint enable unresolved-type
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.expanded && root.activeClient && root.activeClient.keyboardFocus
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        visible: root.shown
        color: "transparent"
        mask: Region { item: card }
        Item {
            id: card
            x: root.expanded ? root.targetLeft : root.targetCenter - root.targetNeckWidth / 2
            width: root.expanded ? root.targetWidth : root.targetNeckWidth
            height: root.expanded ? root.targetHeight : 0
            clip: true
            Behavior on x { enabled: !root.initializing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: !root.initializing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !root.initializing; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            CalendarSurface {
                anchors.fill: parent
                neckWidth: Math.min(root.neckWidth, parent.width)
                neckCenter: Math.max(neckWidth / 2, Math.min(parent.width - neckWidth / 2, root.neckCenter - card.x))
                fillColor: Theme.base; strokeColor: Theme.surface1; strokeWidth: Theme.borderWidth
            }
            Flickable {
                id: scroll
                x: 12; y: 22
                width: Math.max(0, parent.width - 24)
                height: Math.max(0, parent.height - 34)
                contentHeight: root.activeClient && root.activeClient.contentItem ? root.activeClient.contentItem.implicitHeight : 0
                clip: true
                interactive: root.expanded && !contentTransition.running
                opacity: Math.min(1, Math.max(0, (card.height - 30) / 80))
                boundsBehavior: Flickable.StopAtBounds
                Item {
                    id: incomingPage
                    width: root.targetWidth - 24
                    height: scroll.contentHeight
                }
                Item { id: outgoingPage; enabled: false }
            }
            HoverHandler { id: cardHover }
        }
    }
}
