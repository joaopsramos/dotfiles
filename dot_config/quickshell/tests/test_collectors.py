"""Regression tests for telemetry sampling, failures and network parsing."""
from concurrent.futures import Future
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import threading
import unittest
from unittest.mock import patch

BAR = Path(__file__).resolve().parents[1] / 'bar'
sys.path.insert(0, str(BAR))

import status
import telemetry
from network import network


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


system = load_module('system_details', BAR / 'system/system.py')
battery = load_module('battery_details', BAR / 'battery/battery.py')
storage = load_module('storage_details', BAR / 'storage/storage.py')


class ImmediateExecutor:
    """Complete network work deterministically in collector unit tests."""
    def submit(self, function):
        future = Future()
        try:
            future.set_result(function())
        except Exception as error:
            future.set_exception(error)
        return future

    def shutdown(self, **kwargs):
        pass


class CpuTests(unittest.TestCase):
    def test_guest_ticks_are_not_counted_twice(self):
        with patch.object(Path, 'read_text', return_value='cpu 100 20 30 400 50 6 7 8 90 10\n'):
            self.assertEqual(telemetry.cpu_ticks()['cpu'], (621, 450))

    def test_counter_reset_is_safe(self):
        self.assertEqual(telemetry.utilization((100, 50), (90, 40)), 0)
        self.assertEqual(telemetry.utilization((100, 50), (200, 75)), 75)

    def test_details_reuse_recent_cpu_sample_without_sleeping(self):
        sample = {'time': time.time() - 2, 'ticks': {'cpu': [100, 50]}}
        with (
            patch.dict(os.environ, {'QUICKSHELL_CPU_SAMPLE': json.dumps(sample)}),
            patch.object(system, 'cpu_ticks', return_value={'cpu': (200, 75)}),
            patch.object(system.time, 'sleep') as sleep,
        ):
            before, after = system.sample_cpu()
        sleep.assert_not_called()
        self.assertEqual(telemetry.utilization(before['cpu'], after['cpu']), 75)


class StatusTests(unittest.TestCase):
    def test_readings_survive_failures_and_slow_metrics_are_throttled(self):
        with (
            patch.object(status, 'cpu_ticks', return_value={'cpu': (100, 50)}),
            patch.object(status, 'memory_usage', return_value=42) as memory,
            patch.object(status, 'disk_usage', return_value=60) as disk,
            patch.object(status, 'battery', return_value={'value': 80, 'charging': False}),
            patch.object(status, 'network', return_value={'kind': 'wifi', 'name': 'Office'}) as net,
            patch.object(status.time, 'monotonic', side_effect=[0, 2, 4]),
        ):
            collector = status.Collector(executor=ImmediateExecutor())
            first = collector.update()
            self.assertIsNone(first['data']['cpu'])
            memory.side_effect = OSError('unavailable')
            failed = collector.update()
            self.assertEqual(failed['data']['memory'], 42)
            self.assertIn('memory', failed['errors'])
            memory.side_effect = None
            memory.return_value = 43
            recovered = collector.update()
        self.assertEqual(recovered['data']['memory'], 43)
        self.assertNotIn('memory', recovered['errors'])
        self.assertEqual(disk.call_count, 1)
        self.assertEqual(net.call_count, 1)

    def test_loopback_does_not_appear_as_ethernet(self):
        output = 'loopback:connected:lo\nwifi:connected:Office\\:west\n'
        devices = subprocess.CompletedProcess([], 0, stdout=output)
        signals = subprocess.CompletedProcess([], 0, stdout=':90\n*:72\n')
        with patch.object(status.subprocess, 'run', side_effect=[devices, signals]):
            self.assertEqual(status.network(), {
                'kind': 'wifi', 'name': 'Office:west', 'signal': 72,
            })

    def test_slow_network_does_not_block_cpu_sampling(self):
        entered, release = threading.Event(), threading.Event()

        def slow_network():
            entered.set()
            release.wait(timeout=2)
            return {'kind': 'wifi', 'name': 'Office', 'signal': 72}

        with (
            patch.object(status, 'network', side_effect=slow_network),
            patch.object(status, 'cpu_ticks', side_effect=[
                {'cpu': (100, 50)}, {'cpu': (200, 75)}, {'cpu': (300, 125)},
            ]),
            patch.object(status, 'memory_usage', return_value=42),
            patch.object(status, 'disk_usage', return_value=60),
            patch.object(status, 'battery', return_value={'value': -1, 'charging': False}),
        ):
            collector = status.Collector()
            try:
                collector.update()
                self.assertTrue(entered.wait(timeout=1))
                started = time.perf_counter()
                sample = collector.update()
                self.assertLess(time.perf_counter() - started, 0.5)
                self.assertEqual(sample['data']['cpu'], 75)
                release.set()
                collector.network_future.result(timeout=1)
                self.assertEqual(collector.update()['data']['network']['signal'], 72)
            finally:
                release.set()
                collector.close()

    def test_network_reading_survives_failure_and_recovers(self):
        previous = {'kind': 'wifi', 'name': 'Office', 'signal': 72}
        current = {'kind': 'ethernet', 'name': 'Wired', 'signal': -1}
        with (
            patch.object(status, 'network', side_effect=[previous, OSError('offline'), current]),
            patch.object(status, 'cpu_ticks', return_value={'cpu': (100, 50)}),
            patch.object(status, 'memory_usage', return_value=42),
            patch.object(status, 'disk_usage', return_value=60),
            patch.object(status, 'battery', return_value={'value': -1, 'charging': False}),
            patch.object(status.time, 'monotonic', side_effect=[0, 2, 10, 12, 20, 22]),
        ):
            collector = status.Collector(executor=ImmediateExecutor())
            collector.update()
            self.assertEqual(collector.update()['data']['network'], previous)
            collector.update()
            failed = collector.update()
            self.assertEqual(failed['data']['network'], previous)
            self.assertIn('network', failed['errors'])
            collector.update()
            recovered = collector.update()
            self.assertEqual(recovered['data']['network'], current)
            self.assertNotIn('network', recovered['errors'])


class NetworkTests(unittest.TestCase):
    def test_escaped_fields(self):
        self.assertEqual(network.fields(r'Office\:west:abc\\def:'), ['Office:west', 'abc\\def', ''])

    def test_profile_cache_avoids_per_profile_queries(self):
        now = time.time()
        cache = [{'name': 'Office', 'uuid': 'u1', 'ssid': 'Office:west', 'fetchedAt': now}]

        def fake_nmcli(*args, **kwargs):
            if args == ('radio', 'wifi'):
                return 'enabled'
            if 'device' in args and 'status' in args:
                return 'wlan0:wifi:connected:Office'
            if 'connection' in args and '--get-values' not in args:
                return 'Office:u1:802-11-wireless:wlan0'
            if 'list' in args:
                return '*:Office\\:west:75:WPA2'
            if 'show' in args and 'device' in args:
                return 'IP4.ADDRESS[1]:192.0.2.1/24\nIP4.GATEWAY:192.0.2.254'
            self.fail(f'Unexpected per-profile query: {args}')

        with (
            patch.dict(os.environ, {'QUICKSHELL_NETWORK_PROFILES': json.dumps(cache)}),
            patch.object(network, 'nmcli', side_effect=fake_nmcli),
        ):
            snapshot = network.snapshot()
        self.assertEqual(snapshot['networks'][0]['uuid'], 'u1')
        self.assertEqual(snapshot['current']['name'], 'Office:west')
        self.assertEqual(snapshot['current']['address'], '192.0.2.1/24')


class HardwareTests(unittest.TestCase):
    def test_mount_escapes(self):
        self.assertEqual(storage.unescape(r'/media/My\040Drive'), '/media/My Drive')

    def test_charge_based_battery_units(self):
        values = {'voltage_now': 12000000, 'charge_now': 2000000,
                  'charge_full': 4000000, 'charge_full_design': 5000000,
                  'current_now': 1000000, 'capacity': 50}
        with (
            patch.object(Path, 'read_text', return_value='Discharging'),
            patch.object(battery, 'number', side_effect=lambda path, name: values.get(name)),
        ):
            result = battery.read_battery(Path('/fake/BAT0'))
        self.assertEqual(result['energy'], 24)
        self.assertEqual(result['full'], 48)
        self.assertEqual(result['power'], 12)
        self.assertEqual(result['health'], 80)
        self.assertEqual(result['remaining'], 7200)


if __name__ == '__main__':
    unittest.main()
