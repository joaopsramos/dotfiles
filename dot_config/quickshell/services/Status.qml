pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var stats: collector.data
    property var errors: ({})
    property string error: ""
    property var networkOverride: null
    property real networkOverrideAt: 0

    function updateNetwork(current) {
        networkOverride = {
            kind: current.kind,
            signal: current.signal ?? -1,
            name: current.name
        }
        networkOverrideAt = Date.now() / 1000
        collector.data = Object.assign({}, collector.data, {
            network: networkOverride
        })
        const nextErrors = Object.assign({}, errors)
        delete nextErrors.network
        errors = nextErrors
    }

    QtObject {
        id: collector
        property var data: ({
                cpu: null,
                memory: null,
                disk: null,
                network: {
                    kind: "unknown",
                    name: ""
                },
                battery: {
                    value: -1,
                    charging: false
                }
            })
    }
    Process {
        id: process
        command: ["python3", "-u", Quickshell.shellPath("bar/status.py"), "--watch"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const response = JSON.parse(data)
                    if (root.networkOverride && response.networkUpdatedAt < root.networkOverrideAt)
                        response.data.network = root.networkOverride
                    else
                        root.networkOverride = null
                    collector.data = response.data
                    if (root.networkOverride)
                        delete response.errors.network
                    root.errors = response.errors
                    root.error = ""
                } catch (error) {
                    root.error = "Could not read bar telemetry."
                    console.warn(root.error, error)
                }
            }
        }
        // Quickshell qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.error = "Bar telemetry stopped; retrying."
            retry.restart()
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        id: retry
        interval: 5000
        onTriggered: process.running = true
    }
}
