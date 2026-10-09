#!/usr/bin/env python3
"""Battery details from sysfs and optional power profile controls."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def number(path, name):
    try:
        return float((path / name).read_text().strip())
    except (OSError, ValueError):
        return None


def read_battery(path):
    state = (path / "status").read_text().strip()
    energy = number(path, "energy_now")
    full = number(path, "energy_full")
    design = number(path, "energy_full_design")
    rate = number(path, "power_now")
    voltage = number(path, "voltage_now")
    if energy is None and voltage:
        charge = number(path, "charge_now")
        charge_full = number(path, "charge_full")
        charge_design = number(path, "charge_full_design")
        energy = charge * voltage / 1e6 if charge is not None else None
        full = charge_full * voltage / 1e6 if charge_full is not None else None
        design = charge_design * voltage / 1e6 if charge_design is not None else None
    if rate is None and voltage:
        current = number(path, "current_now")
        rate = abs(current * voltage / 1e6) if current is not None else None
    remaining = None
    if rate and rate > 0 and energy is not None:
        if state == "Discharging":
            remaining = energy / rate * 3600
        elif state == "Charging" and full is not None:
            remaining = max(0, full - energy) / rate * 3600
    return {
        "value": number(path, "capacity"), "state": state,
        "health": full / design * 100 if full is not None and design else None,
        "power": abs(rate) / 1e6 if rate is not None else None,
        "energy": energy / 1e6 if energy is not None else None,
        "full": full / 1e6 if full is not None else None,
        "cycles": number(path, "cycle_count"), "remaining": remaining,
    }


def profiles_command(*args):
    executable = shutil.which("powerprofilesctl")
    if not executable:
        raise RuntimeError("Power profiles are unavailable")
    result = subprocess.run(
        [executable, *args], capture_output=True, text=True, timeout=5,
        env={**os.environ, "LC_ALL": "C", "PATH": "/usr/bin:/bin:" + os.environ.get("PATH", "")},
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not change power profile")
    return result.stdout.strip()


def snapshot():
    details = {}
    for path in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        try:
            details = read_battery(path)
            break
        except OSError:
            continue
    profiles, active = [], ""
    try:
        listing = profiles_command("list")
        profiles = re.findall(r"^\s*\*?\s*(power-saver|balanced|performance):", listing, re.MULTILINE)
        if profiles:
            active = profiles_command("get")
    except (RuntimeError, OSError, subprocess.TimeoutExpired):
        pass
    return {"battery": details, "profiles": profiles, "activeProfile": active}


def main():
    try:
        args = sys.argv[1:]
        if args:
            if len(args) != 2 or args[0] != "profile" or args[1] not in ("power-saver", "balanced", "performance"):
                raise ValueError("Unsupported power profile")
            profiles_command("set", args[1])
        print(json.dumps({"ok": True, "data": snapshot()}))
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error)}))


if __name__ == "__main__":
    main()
