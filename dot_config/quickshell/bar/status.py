#!/usr/bin/env python3
"""Stream lightweight bar telemetry, retaining the last successful readings."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from telemetry import cpu_ticks, utilization
from network.network import fields


def memory_usage():
    memory = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        memory[key] = int(value.split()[0])
    return round(100 * (1 - memory['MemAvailable'] / memory['MemTotal']))


def disk_usage():
    disk = shutil.disk_usage('/')
    return disk.used * 100 // disk.total


def battery():
    last_error = None
    for path in sorted(Path('/sys/class/power_supply').glob('BAT*')):
        try:
            capacity = int((path / 'capacity').read_text())
            state = (path / 'status').read_text().strip()
            return {'value': capacity, 'charging': state in ('Charging', 'Full')}
        except (OSError, ValueError) as error:
            last_error = error
    if last_error is not None:
        raise last_error
    return {'value': -1, 'charging': False}


def network():
    result = subprocess.run(
        ['nmcli', '--terse', '--colors', 'no', '--fields',
         'TYPE,STATE,CONNECTION', 'device', 'status'],
        capture_output=True, text=True, timeout=2, check=True,
        env={**os.environ, 'LC_ALL': 'C'},
    )
    for line in result.stdout.splitlines():
        kind, state, name = fields(line)
        if state == 'connected' and kind in ('wifi', 'ethernet'):
            strength = -1
            if kind == 'wifi':
                try:
                    signals = subprocess.run(
                        ['nmcli', '--terse', '--colors', 'no', '--fields',
                         'IN-USE,SIGNAL', 'device', 'wifi', 'list', '--rescan', 'no'],
                        capture_output=True, text=True, timeout=2, check=True,
                        env={**os.environ, 'LC_ALL': 'C'},
                    )
                    strength = max((int(signal) for active, signal in
                                    (fields(row) for row in signals.stdout.splitlines())
                                    if active == '*'), default=-1)
                except (subprocess.SubprocessError, ValueError):
                    pass
            return {'kind': kind, 'name': name, 'signal': strength}
    return {'kind': 'down', 'name': ''}


class Collector:
    def __init__(self, executor=None):
        self.data = {'cpu': None, 'memory': None, 'disk': None,
                     'network': {'kind': 'unknown', 'name': ''},
                     'battery': {'value': -1, 'charging': False}}
        self.errors = {}
        self.previous_cpu = None
        self.next_update = {}
        self.network_updated_at = 0
        self.network_executor = executor if executor is not None else ThreadPoolExecutor(max_workers=1)
        self.network_future = None

    def update(self):
        now = time.monotonic()
        try:
            ticks = cpu_ticks()['cpu']
            if self.previous_cpu is not None:
                self.data['cpu'] = round(utilization(self.previous_cpu, ticks))
            self.previous_cpu = ticks
            self.errors.pop('cpu', None)
        except (OSError, ValueError, KeyError) as error:
            self.errors['cpu'] = str(error)
        for key, reader, interval in (
            ('memory', memory_usage, 2), ('disk', disk_usage, 30),
            ('battery', battery, 15),
        ):
            if now < self.next_update.get(key, 0):
                continue
            self.next_update[key] = now + interval
            try:
                self.data[key] = reader()
                self.errors.pop(key, None)
            except (OSError, ValueError, KeyError, ZeroDivisionError,
                    subprocess.SubprocessError) as error:
                self.errors[key] = str(error)
        self.update_network(now)
        return {'data': self.data, 'errors': self.errors,
                'networkUpdatedAt': self.network_updated_at}

    def update_network(self, now):
        # Never wait for nmcli in the CPU/memory sampling loop.
        if self.network_future is not None and self.network_future.done():
            try:
                self.data['network'], self.network_updated_at = self.network_future.result()
                self.errors.pop('network', None)
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                self.errors['network'] = str(error)
            self.network_future = None
        if self.network_future is None and now >= self.next_update.get('network', 0):
            self.next_update['network'] = now + 10
            self.network_future = self.network_executor.submit(network_sample)

    def close(self):
        self.network_executor.shutdown(wait=True, cancel_futures=True)


def network_sample():
    data = network()
    return data, time.time()


def main():
    collector = Collector()
    watching = '--watch' in sys.argv[1:]
    try:
        while True:
            started = time.monotonic()
            response = collector.update()
            if not watching:
                # A one-shot invocation can wait; the persistent stream cannot.
                try:
                    collector.network_future.result()
                except (OSError, ValueError, KeyError, subprocess.SubprocessError):
                    pass
                collector.update_network(time.monotonic())
                response['networkUpdatedAt'] = collector.network_updated_at
            print(json.dumps(response), flush=True)
            if not watching:
                break
            time.sleep(max(0, 2 - (time.monotonic() - started)))
    finally:
        collector.close()


if __name__ == '__main__':
    main()
