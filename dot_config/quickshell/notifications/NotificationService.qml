pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Scope {
    id: root
    property list<NotificationEntry> entries: []
    property alias history: historyStorage.records

    PersistentProperties {
        id: historyStorage
        reloadableId: "notification-history"
        property var records: []
    }

    function remember(entry) {
        const notification = entry.notification
        if (!notification || notification.transient || entry.closed) return
        const record = {
            id: notification.id, summary: entry.summary, body: entry.body,
            appName: entry.appName, appIcon: entry.appIcon, critical: entry.critical,
            receivedAt: Qt.formatDateTime(entry.receivedAt, "yyyy-MM-ddTHH:mm:ss")
        }
        history = [record, ...history.filter(item => item.id !== record.id)].slice(0, 100)
    }
    function removeHistory(id) { history = history.filter(item => item.id !== id) }
    function clearHistory() { history = [] }

    function dismissAll() {
        for (const entry of entries.slice())
            entry.dismiss()
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: false
        onNotification: notification => {
            notification.tracked = true
            const screen = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || ""
            const entry = entryComponent.createObject(root, { notification, screenName: screen })
            root.remember(entry)
            root.entries = [entry, ...root.entries]
        }
    }

    Component {
        id: entryComponent
        NotificationEntry {
            id: entryObject
            onUpdated: root.remember(entryObject)
            onFinished: {
                root.entries = root.entries.filter(entry => entry !== entryObject)
                entryObject.destroy()
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { root.dismissAll() }
        function dismiss(): void {
            const entry = root.entries.find(item => !item.closed)
            if (entry) entry.dismiss()
        }
        function count(): int { return root.entries.filter(item => !item.closed).length }
        function clearHistory(): void { root.clearHistory() }
    }
}
