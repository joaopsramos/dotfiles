pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs

FocusScope {
    id: root
    property bool edgeAttached: false
    property string hostname: ""
    property string uptime: ""
    property int selected: 0
    property bool confirming: false
    readonly property var actions: [
        {
            label: "Lock",
            icon: "󰌾",
            detail: "Secure your session",
            accent: Theme.blue
        },
        {
            label: "Suspend",
            icon: "󰤄",
            detail: "Put the computer to sleep",
            accent: Theme.mauve
        },
        {
            label: "Logout",
            icon: "󰍃",
            detail: "End your current session",
            accent: Theme.yellow
        },
        {
            label: "Reboot",
            icon: "󰜉",
            detail: "Restart the computer",
            accent: Theme.peach
        },
        {
            label: "Shutdown",
            icon: "󰐥",
            detail: "Turn off the computer",
            accent: Theme.red
        }
    ]
    signal dismissRequested
    signal executeRequested(int index)
    implicitHeight: content.implicitHeight + 40

    function reset() {
        selected = 0
        confirming = false
    }
    function choose(index) {
        selected = index
        if (index === 0)
            executeRequested(index)
        else {
            confirming = true
        }
    }
    function back() {
        confirming = false
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.confirming)
                root.back()
            else
                root.dismissRequested()
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (!root.confirming)
                root.choose(root.selected)
            else
                root.executeRequested(root.selected)
        } else if (!root.confirming && [Qt.Key_Up, Qt.Key_Backtab].includes(event.key)) {
            root.selected = (root.selected + 4) % 5
        } else if (!root.confirming && [Qt.Key_Down, Qt.Key_Tab].includes(event.key)) {
            root.selected = (root.selected + 1) % 5
        } else if (!root.confirming && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
            root.choose(event.key - Qt.Key_1)
        } else
            return
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        topLeftRadius: root.edgeAttached ? 0 : radius
        topRightRadius: root.edgeAttached ? 0 : radius
        bottomLeftRadius: root.edgeAttached ? 0 : radius
        color: Theme.base
        border.width: Theme.borderWidth
        border.color: Theme.surface1
        // Consume clicks inside the card, including its empty areas.
        MouseArea {
            anchors.fill: parent
            onClicked: root.forceActiveFocus()
        }
    }
    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16
        Row {
            width: parent.width
            spacing: 12
            Rectangle {
                width: 44
                height: 44
                radius: 14
                color: Qt.alpha(Theme.red, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    color: Theme.red
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: "Power menu"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.hostname || "Session"
                    textFormat: Text.PlainText
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surface0
        }
        Column {
            width: parent.width
            spacing: 6
            visible: !root.confirming
            Repeater {
                model: root.actions
                delegate: Button {
                    id: actionButton
                    HoverHandler {
                        enabled: actionButton.enabled
                        cursorShape: Qt.PointingHandCursor
                    }
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 54
                    padding: 10
                    focusPolicy: Qt.NoFocus
                    onHoveredChanged: if (hovered)
                        root.selected = index
                    onClicked: {
                        root.forceActiveFocus()
                        root.choose(index)
                    }
                    contentItem: Row {
                        spacing: 12
                        Text {
                            width: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionButton.modelData.icon
                            color: actionButton.modelData.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 23
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Column {
                            width: actionButton.availableWidth - 42
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text {
                                text: actionButton.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                text: actionButton.modelData.detail
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.captionFontSize
                            }
                        }

                    }
                    background: Rectangle {
                        radius: 10
                        color: root.selected === actionButton.index ? Qt.alpha(actionButton.modelData.accent, 0.10) : Theme.mantle
                        border.width: 1
                        border.color: root.selected === actionButton.index ? Qt.alpha(actionButton.modelData.accent, 0.55) : "transparent"
                    }
                }
            }
        }
        Column {
            width: parent.width
            visible: root.confirming
            spacing: 14
            Text {
                width: parent.width
                text: root.actions[root.selected].label + "?"
                color: root.actions[root.selected].accent
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: root.selected === 1 ? "Your session will resume when you wake the computer." : "Save your work before continuing."
                wrapMode: Text.Wrap
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
            }
            ConfirmButton {
                text: "Confirm"
                width: parent.width
                selected: true
                accent: root.actions[root.selected].accent
                onClicked: root.executeRequested(root.selected)
            }
        }
        Text {
            visible: root.uptime.length > 0
            width: parent.width
            text: "Up " + root.uptime
            color: Theme.overlay1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.captionFontSize
            horizontalAlignment: Text.AlignHCenter
        }
    }
    component ConfirmButton: Button {
        id: button
        HoverHandler {
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
        }
        property bool selected: false
        property color accent: Theme.text
        height: 40
        focusPolicy: Qt.NoFocus
        contentItem: Text {
            text: button.text
            color: button.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 10
            color: button.hovered || button.selected ? Qt.alpha(button.accent, 0.12) : Theme.mantle
            border.width: 1
            border.color: button.selected ? button.accent : Theme.surface0
        }
    }
}
