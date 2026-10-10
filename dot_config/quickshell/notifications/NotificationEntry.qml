import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root
    required property Notification notification
    required property string screenName
    readonly property date receivedAt: new Date()
    property bool hovered: false
    property bool closed: false
    // Quickshell's qmltypes expose this property as an unresolved C++ QList.
    // qmllint disable unresolved-type
    readonly property list<NotificationAction> actions: !closed && notification ? notification.actions : []
    // qmllint enable unresolved-type
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property bool critical: false
    property real progress: -1
    property real remaining: 0
    property real deadline: 0
    signal finished
    signal updated

    function refresh() {
        if (closed || !notification)
            return
        summary = notification.summary
        body = notification.body
        appName = notification.appName || "Notification"
        appIcon = notification.appIcon || ""
        critical = notification.urgency === NotificationUrgency.Critical
        progress = notification.hints.value === undefined ? -1 : Math.max(0, Math.min(100, Number(notification.hints.value)))
        remaining = critical || notification.expireTimeout === 0 ? 0 : notification.expireTimeout < 0 ? 10000 : notification.expireTimeout
        scheduleExpiry()
        updated()
    }
    function dismiss() {
        if (!closed && notification)
            notification.dismiss()
    }
    function activate() {
        if (closed || !notification)
            return
        const action = actions.find(item => item.identifier === "default")
        if (action)
            action.invoke()
        else
            dismiss()
    }
    Component.onCompleted: refresh()

    Connections {
        target: root.notification
        function onSummaryChanged() {
            root.refresh()
        }
        function onBodyChanged() {
            root.refresh()
        }
        function onAppNameChanged() {
            root.refresh()
        }
        function onAppIconChanged() {
            root.refresh()
        }
        function onHintsChanged() {
            root.refresh()
        }
        function onExpireTimeoutChanged() {
            root.refresh()
        }
        function onUrgencyChanged() {
            root.refresh()
        }
        function onClosed() {
            root.closed = true
            expiry.stop()
            removeDelay.start()
        }
    }
    function scheduleExpiry() {
        expiry.stop()
        if (closed || hovered || remaining <= 0)
            return
        deadline = Date.now() + remaining
        expiry.interval = Math.max(1, Math.ceil(remaining))
        expiry.start()
    }
    onHoveredChanged: {
        if (hovered) {
            if (expiry.running)
                remaining = Math.max(1, deadline - Date.now())
            expiry.stop()
        } else
            scheduleExpiry()
    }
    Timer {
        id: expiry
        onTriggered: {
            if (!root.closed && !root.hovered && root.notification) {
                root.remaining = 0
                root.notification.expire()
            }
        }
    }
    Timer {
        id: removeDelay
        interval: 160
        onTriggered: root.finished()
    }
}
