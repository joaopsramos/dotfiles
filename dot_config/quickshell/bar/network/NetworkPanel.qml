pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs
import qs.components

Item {
    id: root
    property var network: ({
            enabled: false,
            device: "",
            current: {
                name: "Not connected",
                kind: "down",
                address: "",
                gateway: "",
                signal: -1
            },
            networks: [],
            profiles: []
        })
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
    signal settings
    signal focusPassword
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
                text: "Wi-Fi"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.headingFontSize
                font.weight: Font.DemiBold
            }
            ThemedButton {
                horizontalAlignment: Text.AlignLeft
                textFormat: Text.PlainText
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
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
            Column {
                id: details
                x: 10
                y: 10
                width: parent.width - 20
                spacing: 5
                Text {
                    width: parent.width
                    text: root.network.current.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.network
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    width: parent.width
                    text: root.network.current.kind === "down" ? (root.network.enabled ? "Wi-Fi is on" : "Wi-Fi is off") : root.network.current.device + (root.network.current.signal >= 0 ? "  ·  " + root.network.current.signal + "% signal" : "  ·  Ethernet")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
                Text {
                    visible: root.network.current.address !== ""
                    width: parent.width
                    text: "IP  " + root.network.current.address
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
                Text {
                    visible: root.network.current.gateway !== ""
                    width: parent.width
                    text: "Gateway  " + root.network.current.gateway
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
            }
        }

        Column {
            width: parent.width
            visible: root.networkReady && !!root.network.device
            spacing: 0
            TabBar {
                id: connectionTabs
                width: parent.width
                currentIndex: root.savedView ? 1 : 0
                spacing: 0
                background: Item {}
                Repeater {
                    model: ["Nearby", "Saved"]
                    delegate: TabButton {
                        id: tab
                        required property string modelData
                        required property int index
                        width: connectionTabs.width / 2
                        implicitHeight: 34
                        text: modelData
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        onClicked: {
                            root.savedView = index === 1
                            if (root.savedView)
                                root.passwordSsid = ""
                        }
                        contentItem: Text {
                            text: tab.text
                            color: tab.checked ? Theme.text : Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: tab.checked ? Theme.mantle : Theme.transparent
                            topLeftRadius: 6
                            topRightRadius: 6
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: connectionListContent.implicitHeight + 8
                color: Theme.mantle
                radius: Theme.radius
                topLeftRadius: root.savedView ? Theme.radius : 0
                topRightRadius: root.savedView ? 0 : Theme.radius
                Column {
                    id: connectionListContent
                    x: 8
                    y: 8
                    width: parent.width - 16
                    spacing: 8
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
                                readonly property bool connecting: !modelData.active && ((modelData.uuid && root.connectingUuids.includes(modelData.uuid)) || (!root.savedView && root.connectingSsid !== "" && root.connectingSsid === modelData.ssid))
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
                                    color: entry.modelData.active ? Theme.surface0 : entry.expanded || entryMouse.containsMouse ? Theme.surface0 : Theme.transparent
                                }
                                opacity: connecting ? 0.55 : 1
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                                Text {
                                    x: 9
                                    y: 6
                                    width: parent.width - 125
                                    text: root.savedView ? entry.modelData.name : entry.modelData.ssid
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.bodyFontSize
                                }
                                Text {
                                    x: 9
                                    y: 26
                                    width: parent.width - 125
                                    text: entry.connecting ? "Connecting…" : entry.modelData.active ? "Connected" : root.savedView ? (entry.modelData.wifi ? "Saved Wi-Fi" : "Ethernet") : (entry.modelData.security && entry.modelData.security !== "--" ? entry.modelData.security : "Open") + "  ·  " + entry.modelData.signal + "%"
                                    color: entry.modelData.active ? Theme.green : Theme.subtext0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.captionFontSize
                                }
                                Text {
                                    visible: !entry.connecting
                                    anchors.right: parent.right
                                    anchors.rightMargin: 49
                                    y: (48 - height) / 2
                                    text: entry.modelData.active ? "" : "Connect"
                                    color: entry.modelData.active ? Theme.green : Theme.mauve
                                    font.family: Theme.fontFamily
                                    font.pixelSize: entry.modelData.active ? 18 : Theme.smallFontSize
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 52
                                    y: (48 - height) / 2
                                    visible: entry.connecting
                                    text: ""
                                    color: Theme.mauve
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.barFontSize
                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
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
                                    x: 9
                                    y: 50
                                    width: parent.width - 58
                                    spacing: Theme.spacing
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
                                        font.pixelSize: Theme.bodyFontSize
                                        padding: 8
                                        background: Rectangle {
                                            color: Theme.base
                                            radius: 6
                                            border.color: password.activeFocus ? Theme.mauve : Theme.surface1
                                        }
                                        onAccepted: {
                                            if (text.length && !entry.connecting)
                                                connectButton.clicked()
                                        }
                                        Keys.onEscapePressed: root.passwordSsid = ""
                                    }
                                    Row {
                                        spacing: Theme.spacing
                                        ThemedButton {
                                            horizontalAlignment: Text.AlignLeft
                                            textFormat: Text.PlainText
                                            id: connectButton
                                            text: "Connect"
                                            textColor: Theme.green
                                            enabled: !entry.connecting
                                            onClicked: {
                                                if (!password.text.length)
                                                    return
                                                root.joinNetwork(entry.modelData, password.text)
                                                password.clear()
                                            }
                                        }
                                        ThemedButton {
                                            horizontalAlignment: Text.AlignLeft
                                            textFormat: Text.PlainText
                                            text: "Cancel"
                                            textColor: Theme.red
                                            enabled: !entry.connecting
                                            onClicked: root.passwordSsid = ""
                                        }
                                    }
                                    onVisibleChanged: {
                                        if (!visible)
                                            password.clear()
                                    }
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    y: 8
                                    width: 32
                                    height: 32
                                    radius: 6
                                    visible: !!entry.modelData.uuid
                                    color: forgetMouse.containsMouse ? Theme.surface0 : Theme.transparent
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 18
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
                                            font.pixelSize: Theme.smallFontSize
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
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: root.scanning
                            }
                        }
                    }

                    Text {
                        visible: networks.count === 0 && !root.scanning
                        width: parent.width
                        text: root.savedView ? "No saved connections" : !root.network.device ? "No Wi-Fi adapter found" : !root.network.enabled ? "Turn on Wi-Fi to see nearby networks" : "No networks found. Try scanning again."
                        wrapMode: Text.WordWrap
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }
                }
            }
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
            font.pixelSize: Theme.smallFontSize
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surface0
        }

        Row {
            anchors.right: parent.right
            spacing: 6
            ThemedButton {
                horizontalAlignment: Text.AlignLeft
                textFormat: Text.PlainText
                text: "Scan"
                visible: root.networkReady && !!root.network.device
                loading: root.scanning
                enabled: root.network.enabled && root.network.device !== "" && !root.scanning
                onClicked: root.action(["scan", root.network.device])
            }
            ThemedButton {
                horizontalAlignment: Text.AlignLeft
                textFormat: Text.PlainText
                text: "Disconnect"
                visible: root.networkReady && !!root.network.device
                enabled: root.network.current.kind !== "down"
                onClicked: root.action(["disconnect", root.network.current.device])
            }
            ThemedButton {
                horizontalAlignment: Text.AlignLeft
                textFormat: Text.PlainText
                text: "Settings"
                onClicked: root.settings()
            }
        }
    }
}
