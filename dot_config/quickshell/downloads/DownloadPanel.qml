pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.components

Column {
    id: root
    property var entries: []
    property string folderUrl: ""
    signal dismissFile(string path, string revision, real arrived)
    signal closeRequested
    spacing: 12

    function size(bytes) {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB"
            : bytes >= 1024 ? Math.round(bytes / 1024) + " KB" : bytes + " B"
    }
    function fileIcon(mime) {
        if (mime.startsWith("image/")) return "image-x-generic"
        if (mime.startsWith("video/")) return "video-x-generic"
        if (mime.startsWith("audio/")) return "audio-x-generic"
        if (mime === "application/pdf") return "application-pdf"
        if (/zip|compressed|tar|archive/.test(mime)) return "package-x-generic"
        return "text-x-generic"
    }
    Row {
        width: parent.width
        spacing: 8
        Text {
            width: parent.width - folder.width - 8
            text: "Downloads"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.headingFontSize
            font.weight: Font.DemiBold
        }
        ThemedButton {
            id: folder
            text: "Open folder"
            onClicked: Quickshell.execDetached(["thunar", root.folderUrl])
        }
    }
    Text {
        visible: root.entries.length === 0
        width: parent.width
        text: "No recent downloads"
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.bodyFontSize
    }
    Flickable {
        width: parent.width
        height: Math.min(contentHeight, 360)
        contentHeight: list.height
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                model: root.entries
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: list.width
                    height: 64
                    radius: Theme.radius
                    color: open.containsMouse && !dismissButton.hovered ? Theme.surface0 : Theme.mantle
                    Image {
                        id: icon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        sourceSize: Qt.size(28, 28)
                        source: Quickshell.iconPath(root.fileIcon(row.modelData.mime), true)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    Text {
                        x: 12; width: 28; height: parent.height
                        visible: icon.status !== Image.Ready
                        text: "󰈔"
                        color: Theme.blue
                        font.family: Theme.fontFamily
                        font.pixelSize: 25
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Column {
                        x: 52
                        width: parent.width - x - 42
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Text {
                            width: parent.width
                            text: row.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.bodyFontSize
                        }
                        Text {
                            text: root.size(row.modelData.size) + " · " + Qt.formatDateTime(new Date(row.modelData.arrived * 1000), "MMM d, HH:mm")
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.captionFontSize
                        }
                    }
                    MouseArea {
                        id: open
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(row.modelData.url)
                    }
                    ThemedButton {
                        id: dismissButton
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        leftPadding: 0; rightPadding: 0
                        text: "×"
                        backgroundColor: hovered ? Theme.surface0 : Theme.transparent
                        onClicked: root.dismissFile(row.modelData.path, row.modelData.revision, row.modelData.arrived)
                    }
                }
            }
        }
    }
}
