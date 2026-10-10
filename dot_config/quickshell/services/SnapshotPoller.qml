import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property string script
    property int interval: 5000
    property var snapshot: ({})
    property string error: ""
    property var viewers: []
    readonly property bool active: viewers.length > 0
    property var pendingActions: []
    property var activeAction: []
    readonly property var processEnvironment: ({
            QUICKSHELL_CPU_SAMPLE: JSON.stringify(snapshot.cpuSample || null)
        })

    function setViewer(viewer, opened) {
        const wasActive = active
        viewers = viewers.filter(item => item !== viewer)
        if (opened)
            viewers = [...viewers, viewer]
        if (opened && !wasActive) {
            error = ""
            refresh()
        }
    }
    function refresh() {
        if (!request.running && activeAction.length === 0 && pendingActions.length === 0)
            enqueue([])
    }
    function execute(arguments) {
        error = ""
        enqueue(arguments)
    }
    function enqueue(arguments) {
        pendingActions = [...pendingActions, arguments]
        nextRequest()
    }
    function nextRequest() {
        if (request.running || pendingActions.length === 0)
            return
        const next = pendingActions[0]
        pendingActions = pendingActions.slice(1)
        activeAction = next
        request.command = ["python3", Quickshell.shellPath(script)].concat(next)
        request.running = true
    }
    Process {
        id: request
        environment: root.processEnvironment
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text)
                    if (response.ok) {
                        root.snapshot = response.data
                        root.error = ""
                    } else
                        root.error = response.error
                } catch (error) {
                    root.error = "Could not read information."
                    console.warn(root.script, error)
                }
            }
        }
        // Quickshell qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.activeAction = []
            Qt.callLater(root.nextRequest)
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
