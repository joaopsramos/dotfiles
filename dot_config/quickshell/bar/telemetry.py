"""Shared Linux CPU sampling helpers."""
from pathlib import Path


def cpu_ticks():
    """Exclude guest counters, which are already included in user/nice time."""
    result = {}
    for line in Path('/proc/stat').read_text().splitlines():
        fields = line.split()
        if fields and fields[0].startswith('cpu'):
            values = [int(value) for value in fields[1:9]]
            result[fields[0]] = (sum(values), sum(values[3:5]))
    return result


def utilization(before, after):
    total = after[0] - before[0]
    idle = after[1] - before[1]
    if total <= 0:
        return 0
    return round(max(0, min(100, (total - idle) * 100 / total)), 1)
