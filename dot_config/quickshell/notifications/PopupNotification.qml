pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import qs

Item {
    id: root
    required property NotificationEntry entry
    signal dismissAll
    property bool appeared: false
    property real retainedHeight: 0
    // Keep the complete card intact while sliding out, including its border.
    // Closing also removes native actions, which must not resize the card.
    implicitHeight: entry.closed ? retainedHeight : card.implicitHeight
    height: implicitHeight
    onImplicitHeightChanged: {
        if (!entry.closed)
            retainedHeight = implicitHeight
    }
    opacity: appeared && !entry.closed ? 1 : 0
    Component.onCompleted: {
        retainedHeight = implicitHeight
        appeared = true
    }
    Behavior on opacity {
        NumberAnimation {
            duration: root.entry.closed ? 140 : 180
        }
    }

    NotificationCard {
        id: card
        record: root.entry
        interactive: true
        actions: root.entry.actions
        progress: root.entry.progress
        x: root.appeared && !root.entry.closed ? 0 : root.width
        width: root.width
        height: root.height
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.7
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
        onActivate: root.entry.activate()
        onRemove: root.entry.dismiss()
        onDismissAll: root.dismissAll()
        HoverHandler { onHoveredChanged: root.entry.hovered = hovered }
        Behavior on x {
            NumberAnimation {
                duration: root.entry.closed ? 140 : 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
