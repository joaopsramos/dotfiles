import QtQuick
import QtQuick.Controls
import qs

Column {
    id: root
    property var node: null
    property string label: "Volume"
    property bool showDescription: true
    property bool showIcon: false
    property string iconSource: ""
    property color accent: Theme.volume
    readonly property var audio: node ? node.audio : null
    spacing: Theme.spacing
    Row {
        width: parent.width
        height: 30
        Item {
            width: root.showIcon ? 28 : 0
            height: parent.height
            visible: root.showIcon
            Image {
                id: appIcon
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                sourceSize.width: 20
                sourceSize.height: 20
                smooth: true
                mipmap: true
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Text {
                width: 20
                height: parent.height
                visible: appIcon.status !== Image.Ready
                text: ""
                color: root.accent
                font.family: Theme.fontFamily
                font.pixelSize: 18
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Text {
            width: parent.width - mute.width - 8 - (root.showIcon ? 28 : 0)
            height: parent.height
            text: root.label + "  " + (root.audio ? Math.round(root.audio.volume * 100) + "%" : "—")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            verticalAlignment: Text.AlignVCenter
        }
        AudioButton {
            id: mute
            text: root.audio?.muted ? "Unmute" : "Mute"
            backgroundColor: root.audio?.muted ? Theme.green : Theme.red
            textColor: Theme.base
            enabled: root.audio !== null
            onClicked: root.audio.muted = !root.audio.muted
        }
    }
    Text {
        visible: root.showDescription
        width: parent.width
        text: root.node ? root.node.description || root.node.name : "No device available"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }
    Slider {
        id: slider
        HoverHandler {
            enabled: slider.enabled
            cursorShape: Qt.PointingHandCursor
        }
        width: parent.width
        height: 24
        from: 0
        to: 1
        value: root.audio ? root.audio.volume : 0
        enabled: root.audio !== null
        onMoved: root.audio.volume = value
        background: Rectangle {
            x: slider.leftPadding
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Theme.surface0
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: root.accent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 14
            height: 14
            radius: 7
            color: slider.pressed ? Theme.text : root.accent
        }
    }
}
