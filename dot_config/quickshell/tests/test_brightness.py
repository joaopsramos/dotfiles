"""Backlight event delivery, deduplication and watcher cleanup."""
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    'brightness', Path(__file__).resolve().parents[1] / 'overlays/brightness.py',
)
brightness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(brightness)


def event(action, subsystem='backlight'):
    return f'KERNEL[1.0] {action}\nACTION={action}\nSUBSYSTEM={subsystem}\n\n'


class BrightnessTests(unittest.TestCase):
    def test_events_emit_only_changes_and_handle_device_removal(self):
        monitor = Mock(stdout=io.StringIO(
            'monitor will print the received events\n\n'
            + event('change', 'power_supply') + event('bind')
            + event('change') + event('change') + event('remove') + event('add')
        ))
        read = Mock(side_effect=[50, 50, 60, -1, 80])
        values = []
        with self.assertRaisesRegex(RuntimeError, 'monitor stopped'):
            brightness.watch(monitor, read=read, emit=values.append)
        self.assertEqual(values, [50, 60, -1, 80])
        self.assertEqual(read.call_count, 5)

    def test_initial_value_is_emitted_without_any_events(self):
        monitor = Mock(stdout=io.StringIO(''))
        values = []
        with self.assertRaises(RuntimeError):
            brightness.watch(monitor, read=lambda: 42, emit=values.append)
        self.assertEqual(values, [42])

    def test_reading_uses_requested_brightness_percentage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            device = root / 'backlight0'
            device.mkdir()
            (device / 'brightness').write_text('75')
            (device / 'actual_brightness').write_text('60')
            (device / 'max_brightness').write_text('100')
            self.assertEqual(brightness.read_brightness(root), 75)
            (device / 'max_brightness').write_text('0')
            self.assertEqual(brightness.read_brightness(root), -1)
        self.assertEqual(brightness.read_brightness(root), -1)

    def test_monitor_is_stopped_when_its_stream_ends(self):
        monitor = Mock(stdout=io.StringIO(''))
        with (
            patch.object(brightness.signal, 'signal'),
            patch.object(brightness.subprocess, 'Popen', return_value=monitor),
            patch.object(brightness, 'watch', side_effect=RuntimeError('stopped')),
        ):
            with self.assertRaises(RuntimeError):
                brightness.main()
        monitor.terminate.assert_called_once()
        monitor.wait.assert_called_once_with(timeout=2)

    def test_unresponsive_monitor_is_killed_during_cleanup(self):
        monitor = Mock()
        monitor.wait.side_effect = [subprocess.TimeoutExpired('udevadm', 2), 0]
        with (
            patch.object(brightness.signal, 'signal'),
            patch.object(brightness.subprocess, 'Popen', return_value=monitor),
            patch.object(brightness, 'watch', side_effect=RuntimeError('stopped')),
        ):
            with self.assertRaises(RuntimeError):
                brightness.main()
        monitor.kill.assert_called_once()


if __name__ == '__main__':
    unittest.main()
