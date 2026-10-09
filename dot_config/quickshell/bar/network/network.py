#!/usr/bin/env python3
"""NetworkManager snapshots and actions for the network popup."""
import json
import os
import subprocess
import sys
import tempfile


def nmcli(*args, wait=8):
    result = subprocess.run(
        ["nmcli", "--wait", str(wait), "--colors", "no", *args],
        capture_output=True, text=True, timeout=wait + 3,
        env={**os.environ, "LC_ALL": "C"},
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "NetworkManager request failed")
    return result.stdout.strip()


def fields(line):
    """Decode nmcli's escaped colon-separated fields."""
    result, current, escaped = [], [], False
    for character in line:
        if escaped:
            current.append(character)
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == ":":
            result.append("".join(current))
            current = []
        else:
            current.append(character)
    if escaped:
        current.append("\\")
    return result + ["".join(current)]


def rows(*args):
    return [fields(line) for line in nmcli("--terse", *args).splitlines() if line]


def profile_exists(uuid):
    return uuid in nmcli("--get-values", "UUID", "connection", "show").splitlines()


def forget_profile(uuid):
    try:
        nmcli("connection", "delete", "uuid", uuid)
    except RuntimeError:
        # NetworkManager may remove an active profile before reporting an error.
        if profile_exists(uuid):
            raise


def snapshot():
    enabled = nmcli("radio", "wifi") == "enabled"
    devices = rows("--fields", "DEVICE,TYPE,STATE,CONNECTION", "device", "status")
    wifi = next((row for row in devices if row[1] == "wifi" and row[2] == "connected"), None)
    wifi = wifi or next((row for row in devices if row[1] == "wifi"), None)
    current = next((row for row in devices if row[2] == "connected" and row[1] in ("wifi", "ethernet")), None)
    device = wifi[0] if wifi else ""
    profiles = []
    for name, uuid, kind, interface in rows("--fields", "NAME,UUID,TYPE,DEVICE", "connection", "show"):
        if kind not in ("802-11-wireless", "wifi", "802-3-ethernet", "ethernet"):
            continue
        ssid = ""
        if kind in ("802-11-wireless", "wifi"):
            try:
                ssid = fields(nmcli("--get-values", "802-11-wireless.ssid", "connection", "show", "uuid", uuid))[0]
            except RuntimeError:
                if profile_exists(uuid):
                    raise
                continue
        profiles.append({"name": name, "uuid": uuid, "ssid": ssid,
                         "wifi": kind in ("802-11-wireless", "wifi"),
                         "active": interface not in ("", "--")})
    networks = {}
    if enabled and device:
        for active, ssid, signal, security in rows("--fields", "IN-USE,SSID,SIGNAL,SECURITY",
                "device", "wifi", "list", "ifname", device, "--rescan", "no"):
            if not ssid:
                continue
            entry = {"ssid": ssid, "signal": int(signal or 0), "security": security,
                     "active": active == "*", "uuid": next((p["uuid"] for p in profiles if p["ssid"] == ssid), "")}
            previous = networks.get(ssid)
            if previous is None or (entry["active"], entry["signal"]) > (previous["active"], previous["signal"]):
                networks[ssid] = entry
    details = {"name": current[3] if current else "Not connected", "kind": current[1] if current else "down",
               "device": current[0] if current else device, "address": "", "gateway": "", "signal": -1}
    if current:
        info = rows("--fields", "IP4.ADDRESS,IP4.GATEWAY", "--mode", "multiline", "device", "show", current[0])
        details["address"] = next((row[1] for row in info if row[0].startswith("IP4.ADDRESS") and len(row) > 1), "")
        details["gateway"] = next((row[1] for row in info if row[0] == "IP4.GATEWAY" and len(row) > 1 and row[1] != "--"), "")
    active_network = next((entry for entry in networks.values() if entry["active"]), None)
    if current and current[1] == "wifi" and active_network:
        details.update(name=active_network["ssid"], signal=active_network["signal"])
    return {"enabled": enabled, "device": device, "current": details,
            "networks": sorted(networks.values(), key=lambda entry: (not entry["active"], -entry["signal"], entry["ssid"])),
            "profiles": profiles}


def friendly_error(error, action):
    message = str(error)
    if action in ("connect", "join"):
        if isinstance(error, subprocess.TimeoutExpired):
            return "Could not connect in time. Check the Wi-Fi password and signal, then try again."
        detail = message.lower()
        if any(reason in detail for reason in (
            "wrong password", "incorrect password", "invalid password",
            "authentication failed", "authentication failure",
            "secrets were required", "no secrets", "secrets were not provided",
            "802-11-wireless-security.psk", "802-11-wireless-security.wep-key",
        )):
            return "Could not sign in to Wi-Fi. Check the password and try again."
    return message


def main():
    try:
        action, *arguments = sys.argv[1:] or ["status"]
        if action == "radio" and arguments in (["on"], ["off"]):
            nmcli("radio", "wifi", arguments[0])
        elif action == "connect" and len(arguments) == 1:
            nmcli("connection", "up", "uuid", arguments[0], wait=30)
        elif action == "join" and len(arguments) in (2, 3):
            password = json.loads(sys.stdin.readline()).get("password", "")
            if "\n" in password or "\r" in password:
                raise ValueError("Password must be a single line")
            uuid = arguments[2] if len(arguments) == 3 else ""
            if uuid:
                # Supply replacement credentials without putting them in process arguments.
                with tempfile.NamedTemporaryFile(mode="w", prefix="quickshell-wifi-") as secrets:
                    secrets.write("802-11-wireless-security.psk:" + password + "\n")
                    secrets.flush()
                    nmcli("connection", "up", "uuid", uuid, "passwd-file", secrets.name, wait=30)
            else:
                result = subprocess.run(
                    ["nmcli", "--wait", "30", "--colors", "no", "--ask",
                     "device", "wifi", "connect", arguments[0], "ifname", arguments[1]],
                    input=password + "\n", capture_output=True, text=True, timeout=33,
                    env={**os.environ, "LC_ALL": "C"},
                )
                if result.returncode:
                    raise RuntimeError(result.stderr.strip() or "Could not connect to the network")
        elif action == "forget" and len(arguments) == 1:
            forget_profile(arguments[0])
        elif action == "disconnect" and len(arguments) == 1:
            nmcli("device", "disconnect", arguments[0], wait=15)
        elif action == "scan" and len(arguments) == 1:
            nmcli("--fields", "SSID", "device", "wifi", "list", "ifname", arguments[0], "--rescan", "yes", wait=15)
        elif action != "status":
            raise ValueError("Unsupported network action")
        data = snapshot()
        print(json.dumps({"ok": True, "data": data}))
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": friendly_error(error, action)}))


if __name__ == "__main__":
    main()
