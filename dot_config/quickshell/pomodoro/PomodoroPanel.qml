pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.components

Column {
    id: root
    required property PomodoroTimer timer
    property bool configuring: false
    readonly property var phases: [
        { phase: "focus", label: "Focus" },
        { phase: "short", label: "Short break" },
        { phase: "long", label: "Long break" }
    ]
    readonly property color accent: timer.phase === "focus" ? Theme.mauve : timer.phase === "long" ? Theme.blue : Theme.green
    spacing: 14

    Text {
        width: parent.width
        text: "Pomodoro"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.headingFontSize
        font.weight: Font.DemiBold
    }
    Row {
        width: parent.width
        spacing: 6
        Repeater {
            model: root.phases
            delegate: ThemedButton {
                focusPolicy: Qt.NoFocus
                required property var modelData
                width: (root.width - 12) / 3
                text: modelData.label
                backgroundColor: root.timer.phase === modelData.phase ? Qt.alpha(root.accent, 0.18) : Theme.mantle
                textColor: root.timer.phase === modelData.phase ? root.accent : Theme.subtext0
                onClicked: root.timer.selectPhase(modelData.phase)
            }
        }
    }
    Item {
        width: parent.width
        height: 90
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timer.clockText
                color: root.accent
                font.family: Theme.fontFamily
                font.pixelSize: 48
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timer.label + (root.timer.running ? "" : " · paused")
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.configuring = !root.configuring
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 7; height: 7; radius: 4
                color: index < root.timer.completedShortBreaks ? Theme.green : Theme.surface1
            }
        }

    }
    Row {
        width: parent.width
        spacing: 8
        ThemedButton {
            focusPolicy: Qt.NoFocus
            width: (parent.width - 8) / 2
            text: root.timer.running ? "Pause" : "Start"
            backgroundColor: root.accent
            textColor: Theme.base
            onClicked: root.timer.toggle()
        }
        ThemedButton {
            focusPolicy: Qt.NoFocus
            width: (parent.width - 8) / 2
            text: "Reset"
            onClicked: root.timer.reset()
        }
    }
    Item {
        id: settingsReveal
        width: parent.width
        property real expansion: root.configuring ? 1 : 0
        height: settingsContent.implicitHeight * expansion
        visible: height > 0
        clip: true
        opacity: expansion
        Behavior on expansion {
            NumberAnimation { duration: Theme.normalAnimation; easing.type: Easing.OutCubic }
        }
        Column {
            id: settingsContent
            width: parent.width
            spacing: 8
            Rectangle { width: parent.width; height: 1; color: Theme.surface0 }
            Repeater {
                model: root.phases
                delegate: Row {
                    id: durationRow
                    required property var modelData
                    readonly property color accent: modelData.phase === "focus" ? Theme.mauve : modelData.phase === "long" ? Theme.blue : Theme.green
                    width: root.width
                    spacing: 8
                    Text {
                        width: parent.width - 150
                        height: 30
                        text: durationRow.modelData.label
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.bodyFontSize
                        verticalAlignment: Text.AlignVCenter
                    }
                    ThemedButton {
                        focusPolicy: Qt.NoFocus
                        width: 30
                        leftPadding: 0; rightPadding: 0
                        text: "−"
                        enabled: root.timer.minutes(durationRow.modelData.phase) > 1
                        onClicked: root.timer.configure(durationRow.modelData.phase, root.timer.minutes(durationRow.modelData.phase) - 1)
                    }
                    Text {
                        width: 66
                        height: 30
                        text: root.timer.minutes(durationRow.modelData.phase) + " min"
                        color: durationRow.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.bodyFontSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    ThemedButton {
                        focusPolicy: Qt.NoFocus
                        width: 30
                        leftPadding: 0; rightPadding: 0
                        text: "+"
                        enabled: root.timer.minutes(durationRow.modelData.phase) < 180
                        onClicked: root.timer.configure(durationRow.modelData.phase, root.timer.minutes(durationRow.modelData.phase) + 1)
                    }
                }
            }

        }
    }
}
