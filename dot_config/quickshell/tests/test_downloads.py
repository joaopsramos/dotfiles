"""Downloads arrival timestamps and inotify delivery."""
import importlib.util
import json
import io
import os
from pathlib import Path
import select
import signal
import subprocess
import struct
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / 'downloads/watch.py'
spec = importlib.util.spec_from_file_location('downloads_watch', SCRIPT)
watcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watcher)


class DownloadsTests(unittest.TestCase):
    def test_recency_and_order_use_arrival_not_modification(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            first = folder / 'first.txt'
            second = folder / 'second.txt'
            expired = folder / 'expired.txt'
            for path in (first, second, expired):
                path.write_text('content')
            os.utime(second, (1, 1))
            arrivals = {str(first): 99990, str(second): 99999, str(expired): 1}
            with patch.object(watcher.time, 'time', return_value=100000):
                records = watcher.recent(folder, arrivals)
            self.assertEqual([r['name'] for r in records], ['second.txt', 'first.txt'])
            self.assertEqual(records[0]['arrived'], 99999)

    def test_cache_round_trip_and_missing_files_pruned(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / 'Downloads'
            folder.mkdir()
            cache = Path(tmp) / 'cache' / 'arrivals.json'
            arrivals = {str(folder / 'removed.txt'): 123}
            watcher.save_arrivals(cache, arrivals)
            self.assertEqual(watcher.load_arrivals(cache), arrivals)
            watcher.recent(folder, arrivals)
            self.assertEqual(arrivals, {})
            cache.write_text('invalid')
            self.assertEqual(watcher.load_arrivals(cache), {})

    def test_multiple_arrivals_emit_one_snapshot_and_save_once(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            names = ['first.txt', 'second.txt', 'third.txt']
            events = bytearray()
            for name in names:
                (folder / name).write_text('content')
                encoded = os.fsencode(name) + b'\0'
                events.extend(struct.pack('iIII', 11, watcher.CLOSE_WRITE, 0, len(encoded)))
                events.extend(encoded)
            libc = Mock()
            libc.inotify_init1.return_value = 123
            libc.inotify_add_watch.side_effect = [10, 11]
            output = io.StringIO()
            with (
                patch.object(watcher.ctypes, 'CDLL', return_value=libc),
                patch.object(watcher.select, 'select', side_effect=[None, RuntimeError('end test')]),
                patch.object(watcher.os, 'read', return_value=bytes(events)),
                patch.object(watcher.os, 'close'),
                patch.object(watcher, 'load_arrivals',
                             return_value={str(folder / name): 1 for name in names}),
                patch.object(watcher, 'save_arrivals') as save,
                patch.object(watcher, 'recent', wraps=watcher.recent) as scan,
                patch.object(watcher.sys, 'stdout', output),
            ):
                with self.assertRaisesRegex(RuntimeError, 'end test'):
                    watcher.watch(folder)
            snapshots = [json.loads(line) for line in output.getvalue().splitlines()]
            self.assertEqual(len(snapshots), 2)  # Startup plus the complete batch.
            self.assertEqual({r['name'] for r in snapshots[1]['entries']}, set(names))
            self.assertEqual(snapshots[1]['arrived']['name'], 'third.txt')
            self.assertEqual(scan.call_count, 3)  # Two startup scans, one batch scan.
            self.assertEqual(save.call_count, 2)  # Startup plus one batch write.

    def test_multiple_files_moved_out_and_restored_in_one_batch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'Downloads'
            trash = root / 'Trash'
            folder.mkdir()
            trash.mkdir()
            names = ['first.txt', 'second.txt']
            for name in names:
                (folder / name).write_text('content')
            process = subprocess.Popen(
                ['python3', '-u', str(SCRIPT), str(folder)], stdout=subprocess.PIPE,
                env=dict(os.environ, XDG_CACHE_HOME=str(root / 'cache')),
            )
            def receive():
                self.assertTrue(select.select([process.stdout], [], [], 3)[0])
                return json.loads(process.stdout.readline())
            try:
                initial = receive()
                process.send_signal(signal.SIGSTOP)
                os.waitpid(process.pid, os.WUNTRACED)
                before = time.time()
                for name in names:
                    (folder / name).rename(trash / name)
                for name in names:
                    (trash / name).rename(folder / name)
                process.send_signal(signal.SIGCONT)
                restored = receive()
                self.assertEqual({r['name'] for r in restored['entries']}, set(names))
                self.assertIsNotNone(restored['arrived'])
                originals = {r['path']: r for r in initial['entries']}
                for record in restored['entries']:
                    self.assertGreaterEqual(record['arrived'], before)
                    self.assertEqual(record['revision'], originals[record['path']]['revision'])
            finally:
                process.send_signal(signal.SIGCONT)
                process.terminate()
                process.wait(timeout=3)
                process.stdout.close()

    def test_old_file_move_is_visible_and_arrival_survives_restart(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'Downloads'
            folder.mkdir()
            env = dict(os.environ, XDG_CACHE_HOME=str(root / 'cache'))

            def start():
                return subprocess.Popen(['python3', '-u', str(SCRIPT), str(folder)],
                                        stdout=subprocess.PIPE, text=True, env=env)

            def receive(process):
                self.assertTrue(select.select([process.stdout], [], [], 3)[0], 'No watcher snapshot')
                return json.loads(process.stdout.readline())

            def stop(process):
                process.terminate()
                process.wait(timeout=3)
                process.stdout.close()

            process = start()
            try:
                self.assertEqual(receive(process)['entries'], [])
                old = root / 'old.txt'
                old.write_text('content')
                os.utime(old, (1, 1))
                before = time.time()
                old.rename(folder / 'old.txt')
                snapshot = receive(process)
                self.assertEqual(snapshot['entries'][0]['name'], 'old.txt')
                stamp = snapshot['entries'][0]['arrived']
                self.assertGreaterEqual(stamp, before)
                self.assertEqual(snapshot['arrived']['arrived'], stamp)
            finally:
                stop(process)
            process = start()
            try:
                self.assertEqual(receive(process)['entries'][0]['arrived'], stamp)
            finally:
                stop(process)


if __name__ == '__main__':
    unittest.main()
