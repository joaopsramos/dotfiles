"""Exercise production widgets with fake hardware bridges in a headless shell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]

AUDIO_SERVICE = '''
pragma Singleton
import Quickshell
Singleton {
    property var sink: null
    property var source: null
    property var devices: []
    property var playbackNodes: []
    function applicationIcon(node) { return "" }
}
'''

BLUETOOTH_BRIDGE = '''
import json
from pathlib import Path
import sys
import time
root = Path(__file__).resolve().parents[2]
arguments = sys.argv[1:]
with (root / 'bluetooth-calls.jsonl').open('a') as log:
    log.write(json.dumps(arguments) + '\\n')
time.sleep(0.03)
if arguments[0] == 'pair':
    print(json.dumps({'ok': False, 'error': 'Pairing failed'}))
else:
    print(json.dumps({'ok': True, 'data': {
        'adapter': '/adapter', 'name': 'Test adapter', 'enabled': True,
        'devices': [{'path': '/device/a', 'name': 'Device A', 'icon': 'audio-card',
                     'paired': True, 'connected': False, 'battery': None}],
    }}))
'''

STREAM_BRIDGE = '''
from pathlib import Path
path = Path(__file__).with_name('stream-starts')
count = int(path.read_text()) + 1 if path.exists() else 1
path.write_text(str(count))
print(count, flush=True)
'''

SHELL = '''
import QtQuick
import Quickshell
import qs.services as Services
import qs.bar.audio as AudioWidgets
import qs.bar.bluetooth as BluetoothWidgets
import qs.notifications as Notifications
import qs.downloads as DownloadsWidgets

Scope {
    id: root
    property var failures: []
    property var audioRow: null
    property var bluetoothRow: null
    property bool sawBluetoothError: false
    property int streamStarts: 0
    property int streamStops: 0
    QtObject {
        id: fakeDevice
        property string dbusPath: "/device/a"
        property string address: "AA:BB"
        property string name: "Device A"
        property string deviceName: "Device A"
        property string icon: "audio-card"
        property bool paired: true
        property bool bonded: false
        property bool connected: false
        property bool batteryAvailable: true
        property real battery: 0.5
    }
    QtObject {
        id: fakeAdapter
        property string dbusPath: "/adapter"
        property string name: "Test adapter"
        property bool enabled: true
        property QtObject devices: QtObject { property var values: [fakeDevice] }
    }
    QtObject {
        id: fakeBluetooth
        property QtObject adapters: QtObject { property var values: [fakeAdapter] }
    }

    function check(condition, message) {
        if (!condition) failures = [...failures, message]
    }
    function find(item, predicate) {
        if (predicate(item)) return item
        for (const child of item.children || []) {
            const match = find(child, predicate)
            if (match) return match
        }
        return null
    }
    function node(id, name) {
        return { id: id, properties: { "application.name": name }, name: name,
            description: name, audio: { volume: 0.5, muted: false } }
    }
    DownloadsWidgets.Downloads { id: downloads }
    QtObject {
        id: liveRecord
        readonly property date receivedAt: new Date(Date.now() - 59500)
        property string appName: "Test"
        property string appIcon: ""
        property string summary: "Timestamp expiry"
        property string body: ""
        property bool critical: false
        property bool low: false
    }
    Notifications.NotificationCard { id: timedCard; width: 340; record: liveRecord }
    AudioWidgets.AudioPanel { id: audio; width: 340 }
    BluetoothWidgets.BluetoothPanel { id: bluetooth; width: 340 }
    Notifications.HistoryList {
        id: history
        width: 340
        height: 180
        onRemoveRequested: id => records = records.filter(record => record.id !== id)
    }
    Services.RestartingStream {
        command: ["python3", "-u", Quickshell.shellPath("stream.py")]
        restartDelay: 50
        onRead: data => root.streamStarts++
        onStopped: root.streamStops++
    }
    Connections {
        target: Services.Bluetooth
        function onErrorChanged() {
            if (Services.Bluetooth.error !== "") root.sawBluetoothError = true
        }
    }
    Component.onCompleted: {
        check(timedCard.timeLabel === "now", "Fresh popup timestamp did not show now")
        const first = {path: "/Downloads/first.txt", revision: "unchanged", arrived: 100}
        const second = {path: "/Downloads/second.txt", revision: "unchanged", arrived: 100}
        downloads.entries = [first, second]
        downloads.dismissed = {"/Downloads/first.txt": "unchanged:100"}
        check(downloads.visibleEntries.length === 1, "Dismissed download stayed visible")
        downloads.entries = []
        downloads.entries = [Object.assign({}, first, {arrived: 200}),
                             Object.assign({}, second, {arrived: 200})]
        check(downloads.visibleEntries.length === 2, "Restored download retained an earlier dismissal")
        Services.Audio.playbackNodes = [node(1, "First app")]
        Services.Bluetooth.bluetoothSource = fakeBluetooth
        Services.Bluetooth.runAction(["pair", "/device/a"])
        Services.Bluetooth.runAction(["connect", "/device/a"])
        Services.Bluetooth.runAction(["disconnect", "/device/a"])
        check(Services.Bluetooth.busy, "Queued Bluetooth actions were not busy")
        check(Services.Bluetooth.pendingActions.length === 2, "Bluetooth action queue lost an entry")
        history.records = Array.from({ length: 100 }, (_, i) => ({
            id: i + 1, appName: "Test", summary: "Notification " + i,
            body: "Message ".repeat(i % 5), appIcon: "", critical: false,
            receivedAt: "2026-10-10T12:00:00"
        }))
    }
    Timer {
        interval: 650
        running: true
        onTriggered: {
            root.audioRow = root.find(audio, item => item.showIcon === true && item.node?.id === 1)
            root.bluetoothRow = root.find(bluetooth, item => item.device?.path === "/device/a")
            root.check(root.audioRow !== null, "Audio delegate was not created")
            root.check(root.bluetoothRow !== null, "Bluetooth delegate was not created")
            Services.Audio.playbackNodes = [root.node(1, "Renamed app"), root.node(2, "Second app")]
            fakeDevice.name = "Renamed device"
            fakeDevice.battery = 0.75
            fakeDevice.connected = true
            fakeAdapter.devices.values = [fakeDevice,
                { dbusPath: "/device/b", address: "CC:DD", name: "New device", icon: "input-mouse", paired: false, bonded: false, connected: false, batteryAvailable: false }]
            Qt.callLater(() => {
                root.check(root.audioRow === root.find(audio, item => item.showIcon === true && item.node?.id === 1),
                    "Audio delegate was recreated during a model update")
                root.check(root.audioRow?.label === "Renamed app", "Audio row data was not refreshed")
                root.check(root.bluetoothRow === root.find(bluetooth, item => item.device?.path === "/device/a"),
                    "Bluetooth delegate was recreated during a snapshot update")
                root.check(root.bluetoothRow?.device.name === "Renamed device", "Bluetooth row data was not refreshed")
                root.check(Services.Bluetooth.state.devices[0].battery === 75, "Bluetooth battery event was not applied")
                root.check(Services.Bluetooth.state.devices[0].connected, "Bluetooth connection event was not applied")
                fakeAdapter.enabled = false
                root.check(!Services.Bluetooth.state.enabled, "Bluetooth power event was not applied")
                fakeBluetooth.adapters.values = []
                root.check(Services.Bluetooth.state.adapter === "", "Removed adapter stayed visible")
            })
            history.forceLayout()
            const cards = history.contentItem.children.filter(item => item.record !== undefined)
            root.check(cards.length > 0 && cards.length < 100, "History delegate count: " + cards.length)
            root.check(history.count === 100, "History lost records")
            history.positionViewAtEnd()
        }
    }
    Timer {
        interval: 1800
        running: true
        onTriggered: {
            root.check(timedCard.timeLabel !== "now", "Popup timestamp stayed at now past one minute")
            root.check(root.sawBluetoothError, "Failed Bluetooth action did not report its error")
            root.check(Services.Bluetooth.error === "", "Successful Bluetooth action left a stale error")
            root.check(!Services.Bluetooth.busy && Services.Bluetooth.pendingActions.length === 0,
                "Bluetooth queue did not drain")
            root.check(root.streamStarts >= 2 && root.streamStops >= 1, "Exited watcher was not restarted")
            root.check(root.find(history.contentItem, item => item.record?.id === 100) !== null,
                "History could not scroll to its final record")
            history.removeRequested(100)
            Qt.callLater(() => {
                root.check(history.count === 99, "History removal did not update the model")
                if (root.failures.length) console.error("TEST_FAILED", JSON.stringify(root.failures))
                else console.log("TEST_PASSED: Bluetooth queue/errors, stable rows, watcher recovery, virtual history")
                Qt.quit()
            })
        }
    }
}
'''


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is not installed')
class WidgetTests(unittest.TestCase):
    def test_queue_recovery_row_identity_and_virtual_history(self):
        with tempfile.TemporaryDirectory(prefix='quickshell-widgets-') as directory:
            root = Path(directory)
            for dirname in ('services', 'bar', 'notifications', 'downloads', 'components', 'privacy'):
                for source in (ROOT / dirname).rglob('*.qml'):
                    target = root / source.relative_to(ROOT)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
            shutil.copy2(ROOT / 'Theme.qml', root / 'Theme.qml')
            (root / 'services/Audio.qml').write_text(textwrap.dedent(AUDIO_SERVICE))
            (root / 'bar/bluetooth/bluetooth.py').write_text(textwrap.dedent(BLUETOOTH_BRIDGE))
            # Keep production Downloads state/filtering; offscreen Qt has no
            # PanelWindow backend for its compositor-facing surfaces.
            downloads = root / 'downloads/Downloads.qml'
            downloads.write_text(downloads.read_text().split('    Variants {', 1)[0] + '}\n')
            (root / 'downloads/watch.py').write_text('import time; time.sleep(30)')
            (root / 'stream.py').write_text(textwrap.dedent(STREAM_BRIDGE))
            (root / 'shell.qml').write_text(textwrap.dedent(SHELL))
            runtime = root / 'runtime'
            runtime.mkdir(mode=0o700)
            environment = {
                **os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                'XDG_RUNTIME_DIR': str(runtime), 'PYTHONDONTWRITEBYTECODE': '1',
            }
            environment.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(
                ['quickshell', '-p', str(root), '--no-color'],
                capture_output=True, text=True, timeout=10, env=environment,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('TEST_PASSED', output, output)
            self.assertNotIn('TEST_FAILED', output, output)
            calls = [json.loads(line) for line in
                     (root / 'bluetooth-calls.jsonl').read_text().splitlines()]
            self.assertEqual(calls, [
                ['pair', '/device/a'], ['connect', '/device/a'],
                ['disconnect', '/device/a'],
            ])


if __name__ == '__main__':
    unittest.main()
