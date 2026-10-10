#!/usr/bin/env python3
"""Read processor, memory and optional GPU telemetry without dependencies."""
import glob
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from telemetry import cpu_ticks, utilization


GPU_NAMES = {
    'amdgpu': 'AMD Radeon',
    'i915': 'Intel graphics',
    'xe': 'Intel graphics',
    'nouveau': 'NVIDIA graphics',
}


def read(path, default=''):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def number(path, scale=1):
    try:
        return float(read(path)) / scale
    except ValueError:
        return None


def temperatures(path):
    result = []
    for sensor in sorted(Path(path).glob('temp*_input')):
        value = number(sensor, 1000)
        if value is not None and -20 < value < 150:
            label_path = sensor.with_name(sensor.name.replace('_input', '_label'))
            result.append((read(label_path).lower(), value))
    return result


def sample_cpu():
    """Reuse the previous popup sample; only the first request needs a delay."""
    try:
        sample = json.loads(os.environ.get('QUICKSHELL_CPU_SAMPLE', 'null'))
        if sample and 0 < time.time() - sample['time'] < 15:
            return sample['ticks'], cpu_ticks()
    except (ValueError, KeyError, TypeError):
        pass
    before = cpu_ticks()
    time.sleep(0.2)
    return before, cpu_ticks()


def read_cpu_info():
    result = []
    for block in read('/proc/cpuinfo').split('\n\n'):
        result.append(dict(
            tuple(part.strip() for part in line.split(':', 1))
            for line in block.splitlines() if ':' in line
        ))
    return result


def read_memory():
    memory = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        memory[key] = int(value.split()[0]) * 1024
    total = memory['MemTotal']
    available = memory.get('MemAvailable', memory.get('MemFree', 0))
    used = max(0, total - available)
    cache = max(0, memory.get('Cached', 0) + memory.get('SReclaimable', 0)
                - memory.get('Shmem', 0))
    return {
        'usage': round(used * 100 / total, 1) if total else 0,
        'total': total,
        'used': used,
        'available': available,
        'cached': cache,
        'swapTotal': memory.get('SwapTotal', 0),
        'swapUsed': max(0, memory.get('SwapTotal', 0) - memory.get('SwapFree', 0)),
    }


def read_sensors():
    cpu_temperature = None
    gpus = []
    for path in sorted(glob.glob('/sys/class/hwmon/hwmon*')):
        name = read(path + '/name')
        sensors = temperatures(path)
        if name in ('k10temp', 'coretemp', 'zenpower', 'cpu_thermal') and sensors:
            preferred = [value for label, value in sensors
                         if label in ('tctl', 'tdie') or 'package' in label]
            cpu_temperature = max(preferred or [value for _, value in sensors])
        if name in GPU_NAMES:
            preferred = [value for label, value in sensors
                         if label in ('edge', 'gpu', 'gpu core')]
            gpus.append({
                'name': GPU_NAMES[name],
                'temperature': (preferred or [value for _, value in sensors] or [None])[0],
                'usage': number(path + '/device/gpu_busy_percent'),
            })
    if cpu_temperature is None:
        for zone in glob.glob('/sys/class/thermal/thermal_zone*'):
            if read(zone + '/type').lower() in ('x86_pkg_temp', 'cpu-thermal', 'cpu_thermal'):
                cpu_temperature = number(zone + '/temp', 1000)
                if cpu_temperature is not None:
                    break
    if shutil.which('nvidia-smi'):
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=name,temperature.gpu,utilization.gpu',
                 '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=1, check=True,
            )
            for line in result.stdout.splitlines():
                name, temperature, usage = [item.strip() for item in line.split(',', 2)]
                gpus.append({
                    'name': name,
                    'temperature': float(temperature) if temperature.isdigit() else None,
                    'usage': float(usage) if usage.isdigit() else None,
                })
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    return cpu_temperature, gpus


def snapshot():
    first, last = sample_cpu()
    sampled_at = time.time()
    cores = [utilization(first.get(key, ticks), ticks)
             for key, ticks in last.items() if key != 'cpu']
    info = read_cpu_info()
    model = next((row.get('model name') or row.get('Processor') for row in info
                  if row.get('model name') or row.get('Processor')), 'Processor')
    frequencies = [float(row['cpu MHz']) / 1000 for row in info if 'cpu MHz' in row]
    physical = {(row.get('physical id', '0'), row['core id'])
                for row in info if 'core id' in row}
    cpu_temperature, gpus = read_sensors()
    return {
        'cpu': {
            'usage': utilization(first.get('cpu', last['cpu']), last['cpu']),
            'model': model,
            'cores': len(physical) or None,
            'threads': len(cores),
            'frequency': round(sum(frequencies) / len(frequencies), 2) if frequencies else None,
            'temperature': cpu_temperature,
            'perCore': cores,
            'load': list(os.getloadavg()),
        },
        'memory': read_memory(),
        'gpus': gpus,
        'cpuSample': {'time': sampled_at, 'ticks': last},
    }


if __name__ == '__main__':
    try:
        print(json.dumps({'ok': True, 'data': snapshot()}))
    except (OSError, ValueError, IndexError, KeyError, TypeError):
        print(json.dumps({'ok': False, 'error': 'Could not read system information.'}))
