import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs
import "media"

Item {
    id: root
    property var parentWindow: null
    property real maximumWidth: 400
    readonly property var player: Mpris.players.values.find(player => /^org\.mpris\.MediaPlayer2\.spotify(?:\.|$)/i.test(player.dbusName)) ?? null
    readonly property string track: player ? [player.trackTitle, player.trackArtist].filter(part => part.length > 0).join(" - ") : ""
    visible: player !== null && maximumWidth > 80
    onVisibleChanged: {
        if (!visible)
            popupOpen = false;
    }
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property real popupWidth: Math.max(420, root.width + 24)
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : 34

    function openPopup() {
        if (!parentWindow || !visible)
            return;
        closeDelay.stop();
        popupOpen = true;
    }
    Timer {
        id: openDelay
        interval: 150
        onTriggered: root.openPopup()
    }
    Timer {
        id: closeDelay
        interval: 300
        onTriggered: {
            if (!barHover.hovered && !popupClient.hovered)
                root.popupOpen = false;
        }
    }
    HoverHandler {
        id: barHover
        onHoveredChanged: {
            if (hovered) {
                closeDelay.stop();
                openDelay.restart();
            } else {
                openDelay.stop();
                closeDelay.restart();
            }
        }
    }
    Shape {
        id: frame
        anchors.fill: parent
        visible: root.popupVisible
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.base
            strokeColor: Theme.surface1
            strokeWidth: Theme.borderWidth
            capStyle: ShapePath.FlatCap
            PathSvg {
                path: "M 0.5 " + frame.height + " L 0.5 8.5 Q 0.5 0.5 8.5 0.5 L " + (frame.width - 8.5) + " 0.5 Q " + (frame.width - 0.5) + " 0.5 " + (frame.width - 0.5) + " 8.5 L " + (frame.width - 0.5) + " " + frame.height
            }
        }
    }
    BarModuleWrapper {
        id: module
        anchors.centerIn: parent
        horizontalPadding: 14
        verticalPadding: 6
        moduleColor: root.popupVisible ? "transparent" : Theme.base
        mouseEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton | Qt.BackButton | Qt.ForwardButton
        onClicked: mouse => {
            if (!root.player)
                return;
            if (mouse.button === Qt.LeftButton && root.player.canTogglePlaying)
                root.player.togglePlaying();
            else if ((mouse.button === Qt.MiddleButton || mouse.button === Qt.BackButton) && root.player.canGoPrevious)
                root.player.previous();
            else if ((mouse.button === Qt.RightButton || mouse.button === Qt.ForwardButton) && root.player.canGoNext)
                root.player.next();
        }
        Row {
            id: barContent
            spacing: 8

            BarText {
                id: spotifyIcon
                text: "󰓇"
                color: "#1db954"
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                text: root.track
                textFormat: Text.PlainText
                width: Math.min(implicitWidth, Math.max(0, root.maximumWidth - module.horizontalPadding * 2 - spotifyIcon.width - statusIcon.width - barContent.spacing * 2))
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            BarText {
                id: statusIcon
                text: !root.player ? "" : root.player.playbackState === MprisPlaybackState.Playing ? "" : root.player.playbackState === MprisPlaybackState.Paused ? "󰐌" : ""
                color: root.player?.isPlaying ? Theme.red : Theme.sapphire
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    PopupClient {
        id: popupClient
        parentWindow: root.parentWindow
        triggerItem: root
        popupWidth: root.popupWidth
        opened: root.popupOpen
        contentItem: content
        onDismissed: root.popupOpen = false
        onHoveredChanged: { if (hovered) closeDelay.stop(); else closeDelay.restart() }
        SpotifyPanel {
            id: content
            player: root.player
            active: root.popupOpen
        }
    }
}
