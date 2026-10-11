pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components

Column {
    id: root
    property var snapshot: ({
            cpu: {},
            memory: {},
            gpus: []
        })
    property var cpuFallback: null
    property var memoryFallback: null
    property string error: ""
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpus: snapshot.gpus || []
    readonly property var gpu: gpus.find(item => item.temperature != null) || gpus[0] || ({})
    spacing: 12

    function size(bytes) {
        if (bytes == null)
            return "—"
        return bytes >= 1073741824 ? (bytes / 1073741824).toFixed(1) + " GiB" : Math.round(bytes / 1048576) + " MiB"
    }
    function temperature(value) {
        return value == null ? "Unavailable" : Math.round(value) + "°C"
    }

    Column {
        width: parent.width
        spacing: 6
        Row {
            width: parent.width
            Text {
                width: parent.width
                text: "System"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.headingFontSize
                font.weight: Font.DemiBold
            }
        }
        Text {
            width: parent.width
            text: root.cpu.model || "Processor and memory"
            textFormat: Text.PlainText
            color: Theme.subtext0
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
        }
    }

    Row {
        width: parent.width
        spacing: 10
        Rectangle {
            width: (parent.width - 20) / 3
            height: 174
            radius: Theme.radius
            color: Theme.mantle
            UsageGauge {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                value: root.gpu.temperature ?? 0
                available: root.gpu.temperature != null
                unit: "°C"
                warningValue: 85
                label: "GPU"
                accent: Theme.sapphire
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 144
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                text: root.gpu.name ? root.gpu.name + (root.gpu.usage != null ? " · " + Math.round(root.gpu.usage) + "%" : "") : "Sensor unavailable"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
            }
        }
        Rectangle {
            width: (parent.width - 20) / 3
            height: 174
            radius: Theme.radius
            color: Theme.mantle
            UsageGauge {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                value: root.cpu.usage ?? root.cpuFallback ?? 0
                available: root.cpu.usage != null || root.cpuFallback != null
                label: "CPU"
                accent: Theme.cpu
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 144
                text: " " + root.temperature(root.cpu.temperature) + (root.cpu.frequency != null ? " · " + root.cpu.frequency.toFixed(1) + " GHz" : "")
                color: root.cpu.temperature >= 85 ? Theme.red : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
            }
        }
        Rectangle {
            width: (parent.width - 20) / 3
            height: 174
            radius: Theme.radius
            color: Theme.mantle
            UsageGauge {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                value: root.memory.usage ?? root.memoryFallback ?? 0
                available: root.memory.usage != null || root.memoryFallback != null
                label: "RAM"
                accent: Theme.memory
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 144
                text: root.size(root.memory.used) + " / " + root.size(root.memory.total)
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
            }
        }
    }

    Row {
        width: parent.width
        spacing: 12
        Rectangle {
            width: (parent.width - 12) / 2
            height: Math.max(memoryGrid.implicitHeight, threadContent.implicitHeight) + 24
            radius: Theme.radius
            color: Theme.mantle
            Column {
                id: threadContent
                x: 12
                y: 12
                width: parent.width - 24
                spacing: Theme.spacing
                Text {
                    text: "Thread activity"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    text: root.cpu.threads ? (root.cpu.cores ? root.cpu.cores + " cores · " : "") + root.cpu.threads + " threads" : ""
                    color: Theme.overlay1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.bodyFontSize
                }
                Grid {
                    id: threadGrid
                    width: parent.width
                    columns: 8
                    spacing: 5
                    Repeater {
                        model: root.cpu.perCore || []
                        Rectangle {
                            required property real modelData
                            width: (threadGrid.width - 35) / 8
                            height: 26
                            radius: 4
                            color: Theme.surface0
                            clip: true
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(2, parent.height * parent.modelData / 100)
                                color: parent.modelData >= 90 ? Theme.red : Theme.cpu
                                opacity: 0.4
                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.slowAnimation
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: Math.round(parent.modelData) + "%"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            width: (parent.width - 12) / 2
            height: Math.max(memoryGrid.implicitHeight, threadContent.implicitHeight) + 24
            radius: Theme.radius
            color: Theme.mantle
            Grid {
                id: memoryGrid
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 24
                    rightMargin: 24
                }
                columns: 2
                rowSpacing: 14
                columnSpacing: 12
                Metric {
                    label: "In use"
                    value: root.size(root.memory.used)
                    accent: Theme.memory
                }
                Metric {
                    label: "Available"
                    alignRight: true
                    value: root.size(root.memory.available)
                    accent: Theme.green
                }
                Metric {
                    label: "Cached"
                    value: root.size(root.memory.cached)
                }
                Metric {
                    label: "Swap"
                    alignRight: true
                    value: root.memory.swapTotal == null ? "—" : root.memory.swapTotal === 0 ? "Disabled" : root.size(root.memory.swapUsed) + " / " + root.size(root.memory.swapTotal)
                }
            }
        }
    }

    Text {
        visible: root.error.length > 0
        width: parent.width
        text: root.error
        wrapMode: Text.Wrap
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
    }

    component Metric: Column {
        property string label
        property string value
        property color accent: Theme.text
        property bool alignRight: false
        width: (memoryGrid.width - 12) / 2
        spacing: 5
        Text {
            width: parent.width
            text: parent.label
            horizontalAlignment: parent.alignRight ? Text.AlignRight : Text.AlignLeft
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
        }
        Text {
            width: parent.width
            text: parent.value
            horizontalAlignment: parent.alignRight ? Text.AlignRight : Text.AlignLeft
            wrapMode: Text.WordWrap
            color: parent.accent
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }
}
