"""Watch Downloads using inotify; emit snapshots and completed-file events."""
import ctypes
import json
import hashlib
import mimetypes
import os
from pathlib import Path
import re
import select
import struct
import subprocess
import sys
import time

RECENT_SECONDS = 24 * 60 * 60
MAX_ENTRIES = 20
SLOW_SCAN_SECONDS = 0.5

CREATE, DELETE, MOVED_FROM, MOVED_TO = 0x100, 0x200, 0x40, 0x80
CLOSE_WRITE, DELETE_SELF, MOVE_SELF = 0x8, 0x400, 0x800
IGNORED, OVERFLOW, ISDIR = 0x8000, 0x4000, 0x40000000
MASK = CREATE | DELETE | MOVED_FROM | MOVED_TO | CLOSE_WRITE | DELETE_SELF | MOVE_SELF

def downloads_directory():
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "user-dirs.dirs"
    try:
        match = re.search(r'^XDG_DOWNLOAD_DIR="(.*)"$', config.read_text(), re.MULTILINE)
        if match:
            return Path(match[1].replace("$HOME", str(Path.home()))).absolute()
    except OSError:
        pass
    return Path.home() / "Downloads"

def eligible(path):
    name = path.name.lower()
    return not name.startswith(".") and not name.endswith((".crdownload", ".part", ".partial", ".download", ".tmp", ".!qb", "~"))

def entry(path):
    try:
        if not eligible(path) or not path.is_file():
            return None
        stat = path.stat()
        return {"path": str(path), "url": path.as_uri(), "folderUrl": path.parent.as_uri(),
                "name": path.name, "size": stat.st_size, "modified": stat.st_mtime, "arrived": stat.st_ctime,
                "revision": str(stat.st_mtime_ns) + ":" + str(stat.st_size),
                "mime": mimetypes.guess_type(path.name)[0] or "application/octet-stream"}
    except OSError:
        return None

def arrival_cache(directory):
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    key = hashlib.sha256(os.fsencode(directory)).hexdigest()
    return cache_home / "quickshell" / "downloads" / (key + ".json")


def load_arrivals(cache):
    try:
        values = json.loads(cache.read_text())
        return {path: stamp for path, stamp in values.items()
                if isinstance(stamp, (int, float)) and 0 <= stamp < float("inf")}
    except (OSError, ValueError, AttributeError):
        return {}


def save_arrivals(cache, arrivals):
    try:
        cache.parent.mkdir(parents=True, exist_ok=True)
        temporary = cache.with_suffix(".tmp")
        temporary.write_text(json.dumps(arrivals))
        temporary.replace(cache)
    except OSError as error:
        print("Could not save Downloads arrivals: " + str(error), file=sys.stderr)


def directory_entries(directory):
    return [record for path in directory.iterdir() if (record := entry(path)) is not None]


def recent_records(directory, arrivals):
    try:
        cutoff = time.time() - RECENT_SECONDS
        records = []
        present = set()
        for record in directory_entries(directory):
            key = record["path"]
            present.add(key)
            # Historical arrivals are unknowable on first use. Metadata-change
            # time is a fallback; observed arrivals always use the event time.
            record["arrived"] = arrivals.setdefault(key, record["arrived"])
            if record["arrived"] >= cutoff:
                records.append(record)
        for key in list(arrivals):
            if key not in present:
                del arrivals[key]
        return sorted(records, key=lambda record: record["arrived"], reverse=True)
    except OSError:
        return []


def recent(directory, arrivals):
    return recent_records(directory, arrivals)[:MAX_ENTRIES]


class ScanMonitor:
    def scan(self, directory, arrivals, notify=True):
        started = time.perf_counter()
        records = recent_records(directory, arrivals)
        finished = time.perf_counter()
        elapsed = finished - started
        if notify and elapsed > SLOW_SCAN_SECONDS:
            try:
                subprocess.run([
                    "notify-send", "--app-name=Downloads", "--urgency=critical",
                    "Downloads scan is slow",
                    f"Scanning and sorting {directory} took {elapsed * 1000:.1f} ms (limit: 500 ms).",
                ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=2, check=True)
            except (OSError, subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
                if isinstance(error, subprocess.CalledProcessError):
                    error = error.stderr.strip() or str(error)
                print("Could not send Downloads performance notification: " + str(error), file=sys.stderr)
        return records


def watch(directory):
    libc = ctypes.CDLL(None, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "Could not start Downloads watcher")
    parent_watch = libc.inotify_add_watch(fd, os.fsencode(directory.parent), MASK)
    folder_watch = libc.inotify_add_watch(fd, os.fsencode(directory), MASK)
    if parent_watch < 0 and folder_watch < 0:
        raise OSError(ctypes.get_errno(), "Could not watch Downloads")
    cache = arrival_cache(directory)
    arrival_times = load_arrivals(cache)
    monitor = ScanMonitor()
    known = {record["path"]: record["revision"] for record in monitor.scan(directory, arrival_times, notify=False)}

    def emit(arrived=None, notify=True):
        tracked = monitor.scan(directory, arrival_times, notify=notify)
        present = {record["path"] for record in tracked}
        for path in list(known):
            if path not in present:
                del known[path]
        records = tracked[:MAX_ENTRIES]
        save_arrivals(cache, arrival_times)
        print(json.dumps({"directory": str(directory), "folderUrl": directory.as_uri(),
                          "entries": records, "arrived": arrived}), flush=True)

    emit(notify=False)
    try:
        while True:
            select.select([fd], [], [])
            data = os.read(fd, 262144)
            offset = 0
            changed = False
            arrivals = []
            while offset < len(data):
                descriptor, mask, cookie, length = struct.unpack_from("iIII", data, offset)
                offset += 16
                name = os.fsdecode(data[offset:offset + length].split(b"\0", 1)[0])
                offset += length
                if mask & OVERFLOW:
                    changed = True
                    continue
                if descriptor == parent_watch:
                    if name == directory.name and mask & (CREATE | MOVED_TO):
                        folder_watch = libc.inotify_add_watch(fd, os.fsencode(directory), MASK)
                        changed = True
                    continue
                if descriptor != folder_watch:
                    continue
                if mask & (DELETE_SELF | MOVE_SELF | IGNORED):
                    folder_watch = -1
                    known.clear()
                    arrival_times.clear()
                    changed = True
                    continue
                if mask & ISDIR:
                    continue
                path = directory / name
                if not eligible(path):
                    continue
                if mask & (DELETE | MOVED_FROM):
                    known.pop(str(path), None)
                    arrival_times.pop(str(path), None)
                    changed = True
                if mask & (CLOSE_WRITE | MOVED_TO):
                    record = entry(path)
                    if record and not mask & MOVED_TO and arrival_times.get(str(path), record["arrived"]) < time.time() - RECENT_SECONDS:
                        continue
                    if record and known.get(str(path)) != record["revision"]:
                        known[str(path)] = record["revision"]
                        record["arrived"] = time.time()
                        arrival_times[str(path)] = record["arrived"]
                        arrivals.append(record)
                        changed = True
            if changed:
                # One snapshot and cache write per inotify read. The shelf only
                # needs one arrival to open, even when several files complete.
                emit(arrivals[-1] if arrivals else None)
    finally:
        os.close(fd)

if __name__ == "__main__":
    try:
        watch(Path(sys.argv[1]).absolute() if len(sys.argv) > 1 else downloads_directory())
    except OSError as error:
        print(json.dumps({"error": str(error)}), flush=True)
