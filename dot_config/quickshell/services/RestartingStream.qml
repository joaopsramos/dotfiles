import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property list<string> command
    property int restartDelay: 5000
    signal read(string data)
    signal stopped

    Process {
        id: process
        command: root.command
        running: true
        stdout: SplitParser {
            onRead: data => root.read(data)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn(text.trim())
            }
        }
        // Quickshell qmltypes omit QProcess::ExitStatus.
        // qmllint disable signal-handler-parameters
        onExited: () => {
            root.stopped()
            retry.restart()
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        id: retry
        interval: root.restartDelay
        onTriggered: process.running = true
    }
}
