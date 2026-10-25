"""Event-driven direct-camera detection, without requiring camera hardware."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('camera', Path(__file__).resolve().parents[1] / 'privacy/camera.py')
camera = importlib.util.module_from_spec(spec)
spec.loader.exec_module(camera)


class FakeEvents:
    def __init__(self):
        self.added = []
        self.removed = []
        self.queue = []
        self.timeouts = []
        self.closed = False

    def add(self, path, mask):
        self.added.append((path, mask))
        return len(self.added)

    def remove(self, descriptor):
        self.removed.append(descriptor)

    def wait(self, timeout=None):
        self.timeouts.append(timeout)
        return self.queue.pop(0) if self.queue else []

    def close(self):
        self.closed = True


class CameraTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.device = self.directory / 'video0'
        self.device.touch()
        self.events = FakeEvents()
        self.scan = Mock(return_value=['Browser'])
        self.emit = Mock()
        self.watcher = camera.CameraWatcher(self.directory, self.events, self.scan, self.emit)

    def trigger(self, events):
        self.events.queue = [events, []]
        self.watcher.next_update()

    def test_startup_watches_are_installed_before_scan(self):
        def scan(devices):
            self.assertEqual(self.events.added, [
                (self.directory, camera.DIRECTORY_MASK), (self.device, camera.DEVICE_MASK)])
            self.assertEqual(devices, {self.device})
            return ['Browser']
        self.watcher.scan = scan
        self.watcher.update()
        self.emit.assert_called_once_with(['Browser'])

    def test_open_close_rescan_and_suppress_unchanged_output(self):
        self.scan.side_effect = [[], ['Browser'], ['Browser'], []]
        self.watcher.update()
        descriptor = self.watcher.watches[self.device][0]
        self.trigger([(descriptor, camera.OPEN, '')])
        self.trigger([(descriptor, camera.OPEN, '')])
        self.trigger([(descriptor, camera.CLOSE_NOWRITE, '')])
        self.assertEqual([call.args[0] for call in self.emit.call_args_list], [[], ['Browser'], []])
        self.assertEqual(self.scan.call_count, 4)

    def test_burst_debounce_is_bounded_under_continuous_events(self):
        self.watcher.update()
        descriptor = self.watcher.watches[self.device][0]
        self.events.queue = [[(descriptor, camera.OPEN, '')]] * 20
        self.watcher.clock = Mock(side_effect=[0, .01, .02, .03, .04, .05])
        self.watcher.next_update()
        self.assertEqual(self.scan.call_count, 2)
        self.assertEqual(len(self.events.queue), 15)
        self.assertIsNone(self.events.timeouts[0])
        self.assertTrue(all(0 < timeout <= .05 for timeout in self.events.timeouts[1:]))

    def test_hotplug_add_remove_and_non_camera_events(self):
        self.watcher.update()
        second = self.directory / 'video1'
        second.touch()
        self.trigger([(self.watcher.directory_watch, camera.CREATE, 'video1')])
        self.assertEqual(set(self.watcher.watches), {self.device, second})
        descriptor = self.watcher.watches[self.device][0]
        self.device.unlink()
        self.trigger([(self.watcher.directory_watch, camera.DELETE, 'video0')])
        self.assertEqual(set(self.watcher.watches), {second})
        self.assertIn(descriptor, self.events.removed)
        self.assertFalse(self.watcher.relevant([(self.watcher.directory_watch, camera.CREATE, 'videox')]))

    def test_replacement_at_same_path_reconciles_inode(self):
        self.watcher.update()
        old = self.watcher.watches[self.device][0]
        replacement = self.directory / 'replacement'
        replacement.touch()
        replacement.replace(self.device)
        self.trigger([(self.watcher.directory_watch, camera.MOVED_TO, 'video0')])
        self.assertNotEqual(self.watcher.watches[self.device][0], old)
        self.assertIn(old, self.events.removed)

    def test_event_during_initial_scan_is_not_lost(self):
        def startup(devices):
            descriptor = self.watcher.watches[self.device][0]
            self.events.queue = [[(descriptor, camera.OPEN, '')], []]
            return []
        self.watcher.scan = startup
        self.watcher.update()
        self.watcher.scan = Mock(return_value=['Browser'])
        self.watcher.next_update()
        self.assertEqual([call.args[0] for call in self.emit.call_args_list], [[], ['Browser']])

    def test_overflow_rebuilds_watches_and_rescans(self):
        self.watcher.update()
        old = self.watcher.watches[self.device][0]
        self.trigger([(-1, camera.OVERFLOW, '')])
        self.assertNotEqual(self.watcher.watches[self.device][0], old)
        self.assertIn(old, self.events.removed)
        self.assertEqual(self.scan.call_count, 2)

    def test_invalidated_device_and_directory_are_reinstalled(self):
        self.watcher.update()
        old = self.watcher.watches[self.device][0]
        self.trigger([(old, camera.IGNORED, '')])
        self.assertNotEqual(self.watcher.watches[self.device][0], old)
        old_directory = self.watcher.directory_watch
        self.trigger([(old_directory, camera.MOVE_SELF, '')])
        self.assertNotEqual(self.watcher.directory_watch, old_directory)

    def test_idle_wait_has_no_timeout_or_periodic_scan_and_closes_resources(self):
        class Stop(Exception):
            pass
        def idle(timeout=None):
            self.assertIsNone(timeout)
            self.assertEqual(self.scan.call_count, 1)
            raise Stop()
        self.events.wait = idle
        with self.assertRaises(Stop):
            self.watcher.run()
        self.assertTrue(self.events.closed)

    def test_cleanup_when_initial_watch_fails(self):
        self.events.add = Mock(side_effect=OSError('unavailable'))
        with self.assertRaises(OSError):
            self.watcher.run()
        self.assertTrue(self.events.closed)
        self.scan.assert_not_called()

    def test_native_inotify_open_close_and_hotplug(self):
        events = camera.Inotify()
        self.addCleanup(events.close)
        directory_watch = events.add(self.directory, camera.DIRECTORY_MASK)
        device_watch = events.add(self.device, camera.DEVICE_MASK)
        handle = self.device.open()
        opened = events.wait(.5)
        self.assertTrue(any(wd == device_watch and mask & camera.OPEN for wd, mask, name in opened))
        handle.close()
        closed = events.wait(.5)
        self.assertTrue(any(wd == device_watch and mask & camera.CLOSE_NOWRITE for wd, mask, name in closed))
        (self.directory / 'video2').touch()
        self.assertTrue(any(wd == directory_watch and name == 'video2' and mask & camera.CREATE
                            for wd, mask, name in events.wait(.5)))
        self.assertEqual(events.wait(.01), [])

    def test_proc_scan_filters_user_managers_sorts_and_deduplicates(self):
        proc = self.directory / 'proc'
        proc.mkdir()
        for number, binary, name in [(1, 'browser', 'Zebra'), (2, 'chat', 'Alpha'),
                                     (3, 'pipewire', 'Manager'), (4, 'wireplumber', 'Manager'),
                                     (5, 'pipewire-pulse', 'Manager'), (6, 'browser', 'Zebra')]:
            process = proc / str(number)
            (process / 'fd').mkdir(parents=True)
            (process / 'exe').symlink_to('/usr/bin/' + binary)
            (process / 'comm').write_text(name)
            (process / 'fd/0').symlink_to(self.device)
        self.assertEqual(camera.applications({self.device}, proc), ['Alpha', 'Zebra'])
        with patch.object(camera.os, 'getuid', return_value=os.getuid() + 1):
            self.assertEqual(camera.applications({self.device}, proc), [])


if __name__ == '__main__':
    unittest.main()
