#!/usr/bin/env python3
"""Read processor, memory and optional GPU telemetry without extra dependencies."""
import glob
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def read(path, default=""):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def number(path, scale=1):
    try:
        return float(read(path)) / scale
    except ValueError:
        return None


def cpu_ticks():
    result = {}
    for line in read('/proc/stat').splitlines():
        fields = line.split()
        if fields and fields[0].startswith('cpu'):
            values = [int(v) for v in fields[1:9]]  # guest time is already in user/nice
            result[fields[0]] = (sum(values), sum(values[3:5]))
    return result


def utilization(before, after):
    total = after[0] - before[0]
    idle = after[1] - before[1]
    return round(max(0, min(100, (total - idle) * 100 / total)), 1) if total else 0


def temperatures(path):
    result = []
    for sensor in sorted(Path(path).glob('temp*_input')):
        value = number(sensor, 1000)
        if value is not None and -20 < value < 150:
            label = read(sensor.with_name(sensor.name.replace('_input', '_label'))).lower()
            result.append((label, value))
    return result


def snapshot():
    first = cpu_ticks()
    time.sleep(.2)
    last = cpu_ticks()
    cores = [utilization(first.get(key, ticks), ticks) for key, ticks in last.items() if key != 'cpu']
    info = []
    for block in read('/proc/cpuinfo').split('\n\n'):
        info.append(dict(tuple(part.strip() for part in line.split(':', 1))
                         for line in block.splitlines() if ':' in line))
    model = next((row.get('model name', row.get('Processor', '')) for row in info if row.get('model name') or row.get('Processor')), 'Processor')
    frequencies = [float(row['cpu MHz']) / 1000 for row in info if 'cpu MHz' in row]
    physical = {(row.get('physical id', '0'), row['core id']) for row in info if 'core id' in row}
    memory = {}
    for line in read('/proc/meminfo').splitlines():
        key, value = line.split(':', 1)
        memory[key] = int(value.split()[0]) * 1024
    total = memory.get('MemTotal', 0)
    available = memory.get('MemAvailable', memory.get('MemFree', 0))
    used = max(0, total - available)
    cache = max(0, memory.get('Cached', 0) + memory.get('SReclaimable', 0) - memory.get('Shmem', 0))
    cpu_temp = None
    gpus = []
    for path in sorted(glob.glob('/sys/class/hwmon/hwmon*')):
        name = read(path + '/name')
        sensors = temperatures(path)
        if name in ('k10temp', 'coretemp', 'zenpower', 'cpu_thermal') and sensors:
            preferred = [value for label, value in sensors if label in ('tctl', 'tdie') or 'package' in label]
            cpu_temp = max(preferred or [value for _, value in sensors])
        if name in ('amdgpu', 'i915', 'xe', 'nouveau'):
            preferred = [value for label, value in sensors if label in ('edge', 'gpu', 'gpu core')]
            gpus.append({'name': {'amdgpu': 'AMD Radeon', 'i915': 'Intel graphics', 'xe': 'Intel graphics', 'nouveau': 'NVIDIA graphics'}[name],
                         'temperature': (preferred or [value for _, value in sensors] or [None])[0],
                         'usage': number(path + '/device/gpu_busy_percent')})
    if cpu_temp is None:
        for zone in glob.glob('/sys/class/thermal/thermal_zone*'):
            if read(zone + '/type').lower() in ('x86_pkg_temp', 'cpu-thermal', 'cpu_thermal'):
                cpu_temp = number(zone + '/temp', 1000)
                if cpu_temp is not None:
                    break
    if shutil.which('nvidia-smi'):
        try:
            result = subprocess.run(['nvidia-smi', '--query-gpu=name,temperature.gpu,utilization.gpu', '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=1)
            for line in result.stdout.splitlines():
                name, temperature, usage = [item.strip() for item in line.split(',', 2)]
                gpus.append({'name': name, 'temperature': float(temperature) if temperature.isdigit() else None,
                             'usage': float(usage) if usage.isdigit() else None})
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
    return {'cpu': {'usage': utilization(first.get('cpu', (0, 0)), last.get('cpu', (0, 0))),
                    'model': model, 'cores': len(physical) or None, 'threads': len(cores),
                    'frequency': round(sum(frequencies) / len(frequencies), 2) if frequencies else None,
                    'temperature': cpu_temp, 'perCore': cores, 'load': list(os.getloadavg())},
            'memory': {'usage': round(used * 100 / total, 1) if total else 0,
                       'total': total, 'used': used, 'available': available, 'cached': cache,
                       'swapTotal': memory.get('SwapTotal', 0),
                       'swapUsed': max(0, memory.get('SwapTotal', 0) - memory.get('SwapFree', 0))},
            'gpus': gpus}


if __name__ == '__main__':
    try:
        print(json.dumps({'ok': True, 'data': snapshot()}))
    except (OSError, ValueError, IndexError) as error:
        print(json.dumps({'ok': False, 'error': 'Could not read system information.'}))
