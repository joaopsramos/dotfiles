"""Validate the stop command with mocked process lookup and signaling."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RecordingStopTests(unittest.TestCase):
    def run_stop(self, pid, name='wf-recorder', status=0):
        line = next(line.strip() for line in
                    (ROOT / 'privacy/ScreenSharing.qml').read_text().splitlines()
                    if line.strip().startswith('command:'))
        command = json.loads(line.removeprefix('command: '))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'hypr-recording'
            state.mkdir()
            if pid is not None:
                (state / 'pid').write_text(pid + '\n')
            mocks = root / 'mocks.bash'
            mocks.write_text('''
ps() {
    printf 'ps %s\\n' "$*" >> "$CALL_LOG"
    printf '%s\\n' "$PROCESS_NAME"
    return "$PROCESS_STATUS"
}
kill() {
    printf 'kill %s\\n' "$*" >> "$CALL_LOG"
}
''')
            log = root / 'calls'
            result = subprocess.run(command, capture_output=True, text=True, timeout=3,
                                    env=dict(os.environ, XDG_RUNTIME_DIR=directory,
                                             BASH_ENV=str(mocks), CALL_LOG=str(log),
                                             PROCESS_NAME=name, PROCESS_STATUS=str(status)))
            self.assertEqual(result.returncode, 0, result.stderr)
            return log.read_text().splitlines() if log.exists() else []

    def test_recorder_receives_sigint(self):
        self.assertEqual(self.run_stop('4321'),
                         ['ps -p 4321 -o comm=', 'kill -INT -- 4321'])

    def test_unrelated_names_are_rejected(self):
        for name in ('bash', 'wf-recorder-other', ' wf-recorder', ''):
            with self.subTest(name=name):
                self.assertEqual(self.run_stop('4321', name), ['ps -p 4321 -o comm='])

    def test_missing_process_is_rejected(self):
        for name in ('', 'wf-recorder'):
            with self.subTest(name=name):
                self.assertEqual(self.run_stop('4321', name, status=1),
                                 ['ps -p 4321 -o comm='])

    def test_invalid_pids_are_rejected_before_lookup(self):
        for pid in ('', '0', '1', '-1', 'abc', '4321; exit 9'):
            with self.subTest(pid=pid):
                self.assertEqual(self.run_stop(pid), [])

    def test_missing_pid_file_is_ignored(self):
        self.assertEqual(self.run_stop(None), [])


if __name__ == '__main__':
    unittest.main()
