"""Small BlueZ bridge; no extra Python packages required."""
import json
import subprocess
import sys


def run(command, timeout=35):
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Bluetooth request failed.")
    return result.stdout


def unwrap(value):
    if isinstance(value, dict):
        if "type" in value and "data" in value:
            return unwrap(value["data"])
        return {key: unwrap(item) for key, item in value.items()}
    if isinstance(value, list):
        return [unwrap(item) for item in value]
    return value


def objects():
    response = json.loads(run([
        "busctl", "--system", "--json=short", "call", "org.bluez", "/",
        "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
    ]))
    return unwrap(response)[0]


def snapshot(managed):
    adapters = [
        (path, interfaces["org.bluez.Adapter1"])
        for path, interfaces in managed.items() if "org.bluez.Adapter1" in interfaces
    ]
    path, adapter = next(
        ((path, props) for path, props in adapters if props.get("Powered")),
        adapters[0] if adapters else ("", {}),
    )
    devices = []
    for device_path, interfaces in managed.items():
        props = interfaces.get("org.bluez.Device1")
        if not props or props.get("Adapter") != path:
            continue
        devices.append({
            "path": device_path,
            "address": props.get("Address", ""),
            "name": (props.get("Alias") or props.get("Name")
                     or props.get("Address", "Unknown device")),
            "icon": props.get("Icon", ""),
            "connected": bool(props.get("Connected")),
            "paired": bool(props.get("Paired") or props.get("Bonded")),
            "battery": interfaces.get("org.bluez.Battery1", {}).get("Percentage"),
        })
    devices.sort(key=lambda item: (
        not item["connected"], not item["paired"], item["name"].lower(),
    ))
    return {
        "adapter": path,
        "name": adapter.get("Alias", "Bluetooth"),
        "enabled": bool(adapter.get("Powered")),
        "devices": devices,
    }


def call(path, interface, method, *arguments):
    return run(["busctl", "--system", "call", "org.bluez", path, interface, method, *arguments])


def perform(arguments):
    managed = objects()
    current = snapshot(managed)
    action = arguments[0] if arguments else "status"
    if action == "status":
        return current
    adapter = current["adapter"]
    if not adapter:
        raise RuntimeError("No Bluetooth adapter is available.")
    if action == "power":
        run([
            "busctl", "--system", "set-property", "org.bluez", adapter,
            "org.bluez.Adapter1", "Powered", "b", arguments[1],
        ])
    elif action == "scan":
        if not current["enabled"]:
            raise RuntimeError("Turn Bluetooth on before scanning.")
        run(["bluetoothctl", "--timeout", "12", "scan", "on"], timeout=18)
    else:
        device = next(
            (item for item in current["devices"] if item["path"] == arguments[1]), None,
        )
        if not device:
            raise RuntimeError("This device is no longer available. Scan and try again.")
        path = device["path"]
        if action == "pair":
            run([
                "bluetoothctl", "--agent", "NoInputNoOutput", "--timeout", "30",
                "pair", device["address"],
            ])
            paired = objects().get(path, {}).get("org.bluez.Device1", {}).get("Paired", False)
            if not paired:
                raise RuntimeError(
                    "Could not pair. Put the device in pairing mode. "
                    "Devices requiring a PIN may need a separate Bluetooth pairing tool."
                )
            run([
                "busctl", "--system", "set-property", "org.bluez", path,
                "org.bluez.Device1", "Trusted", "b", "true",
            ])
            call(path, "org.bluez.Device1", "Connect")
        elif action == "connect":
            call(path, "org.bluez.Device1", "Connect")
        elif action == "disconnect":
            call(path, "org.bluez.Device1", "Disconnect")
        elif action == "forget":
            call(adapter, "org.bluez.Adapter1", "RemoveDevice", "o", path)
        else:
            raise RuntimeError("Unknown Bluetooth action.")
    return snapshot(objects())


def friendly(error):
    message = str(error)
    if "Authentication" in message or "Rejected" in message:
        return "Pairing was rejected. Put the device in pairing mode and try again."
    if "NotReady" in message:
        return "Bluetooth is not ready. Check that it is turned on."
    if "ConnectionAttemptFailed" in message or "Failed to connect" in message:
        return "Could not connect. Make sure the device is turned on and nearby."
    if "org.bluez" in message and (
        "not provided" in message or "not found" in message
        or "activation request failed" in message
    ):
        return "The Bluetooth service is unavailable. Install BlueZ and start the bluetooth service."
    if isinstance(error, subprocess.TimeoutExpired):
        return "The device did not respond. Make sure it is nearby and try again."
    return message


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, "data": perform(sys.argv[1:])}))
    except (RuntimeError, subprocess.TimeoutExpired, ValueError, OSError, KeyError, IndexError) as error:
        print(json.dumps({"ok": False, "error": friendly(error)}))
