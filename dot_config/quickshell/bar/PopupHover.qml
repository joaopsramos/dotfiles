import QtQuick
import Quickshell
import qs

Scope {
    id: root
    property bool triggerHovered: false
    property bool popupHovered: false
    property bool available: true
    signal openRequested
    signal closeRequested

    function open() {
        openDelay.stop()
        closeDelay.stop()
        if (available)
            openRequested()
    }
    onTriggerHoveredChanged: {
        if (triggerHovered) {
            closeDelay.stop()
            openDelay.restart()
        } else {
            openDelay.stop()
            closeDelay.restart()
        }
    }
    onPopupHoveredChanged: {
        if (popupHovered)
            closeDelay.stop()
        else
            closeDelay.restart()
    }
    onAvailableChanged: {
        if (!available) {
            openDelay.stop()
            closeDelay.stop()
            closeRequested()
        }
    }
    Timer {
        id: openDelay
        interval: Theme.popupOpenDelay
        onTriggered: root.open()
    }
    Timer {
        id: closeDelay
        interval: Theme.popupCloseDelay
        onTriggered: {
            if (!root.triggerHovered && !root.popupHovered)
                root.closeRequested()
        }
    }
}
