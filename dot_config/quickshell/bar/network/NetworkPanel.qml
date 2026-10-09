pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs

Item {
    id: root
    property var network: ({ enabled: false, device: "", current: { name: "Not connected", kind: "down", address: "", gateway: "", signal: -1 }, networks: [], profiles: [] })
    property string error: ""
    property bool networkReady: true
    property bool savedView: false
    property var connectingUuids: []
    property string connectingSsid: ""
    property bool scanning: false
    property bool turningOn: false
    signal action(var arguments)
    property var failedSsids: []
    property string passwordSsid: ""
    signal joinNetwork(var entry, string password)
    signal settings()
    signal focusPassword()
    Timer {
        id: passwordFocusDelay
        interval: 150
        onTriggered: root.focusPassword()
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.Window.window?.active && root.passwordSsid !== "")
                passwordFocusDelay.restart()
        }
    }
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 10

        Row {
            width: parent.width
            height: 32
            Text {
                width: parent.width - toggle.width
                height: parent.height
                text: "Wi-Fi"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
            }
            NetworkButton {
                id: toggle
                visible: root.networkReady
                text: root.network.enabled ? "Turn off" : "Turn on"
                backgroundColor: root.network.enabled ? Theme.red : Theme.green
                textColor: Theme.base
                loading: root.turningOn
                enabled: root.network.device !== "" && !root.turningOn
                onClicked: root.action(["radio", root.network.enabled ? "off" : "on"])
            }
        }

        Rectangle {
            width: parent.width
            height: details.implicitHeight + 20
            radius: 8
            color: Theme.mantle
            opacity: root.connectingUuids.length > 0 || root.connectingSsid !== "" ? 0.55 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Column {
                id: details
                x: 10; y: 10
                width: parent.width - 20
                spacing: 5
                Text {
                    width: parent.width
                    text: root.network.current.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.network
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    text: root.network.current.kind === "down"
                        ? (root.network.enabled ? "Wi-Fi is on" : "Wi-Fi is off")
                        : root.network.current.device + (root.network.current.signal >= 0 ? "  ·  " + root.network.current.signal + "% signal" : "  ·  Ethernet")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    visible: root.network.current.address !== ""
                    width: parent.width
                    text: "IP  " + root.network.current.address
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    visible: root.network.current.gateway !== ""
                    width: parent.width
                    text: "Gateway  " + root.network.current.gateway
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        Row {
            width: parent.width
            spacing: 6
            NetworkButton {
                text: "Nearby"
                selected: !root.savedView
                textColor: root.savedView ? Theme.subtext0 : Theme.mauve
                onClicked: root.savedView = false
            }
            NetworkButton {
                text: "Saved"
                selected: root.savedView
                textColor: root.savedView ? Theme.mauve : Theme.subtext0
                onClicked: { root.passwordSsid = ""; root.savedView = true }
            }
        }

        ScrollView {
            width: parent.width
            height: Math.min(320, networks.count * 52 + (root.passwordSsid !== "" ? 80 : 0))
            visible: networks.count > 0
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ListView {
                id: networks
                model: root.savedView ? root.network.profiles : root.network.networks
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool connecting: !modelData.active &&
                        ((modelData.uuid && root.connectingUuids.includes(modelData.uuid)) ||
                         (!root.savedView && root.connectingSsid !== "" && root.connectingSsid === modelData.ssid))
                    Connections {
                        target: root
                        function onFocusPassword() {
                            if (entry.expanded && !entry.connecting)
                                password.forceActiveFocus()
                        }
                    }
                    readonly property bool expanded: !root.savedView && root.passwordSsid !== "" && root.passwordSsid === modelData.ssid
                    width: networks.width
                    height: expanded ? 128 : 48
                    Rectangle {
                        width: parent.width - 40
                        height: parent.height
                        radius: 7
                        color: entry.modelData.active ? Theme.surface0 : entry.expanded || entryMouse.containsMouse ? Theme.mantle : "transparent"
                    }
                    opacity: connecting ? 0.55 : 1
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Text {
                        x: 9; y: 6
                        width: parent.width - 125
                        text: root.savedView ? entry.modelData.name : entry.modelData.ssid
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Text {
                        x: 9; y: 26
                        width: parent.width - 125
                        text: entry.connecting ? "Connecting…" : entry.modelData.active ? "Connected" : root.savedView
                            ? (entry.modelData.wifi ? "Saved Wi-Fi" : "Ethernet")
                            : (entry.modelData.security && entry.modelData.security !== "--" ? entry.modelData.security : "Open") + "  ·  " + entry.modelData.signal + "%"
                        color: entry.modelData.active ? Theme.green : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        visible: !entry.connecting
                        anchors.right: parent.right
                        anchors.rightMargin: 49
                        y: (48 - height) / 2
                        text: entry.modelData.active ? "✓" : "Connect"
                        color: entry.modelData.active ? Theme.green : Theme.mauve
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 52
                        y: (48 - height) / 2
                        visible: entry.connecting
                        text: ""
                        color: Theme.mauve
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        RotationAnimation on rotation {
                            from: 0; to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: entry.connecting
                        }
                    }
                    MouseArea {
                        id: entryMouse
                        width: parent.width - 40
                        height: 48
                        hoverEnabled: true
                        enabled: !entry.modelData.active && !entry.connecting
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (entry.modelData.uuid && !root.failedSsids.includes(entry.modelData.ssid))
                                root.action(["connect", entry.modelData.uuid])
                            else if (!root.failedSsids.includes(entry.modelData.ssid) && (!entry.modelData.security || entry.modelData.security === "--"))
                                root.joinNetwork(entry.modelData, "")
                            else {
                                root.passwordSsid = entry.modelData.ssid
                                Qt.callLater(() => {
                                    networks.positionViewAtIndex(entry.index, ListView.Contain)
                                    passwordFocusDelay.restart()
                                })
                            }
                        }
                    }
                    Column {
                        x: 9; y: 50
                        width: parent.width - 58
                        spacing: 8
                        visible: entry.expanded
                        TextField {
                            id: password
                            width: parent.width
                            enabled: !entry.connecting
                            placeholderText: "Wi-Fi password"
                            placeholderTextColor: Theme.subtext0
                            echoMode: TextInput.Password
                            color: Theme.text
                            selectionColor: Theme.mauve
                            selectedTextColor: Theme.base
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            padding: 8
                            background: Rectangle {
                                color: Theme.base
                                radius: 6
                                border.color: password.activeFocus ? Theme.mauve : Theme.surface1
                            }
                            onAccepted: { if (text.length && !entry.connecting) connectButton.clicked() }
                            Keys.onEscapePressed: root.passwordSsid = ""
                        }
                        Row {
                            spacing: 8
                            NetworkButton {
                                id: connectButton
                                text: "Connect"
                                enabled: password.text.length > 0 && !entry.connecting
                                onClicked: {
                                    root.joinNetwork(entry.modelData, password.text)
                                    password.clear()
                                }
                            }
                            NetworkButton {
                                text: "Cancel"
                                enabled: !entry.connecting
                                onClicked: root.passwordSsid = ""
                            }
                        }
                        onVisibleChanged: { if (!visible) password.clear() }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        y: 8
                        width: 32
                        height: 32
                        radius: 6
                        visible: !!entry.modelData.uuid
                        color: forgetMouse.containsMouse ? Theme.surface0 : "transparent"
                        Shape {
                            anchors.centerIn: parent
                            width: 16
                            height: 18
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Theme.red
                                strokeWidth: 1.4
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                PathSvg {
                                    path: "M 2 4.5 L 14 4.5 M 5.5 4.5 L 5.5 2 L 10.5 2 L 10.5 4.5 M 3.5 6.5 L 4.2 15.5 Q 4.3 16.5 5.3 16.5 L 10.7 16.5 Q 11.7 16.5 11.8 15.5 L 12.5 6.5 M 6.5 8 L 6.5 13.5 M 9.5 8 L 9.5 13.5"
                                }
                            }
                        }
                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !entry.connecting
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.action(["forget", entry.modelData.uuid])
                        }
                        ToolTip {
                            id: forgetTooltip
                            visible: forgetMouse.containsMouse
                            delay: 500
                            text: "Forget connection"
                            padding: 8
                            contentItem: Text {
                                text: forgetTooltip.text
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                            background: Rectangle {
                                color: Theme.mantle
                                border.color: Theme.surface1
                                radius: 6
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 36
            visible: networks.count === 0 && root.scanning
            Text {
                anchors.centerIn: parent
                text: ""
                color: Theme.mauve
                font.family: Theme.fontFamily
                font.pixelSize: 20
                RotationAnimation on rotation {
                    from: 0; to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.scanning
                }
            }
        }

        Text {
            visible: networks.count === 0 && !root.scanning
            width: parent.width
            text: root.savedView ? "No saved connections" : !root.network.device ? "No Wi-Fi adapter found"
                : !root.network.enabled ? "Turn on Wi-Fi to see nearby networks" : "No networks found. Try scanning again."
            wrapMode: Text.WordWrap
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            visible: root.error !== ""
            width: parent.width
            text: root.error
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 4
            elide: Text.ElideRight
            color: Theme.red
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Rectangle { width: parent.width; height: 1; color: Theme.surface0 }

        Row {
            spacing: 6
            NetworkButton {
                text: "Scan"
                loading: root.scanning
                enabled: root.network.enabled && root.network.device !== "" && !root.scanning
                onClicked: root.action(["scan", root.network.device])
            }
            NetworkButton {
                text: "Disconnect"
                enabled: root.network.current.kind !== "down"
                onClicked: root.action(["disconnect", root.network.current.device])
            }
            NetworkButton { text: "Settings"; onClicked: root.settings() }
        }
    }
}
