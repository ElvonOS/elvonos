#!/usr/bin/env python3
"""ElvonOS health layer.

Collects OS and Waydroid health every 15 seconds and publishes it as
/run/elvonos/health.json (world-readable, used by Einstellungen and
`elvonos-health`).  A JSONL history stays in /var/log/elvonos/health/.

Runs as a system service; Waydroid probes are executed as the desktop user so
the per-user state (session, bridge, graphics profile) is visible.
"""
import json
import os
import socket
import subprocess
import time
from pathlib import Path

RUN_DIR = Path("/run/elvonos")
STATUS_FILE = RUN_DIR / "health.json"
LOG_DIR = Path("/var/log/elvonos")
HEALTH_LOG = LOG_DIR / "health" / "health.jsonl"
CRASH_LOG = LOG_DIR / "crash"
INTERVAL = 15
LOG_EVERY = 4  # keep one JSONL entry per minute

DESKTOP_USER = os.environ.get("ELVONOS_USER", "elvon")
DESKTOP_HOME = os.environ.get("ELVONOS_HOME", "/home/elvon")


def ensure_dirs():
    for directory in (RUN_DIR, LOG_DIR / "health", CRASH_LOG):
        directory.mkdir(parents=True, exist_ok=True)
    RUN_DIR.chmod(0o755)


def notify_watchdog():
    """Send WATCHDOG=1 to systemd when running under it (no python-systemd)."""
    address = os.environ.get("NOTIFY_SOCKET")
    if not address:
        return
    if address.startswith("@"):
        address = "\0" + address[1:]
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.connect(address)
            sock.sendall(b"WATCHDOG=1")
    except OSError:
        pass


def run(command, timeout=10, as_user=False):
    argv = list(command)
    if as_user:
        argv = ["runuser", "-u", DESKTOP_USER, "--", "env",
                "HOME=" + DESKTOP_HOME, "USER=" + DESKTOP_USER] + argv
    try:
        result = subprocess.run(argv, capture_output=True, text=True,
                                timeout=timeout)
        return result.stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def read_json(command, as_user=False, timeout=10):
    output = run(command, timeout=timeout, as_user=as_user)
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("{") or line.startswith("["):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def check_memory():
    try:
        info = {}
        with open("/proc/meminfo") as handle:
            for line in handle:
                parts = line.split()
                if len(parts) >= 2:
                    info[parts[0].rstrip(":")] = int(parts[1])
        total = info.get("MemTotal", 1)
        available = info.get("MemAvailable", 0)
        used_pct = round((1 - available / total) * 100, 1)
        return {"used_pct": used_pct, "total_kib": total,
                "available_kib": available, "alert": used_pct > 85}
    except OSError as error:
        return {"error": str(error)}


def check_disk():
    try:
        stat = os.statvfs("/")
        total = stat.f_blocks * stat.f_frsize
        free = stat.f_bavail * stat.f_frsize
        used_pct = round((1 - free / total) * 100, 1)
        return {"used_pct": used_pct, "total_bytes": total,
                "free_bytes": free, "alert": used_pct > 90}
    except OSError as error:
        return {"error": str(error)}


def check_load():
    try:
        load1, load5, load15 = os.getloadavg()
        with open("/proc/uptime") as handle:
            uptime = float(handle.read().split()[0])
        return {"load1": round(load1, 2), "load5": round(load5, 2),
                "load15": round(load15, 2), "uptime": int(uptime)}
    except OSError as error:
        return {"error": str(error)}


def check_failed_units():
    output = run(["systemctl", "list-units", "--state=failed",
                  "--no-legend", "--plain"], timeout=6)
    units = []
    for line in output.splitlines():
        words = line.split()
        if words and words[0]:
            units.append(words[0])
    return {"count": len(units), "units": units[:8], "alert": len(units) > 0}


def check_gpu():
    nodes = sorted(str(path) for path in Path("/dev/dri").glob("renderD*")) \
        if Path("/dev/dri").exists() else []
    return {"render_nodes": nodes, "alert": not nodes}


def check_waydroid():
    status = read_json(["elvonos-waydroid", "status", "--json"], as_user=True)
    if not status:
        return {"available": False, "alert": False}
    storage = read_json(["elvonos-waydroid", "storage", "--json"], as_user=True)
    graphics = run(["elvonos-waydroid", "graphics", "status"], as_user=True,
                   timeout=6).strip()
    result = {
        "available": True,
        "container": bool(status.get("container")),
        "session": bool(status.get("session")),
        "booted": bool(status.get("booted")),
        "frozen": bool(status.get("frozen")),
        "apps": int(status.get("apps", 0)),
        "bridge": bool(status.get("bridge")),
        "autostart": bool(status.get("autostart")),
        "graphics": graphics,
    }
    if storage:
        result["data_used"] = int(storage.get("used", 0))
        result["disk_free"] = int(storage.get("free", 0))
    # Only complain when a running session fails to boot; an intentionally
    # stopped Waydroid is not an alert.
    result["alert"] = result["session"] and not result["booted"] \
        and not result["frozen"]
    return result


def collect():
    memory = check_memory()
    disk = check_disk()
    load = check_load()
    units = check_failed_units()
    gpu = check_gpu()
    waydroid = check_waydroid()
    alerts = [
        name for name, section in (
            ("memory", memory), ("disk", disk), ("units", units),
            ("gpu", gpu), ("waydroid", waydroid),
        ) if section.get("alert")
    ]
    return {
        "timestamp": int(time.time()),
        "alerts": alerts,
        "memory": memory,
        "disk": disk,
        "load": load,
        "units": units,
        "gpu": gpu,
        "waydroid": waydroid,
    }


def publish(data):
    temporary = STATUS_FILE.with_suffix(".tmp")
    with open(temporary, "w") as handle:
        json.dump(data, handle)
    os.chmod(temporary, 0o644)
    temporary.replace(STATUS_FILE)


def append_log(data):
    try:
        with open(HEALTH_LOG, "a") as handle:
            handle.write(json.dumps(data) + "\n")
    except OSError:
        pass


def main():
    ensure_dirs()
    print("ElvonOS health layer starting...", flush=True)
    counter = 0
    while True:
        data = collect()
        publish(data)
        if counter % LOG_EVERY == 0:
            append_log(data)
        if data["alerts"]:
            print("HEALTH ALERT: " + ", ".join(data["alerts"]), flush=True)
        counter += 1
        notify_watchdog()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
