"""Detect direct webcam access by the current user's applications."""
import glob
import json
import os
from pathlib import Path
import time

def applications():
    devices = set(glob.glob("/dev/video[0-9]*"))
    if not devices:
        return []
    found = set()
    uid = os.getuid()
    for process in Path("/proc").iterdir():
        if not process.name.isdecimal():
            continue
        try:
            if process.stat().st_uid != uid:
                continue
            binary = Path(os.readlink(process / "exe")).name
            # Session managers keep cameras open for discovery. PipeWire
            # clients are detected separately through active graph links.
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

if __name__ == "__main__":
    previous = None
    while True:
        current = applications()
        if current != previous:
            print(json.dumps(current), flush=True)
            previous = current
        time.sleep(1)
