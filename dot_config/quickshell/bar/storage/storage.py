#!/usr/bin/env python3
"""Local storage usage, block devices and readable drive temperatures."""
import json
from pathlib import Path
import re
import subprocess
import os


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ''


def unescape(value):
    return re.sub(r'\\([0-7]{3})', lambda match: chr(int(match[1], 8)), value)


def usage(path):
    stats = os.statvfs(path)
    unit = stats.f_frsize or stats.f_bsize
    total = stats.f_blocks * unit
    used = (stats.f_blocks - stats.f_bfree) * unit
    available = stats.f_bavail * unit
    return {'total': total, 'used': used, 'available': available,
            'reserved': max(0, total - used - available),
            'usage': round(used * 100 / total, 1) if total else 0}


def snapshot():
    volumes = {}
    root = dict(usage('/'), mountpoints=['/'], source='', filesystem='')
    for line in read('/proc/self/mountinfo').splitlines():
        before, after = line.split(' - ', 1)
        fields, details = before.split(), after.split()
        filesystem, source = details[0], unescape(details[1])
        mount = unescape(fields[4])
        if mount == '/':
            root.update(source=source, filesystem=filesystem)
        if not source.startswith('/dev/') or filesystem in ('tmpfs', 'devtmpfs'):
            continue
        identity = fields[2]
        if identity in volumes:
            if mount not in volumes[identity]['mountpoints']:
                volumes[identity]['mountpoints'].append(mount)
            continue
        try:
            volumes[identity] = dict(usage(mount), mountpoints=[mount], source=source, filesystem=filesystem)
        except OSError:
            continue
    devices = []
    try:
        result = subprocess.run(['lsblk', '-J', '-b', '-o', 'NAME,TYPE,SIZE,MODEL,TRAN,ROTA'],
                                capture_output=True, text=True, timeout=2)
        for disk in json.loads(result.stdout).get('blockdevices', []):
            if disk['type'] != 'disk':
                continue
            temperature = None
            block_device = Path('/sys/class/block', disk['name'], 'device').resolve()
            for sensor in Path('/sys/class/hwmon').glob('hwmon*'):
                if read(sensor / 'name') not in ('nvme', 'drivetemp'):
                    continue
                sensor_device = (sensor / 'device').resolve()
                if sensor_device not in (block_device, block_device.parent):
                    continue
                readings = []
                preferred = []
                for value in sensor.glob('temp*_input'):
                    try:
                        degrees = float(read(value)) / 1000
                        if not -20 < degrees < 150:
                            continue
                        readings.append(degrees)
                        if read(value.with_name(value.name.replace('_input', '_label'))).lower() == 'composite':
                            preferred.append(degrees)
                    except ValueError:
                        pass
                temperature = (preferred or readings or [None])[0]
            devices.append({'name': disk['name'], 'model': (disk.get('model') or disk['name']).strip(),
                            'size': disk['size'], 'kind': 'NVMe SSD' if disk.get('tran') == 'nvme'
                            else 'HDD' if disk.get('rota') else 'SSD',
                            'transport': disk.get('tran') or '', 'temperature': temperature})
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    return {'root': root, 'volumes': sorted(volumes.values(), key=lambda item: ('/' not in item['mountpoints'], item['mountpoints'][0])),
            'devices': devices}


if __name__ == '__main__':
    try:
        print(json.dumps({'ok': True, 'data': snapshot()}))
    except (OSError, ValueError, IndexError):
        print(json.dumps({'ok': False, 'error': 'Could not read storage information.'}))
