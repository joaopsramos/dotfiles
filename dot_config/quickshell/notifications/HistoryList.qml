pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs

ListView {
    id: root
    property var records: []
    signal removeRequested(var id)
    clip: true
    spacing: Theme.spacing
    reuseItems: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
    model: ScriptModel {
        values: root.records
        objectProp: "id"
    }
    delegate: NotificationCard {
        required property var modelData
        record: modelData
        width: root.width
        onRemove: root.removeRequested(modelData.id)
    }
}
