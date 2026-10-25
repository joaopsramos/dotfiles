pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as Native

Singleton {
    id: root
    property var bluetoothSource: Native.Bluetooth
    readonly property var state: {
        const adapters = bluetoothSource.adapters.values
        const adapter = adapters.find(item => item.enabled) || adapters[0]
        const devices = adapter ? adapter.devices.values.map(device => ({
            path: device.dbusPath,
            address: device.address,
            name: device.name || device.deviceName || device.address || "Unknown device",
            icon: device.icon,
            connected: device.connected,
            paired: device.paired || device.bonded,
            battery: device.batteryAvailable ? Math.round(device.battery * 100) : null
        })) : []
        devices.sort((a, b) => Number(b.connected) - Number(a.connected)
            || Number(b.paired) - Number(a.paired) || a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
        return {
            adapter: adapter?.dbusPath || "",
            name: adapter?.name || "Bluetooth",
            enabled: adapter?.enabled || false,
            devices
        }
    }
    readonly property bool ready: true
    property string error: ""
    property var viewers: []
    property var currentRequest: []
    property var pendingActions: []
    readonly property var action: currentRequest[0] === "status" ? [] : currentRequest
    readonly property bool busy: action.length > 0 || pendingActions.some(args => args[0] !== "scan")
    readonly property bool scanning: scan.running || pendingActions.some(args => args[0] === "scan")

    function setViewer(viewer, opened) {
        viewers = viewers.filter(item => item !== viewer)
        if (opened) {
            viewers = [...viewers, viewer]
        } else if (viewers.length === 0)
            error = ""
    }
    function runAction(arguments) {
        if (arguments[0] === "scan" && scanning)
            return
        error = ""
        pendingActions = [...pendingActions, arguments]
        nextRequest()
    }
    function startRequest(arguments) {
        currentRequest = arguments
        request.command = ["python3", Quickshell.shellPath("bar/bluetooth/bluetooth.py")].concat(arguments)
        request.running = true
    }
    function nextRequest() {
        if (request.running || currentRequest.length || pendingActions.length === 0)
            return
        const next = pendingActions[0]
        pendingActions = pendingActions.slice(1)
        if (next[0] === "scan") {
            if (!scan.running)
                scan.running = true
            Qt.callLater(root.nextRequest)
        } else
            startRequest(next)
    }
    Process {
        id: request
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.error = ""
                        if (root.action[0] === "power" && root.action[1] === "true" && response.data.enabled)
                            root.runAction(["scan"])
                    } else
                        root.error = response.error
                } catch (error) {
                    root.error = "Could not read Bluetooth information."
                    console.warn(root.error, error)
                }
            }
        }
        // Quickshell qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.currentRequest = []
            Qt.callLater(root.nextRequest)
        }
        // qmllint enable signal-handler-parameters
    }
    // Discovery stays independent so snapshots can show devices as they appear.
    Process {
        id: scan
        command: ["python3", Quickshell.shellPath("bar/bluetooth/bluetooth.py"), "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.error = ""
                    } else
                        root.error = response.error
                } catch (error) {
                    root.error = "Could not scan for devices."
                    console.warn(root.error, error)
                }
            }
        }

    }
}
