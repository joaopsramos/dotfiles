import QtQuick
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
            popupOpen = false
    }
    property bool popupOpen: false
    readonly property bool popupVisible: popupClient.presented
    readonly property real popupWidth: Math.max(420, root.width + 24)
    implicitWidth: module.implicitWidth
    implicitHeight: parentWindow ? parentWindow.height : Theme.barHeight

    function openPopup() {
        popupHover.open()
    }
    PopupHover {
        id: popupHover
        triggerHovered: barHover.hovered
        popupHovered: popupClient.hovered
        available: !!root.parentWindow && root.visible
        onOpenRequested: root.popupOpen = true
        onCloseRequested: root.popupOpen = false
    }
    HoverHandler {
        id: barHover
    }
    PopupFrame {
        anchors.fill: parent
        visible: root.popupVisible
    }
    BarModuleWrapper {
        id: module
        anchors.centerIn: parent
        horizontalPadding: 14
        verticalPadding: Theme.moduleVerticalPadding
        moduleColor: root.popupVisible ? "transparent" : Theme.base
        mouseEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton | Qt.BackButton | Qt.ForwardButton
        onClicked: mouse => {
            if (!root.player)
                return
            if (mouse.button === Qt.LeftButton && root.player.canTogglePlaying)
                root.player.togglePlaying()
            else if ((mouse.button === Qt.MiddleButton || mouse.button === Qt.BackButton) && root.player.canGoPrevious)
                root.player.previous()
            else if ((mouse.button === Qt.RightButton || mouse.button === Qt.ForwardButton) && root.player.canGoNext)
                root.player.next()
        }
        Row {
            id: barContent
            spacing: Theme.spacing

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
                text: !root.player ? "" : root.player.isPlaying ? "" : "󰐌"
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
        SpotifyPanel {
            id: content
            player: root.player
            active: root.popupOpen
        }
    }
}
