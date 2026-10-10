"""Report backlight changes from kernel events, without periodic polling."""
from pathlib import Path
import signal
import subprocess
import sys


MONITOR_COMMAND = [
    'udevadm', 'monitor', '--kernel', '--property', '--subsystem-match=backlight',
]


def read_brightness(directory=Path('/sys/class/backlight')):
    try:
        paths = sorted(directory.iterdir())
    except OSError:
        return -1
    for path in paths:
        try:
            current = int((path / 'brightness').read_text())
            maximum = int((path / 'max_brightness').read_text())
            if maximum > 0:
                return max(0, min(100, round(current * 100 / maximum)))
        except (OSError, ValueError):
            continue
    return -1


def backlight_events(lines):
    """udevadm separates uevents with an empty line."""
    event = {}
    for line in lines:
        line = line.strip()
        if not line:
            if event.get('SUBSYSTEM') == 'backlight':
                yield event
            event = {}
        elif '=' in line:
            key, value = line.split('=', 1)
            event[key] = value


def watch(monitor, read=read_brightness, emit=None):
    if emit is None:
        emit = lambda value: print(value, flush=True)
    previous = read()
    emit(previous)
    for event in backlight_events(monitor.stdout):
        if event.get('ACTION') not in ('add', 'remove', 'change', 'move'):
            continue
        value = read()
        if value != previous:
            emit(value)
            previous = value
    raise RuntimeError('Backlight event monitor stopped')


def main():
    # Terminating the shell helper must also stop its udev monitor.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    monitor = subprocess.Popen(
        MONITOR_COMMAND, stdout=subprocess.PIPE, text=True, bufsize=1,
    )
    try:
        watch(monitor)
    finally:
        monitor.terminate()
        try:
            monitor.wait(timeout=2)
        except subprocess.TimeoutExpired:
            monitor.kill()
            monitor.wait()


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
