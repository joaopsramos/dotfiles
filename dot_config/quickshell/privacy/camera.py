"""Detect applications holding camera devices open (not proof of recording)."""
import ctypes
import errno
import json
import os
from pathlib import Path
import re
import select
import signal
import struct
import time

OPEN, CLOSE_WRITE, CLOSE_NOWRITE = 0x20, 0x8, 0x10
CREATE, DELETE, MOVED_FROM, MOVED_TO = 0x100, 0x200, 0x40, 0x80
DELETE_SELF, MOVE_SELF, UNMOUNT = 0x400, 0x800, 0x2000
OVERFLOW, IGNORED = 0x4000, 0x8000
INVALIDATED = DELETE_SELF | MOVE_SELF | UNMOUNT | IGNORED
DEVICE_MASK = OPEN | CLOSE_WRITE | CLOSE_NOWRITE | DELETE_SELF | MOVE_SELF
DIRECTORY_MASK = CREATE | DELETE | MOVED_FROM | MOVED_TO | DELETE_SELF | MOVE_SELF
DEBOUNCE_SECONDS = 0.05


def camera_devices(directory):
    return {path for path in directory.glob("video[0-9]*")
            if re.fullmatch(r"video[0-9]+", path.name)}


def applications(devices=None, proc=Path("/proc")):
    if devices is None:
        devices = camera_devices(Path("/dev"))
    devices = {str(device) for device in devices}
    if not devices:
        return []
    found = set()
    uid = os.getuid()
    for process in proc.iterdir():
        if not process.name.isdecimal():
            continue
        try:
            if process.stat().st_uid != uid:
                continue
            binary = Path(os.readlink(process / "exe")).name
            # PipeWire clients are detected separately through active graph links.
            if binary in ("pipewire", "wireplumber", "pipewire-pulse"):
                continue
            for descriptor in (process / "fd").iterdir():
                try:
                    if os.readlink(descriptor) in devices:
                        name = (process / "comm").read_text().strip()
                        found.add(name or binary)
                        break
                except OSError:
                    continue
        except OSError:
            continue
    return sorted(found)


class Inotify:
    def __init__(self):
        self.libc = ctypes.CDLL(None, use_errno=True)
        self.libc.inotify_init1.argtypes = [ctypes.c_int]
        self.libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
        self.libc.inotify_rm_watch.argtypes = [ctypes.c_int, ctypes.c_int]
        self.fd = self.libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "Could not start camera watcher")

    def add(self, path, mask):
        descriptor = self.libc.inotify_add_watch(self.fd, os.fsencode(path), mask)
        if descriptor < 0:
            raise OSError(ctypes.get_errno(), "Could not watch camera path", str(path))
        return descriptor

    def remove(self, descriptor):
        self.libc.inotify_rm_watch(self.fd, descriptor)

    def wait(self, timeout=None):
        if not select.select([self.fd], [], [], timeout)[0]:
            return []
        try:
            data = os.read(self.fd, 262144)
        except BlockingIOError:
            return []
        events = []
        offset = 0
        while offset < len(data):
            descriptor, mask, cookie, length = struct.unpack_from("iIII", data, offset)
            offset += 16
            name = os.fsdecode(data[offset:offset + length].split(b"\0", 1)[0])
            offset += length
            events.append((descriptor, mask, name))
        return events

    def close(self):
        if self.fd >= 0:
            os.close(self.fd)
            self.fd = -1


class CameraWatcher:
    def __init__(self, directory=Path("/dev"), events=None, scan=applications,
                 emit=None, clock=time.monotonic):
        self.directory = directory
        self.events = events if events is not None else Inotify()
        self.scan = scan
        self.emit = emit if emit is not None else lambda names: print(json.dumps(names), flush=True)
        self.clock = clock
        self.directory_watch = None
        self.watches = {}  # path -> (watch descriptor, filesystem identity)
        self.previous = None

    def reconcile(self):
        if self.directory_watch is None:
            # Install the parent first: hotplug during enumeration is queued.
            self.directory_watch = self.events.add(self.directory, DIRECTORY_MASK)
        present = {}
        for path in camera_devices(self.directory):
            try:
                stat = path.stat()
                present[path] = (stat.st_dev, stat.st_ino)
            except FileNotFoundError:
                continue
        for path, (descriptor, identity) in list(self.watches.items()):
            if present.get(path) != identity:
                self.events.remove(descriptor)
                del self.watches[path]
        for path, identity in present.items():
            if path not in self.watches:
                try:
                    self.watches[path] = (self.events.add(path, DEVICE_MASK), identity)
                except OSError as error:
                    if error.errno != errno.ENOENT:
                        raise

    def update(self):
        self.reconcile()
        current = self.scan(set(self.watches))
        if current != self.previous:
            self.emit(current)
            self.previous = current

    def relevant(self, events):
        changed = False
        for descriptor, mask, name in events:
            if mask & OVERFLOW:
                # Lost invalidations cannot be inferred from paths alone. Rebuild
                # all watches before scanning so even unchanged nodes recover.
                for watched, identity in self.watches.values():
                    self.events.remove(watched)
                self.watches.clear()
                if self.directory_watch is not None:
                    self.events.remove(self.directory_watch)
                self.directory_watch = None
                changed = True
            elif descriptor == self.directory_watch:
                if mask & INVALIDATED:
                    self.events.remove(descriptor)
                    self.directory_watch = None
                    changed = True
                elif re.fullmatch(r"video[0-9]+", name):
                    changed = True
            else:
                for path, (watched, identity) in list(self.watches.items()):
                    if descriptor == watched:
                        changed = True
                        if mask & INVALIDATED:
                            self.events.remove(descriptor)
                            del self.watches[path]
                        break
        return changed

    def next_update(self):
        # No timeout while idle: /proc is scanned only at startup or on events.
        while not self.relevant(self.events.wait()):
            pass
        deadline = self.clock() + DEBOUNCE_SECONDS
        # Fixed deadline bounds debounce even if opens/closes never stop.
        while (remaining := deadline - self.clock()) > 0:
            events = self.events.wait(remaining)
            if not events:
                break
            self.relevant(events)
        self.update()

    def run(self):
        try:
            # All device watches precede the initial scan. Queued events cover
            # changes during that scan and trigger a subsequent reconciliation.
            self.update()
            while True:
                self.next_update()
        finally:
            self.events.close()


def main():
    def stop(signum, frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    CameraWatcher().run()


if __name__ == "__main__":
    main()
