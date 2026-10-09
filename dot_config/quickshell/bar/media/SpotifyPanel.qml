pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs

Column {
    id: root
    property var player: null
    property bool active: false
    property real playbackPosition: 0
    readonly property real duration: player && player.lengthSupported ? Math.max(0, player.length) : 0
    spacing: 14

    function syncPosition() {
        playbackPosition = player && player.positionSupported ? Math.max(0, player.position) : 0
    }
    function timeLabel(seconds) {
        const value = Math.floor(Math.max(0, seconds))
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }
    onPlayerChanged: syncPosition()
    onActiveChanged: { if (active) syncPosition() }
    Connections {
        target: root.player
        function onPositionChanged() { root.syncPosition() }
        function onMetadataChanged() { root.syncPosition() }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.active && !!root.player?.isPlaying && !!root.player?.positionSupported
        onTriggered: root.syncPosition()
    }

    Row {
        width: parent.width
        spacing: 8
        Text {
            text: "󰓇"
            color: Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: 17
        }
        Text {
            text: "Spotify"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }

    }
    Row {
        width: parent.width
        spacing: 18
        Item {
            width: 144; height: 144
            Rectangle {
                anchors.fill: parent
                radius: 72
                color: Qt.alpha(Theme.green, 0.08)
            }
            Canvas {
                id: coverMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "white"
                    ctx.beginPath()
                    for (let i = 0; i <= 360; i++) {
                        const angle = i * Math.PI / 180
                        const radius = 66 + 4 * Math.cos(9 * angle)
                        const x = width / 2 + radius * Math.cos(angle)
                        const y = height / 2 + radius * Math.sin(angle)
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.closePath()
                    ctx.fill()
                }
            }
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: coverMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                Rectangle { anchors.fill: parent; color: Theme.mantle }
                Text {
                    anchors.centerIn: parent
                    text: "󰓇"
                    font.family: Theme.fontFamily
                    font.pixelSize: 52
                    color: Theme.green
                    visible: artwork.status !== Image.Ready
                }
                Image {
                    id: artwork
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    asynchronous: true
                    sourceSize: Qt.size(288, 288)
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
            }
        }
        Column {
            width: parent.width - 162
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                width: parent.width
                text: root.player?.trackTitle || "Nothing playing"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: root.player?.trackArtist || ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: root.player?.trackAlbum || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.overlay1
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
    Column {
        width: parent.width
        spacing: 3
        Slider {
            id: progress
            visible: root.duration > 0 && !!root.player?.positionSupported
            width: parent.width
            height: 24
            from: 0
            to: Math.max(1, root.duration)
            property real seekPosition: 0
            Binding {
                target: progress
                property: "value"
                value: root.playbackPosition
                when: !progress.pressed
            }
            onMoved: seekPosition = value
            enabled: !!root.player?.canSeek
            onPressedChanged: {
                if (pressed) seekPosition = value
                else if (root.player?.canSeek) {
                    root.player.position = seekPosition
                    root.syncPosition()
                }
            }
            background: Rectangle {
                x: progress.leftPadding
                y: (progress.height - height) / 2
                width: progress.availableWidth
                height: 4
                radius: 2
                color: Theme.surface0
                Rectangle {
                    width: progress.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.green
                }
            }
            handle: Rectangle {
                x: progress.leftPadding + progress.visualPosition * (progress.availableWidth - width)
                y: (progress.height - height) / 2
                width: 12; height: 12
                radius: 6
                color: progress.pressed ? Theme.text : Theme.green
            }
        }
        Item {
            width: parent.width
            height: playbackControls.implicitHeight
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: progress.visible
                text: root.timeLabel(progress.pressed ? progress.value : root.playbackPosition)
                color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: progress.visible
                text: "−" + root.timeLabel(root.duration - (progress.pressed ? progress.value : root.playbackPosition))
                color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: 11
            }
        Row {
            id: playbackControls
            anchors.centerIn: parent
            spacing: 8
            PlaybackButton {
                text: "󰒟"
                highlighted: !!root.player?.shuffle
                enabled: !!root.player?.shuffleSupported
                onClicked: root.player.shuffle = !root.player.shuffle
                hint: "Shuffle"
            }
            PlaybackButton {
                symbol: "previous"
                enabled: !!root.player?.canGoPrevious
                onClicked: root.player.previous()
            }
            PlaybackButton {
                symbol: root.player?.isPlaying ? "pause" : "play"
                prominent: true
                enabled: !!root.player?.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            PlaybackButton {
                symbol: "next"
                enabled: !!root.player?.canGoNext
                onClicked: root.player.next()
            }
            PlaybackButton {
                text: root.player?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                highlighted: !!root.player && root.player.loopState !== MprisLoopState.None
                enabled: !!root.player?.loopSupported
                onClicked: {
                    const current = root.player.loopState
                    root.player.loopState = current === MprisLoopState.None ? MprisLoopState.Playlist
                        : current === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
                hint: root.player?.loopState === MprisLoopState.Track ? "Repeat track"
                    : root.player?.loopState === MprisLoopState.Playlist ? "Repeat playlist" : "Repeat off"
            }
        }
        }
    }

    component PlaybackButton: Button {
        id: button
        property bool prominent: false
        property string symbol: ""
        property string hint: ""
        padding: 0
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        ToolTip {
            id: tooltip
            visible: button.hovered && button.hint.length > 0
            text: button.hint
            delay: 350
            padding: 8
            contentItem: Text {
                text: tooltip.text
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            background: Rectangle {
                color: Theme.mantle
                radius: Theme.radius
                border.width: Theme.borderWidth
                border.color: Theme.surface1
            }
        }
        implicitWidth: prominent ? 46 : 42
        implicitHeight: 46
        opacity: enabled ? 1 : 0.35
        contentItem: Item {
            Text {
                anchors.fill: parent
                visible: button.symbol === ""
                transform: Translate { x: -2 }
                text: button.text
                color: button.highlighted ? Theme.green : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Shape {
                anchors.centerIn: parent
                width: 18; height: 18
                visible: button.symbol !== ""
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: button.prominent ? Theme.base : Theme.text
                    PathSvg {
                        path: button.symbol === "previous"
                            ? "M 2 3 H 4 V 15 H 2 Z M 16 3 L 5 9 L 16 15 Z"
                            : button.symbol === "next"
                            ? "M 14 3 H 16 V 15 H 14 Z M 2 3 L 13 9 L 2 15 Z"
                            : button.symbol === "pause"
                            ? "M 3 3 H 7 V 15 H 3 Z M 11 3 H 15 V 15 H 11 Z"
                            : "M 5 2 L 16 9 L 5 16 Z"
                    }
                }
            }
        }
        background: Rectangle {
            radius: height / 2
            color: button.prominent ? (button.hovered ? Qt.lighter(Theme.green, 1.1) : Theme.green)
                : button.hovered ? Theme.surface0 : button.highlighted ? Qt.alpha(Theme.green, 0.12) : "transparent"
            border.width: 0
        }
    }
}
