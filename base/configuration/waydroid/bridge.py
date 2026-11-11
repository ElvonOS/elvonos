#!/usr/bin/python3
# ElvonOS Waydroid bridge: clipboard and notification forwarding.
#
# The native Rust session replaces Waydroid's Python session manager, so the
# upstream clipboard and notification services are not started by anything.
# This helper starts the same gbinder services standalone:
#
#   waydroidclipboard    Android <-> host clipboard (wl-paste / wl-copy)
#   waydroidnotifications Android notifications -> org.freedesktop.Notifications
#
# It is started by `elvonos-waydroid` once Android is up and exits with the
# session.  Failures are non-fatal: the Android apps keep running without it.
import os
import fcntl
import logging
import signal
import subprocess
import sys
import threading
import time

sys.path.insert(0, "/usr/lib/waydroid")

# tools.helpers.arguments() parses sys.argv; give it a valid, harmless command.
sys.argv = ["waydroid", "session", "start"]

import tools  # noqa: E402

import dbus.mainloop.glib  # noqa: E402

# gbinder and notification_manager create GLib/D-Bus objects; the D-Bus
# connection needs a main loop before it is constructed.
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
dbus.mainloop.glib.threads_init()

STATE_DIR = os.path.expanduser("~/.local/state/elvonos")
PID_FILE = os.path.join(STATE_DIR, "waydroid-bridge.pid")
LOCK_FILE = os.path.join(STATE_DIR, "waydroid-bridge.lock")
LOG_FILE = os.path.join(STATE_DIR, "waydroid-bridge.log")

# The upstream services log through the standard logging module; route that to
# the ElvonOS bridge log so failures (D-Bus errors, binder problems) are
# visible instead of going to /dev/null.
try:
    os.makedirs(STATE_DIR, exist_ok=True)
    logging.basicConfig(
        filename=LOG_FILE,
        level=logging.INFO,
        format="[%(asctime)s] %(levelname)s %(name)s: %(message)s",
    )
except OSError:
    pass

last_clipboard = {"value": None}
running = threading.Event()


def write_pid():
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(PID_FILE, "w") as handle:
            handle.write("{}\n".format(os.getpid()))
    except OSError:
        pass


def remove_pid():
    try:
        os.remove(PID_FILE)
    except OSError:
        pass


def log(message):
    try:
        with open(os.path.expanduser("~/.local/state/elvonos/waydroid-bridge.log"), "a") as handle:
            handle.write("[{}] {}\n".format(time.strftime("%Y-%m-%d %H:%M:%S"), message))
    except OSError:
        pass


def get_clipboard():
    try:
        result = subprocess.run(
            ["wl-paste", "--no-newline"], capture_output=True, text=True, timeout=3
        )
        if result.returncode == 0:
            return result.stdout
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def set_clipboard(value):
    if value is None or value == last_clipboard["value"]:
        return
    try:
        subprocess.run(["wl-copy"], input=value, text=True, timeout=3)
        last_clipboard["value"] = value
    except (OSError, subprocess.SubprocessError):
        pass


def clipboard_loop(args):
    from tools.interfaces import IClipboard

    while not running.is_set():
        try:
            IClipboard.add_service(args, set_clipboard, get_clipboard)
        except Exception as error:  # noqa: BLE001 - keep the bridge alive
            log("clipboard service stopped: {}".format(error))
            time.sleep(5)


def main():
    # Only one bridge may register the binder services.
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        lock = open(LOCK_FILE, "w")
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("another bridge instance is already running")
        return 0

    try:
        from tools import helpers

        args = helpers.arguments()
        tools.prep_args(args)
    except Exception as error:  # noqa: BLE001
        log("cannot prepare Waydroid arguments: {}".format(error))
        return 1

    write_pid()

    def terminate(*_args):
        remove_pid()
        # The gbinder/GLib threads may not unblock a normal interpreter exit.
        os._exit(0)

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)

    threads = []
    clipboard = threading.Thread(target=clipboard_loop, args=(args,), daemon=True)
    clipboard.start()
    threads.append(clipboard)

    try:
        from tools.services import notification_manager

        notification_manager.start(args, None)
        log("clipboard and notification bridge started")
    except Exception as error:  # noqa: BLE001
        log("notification service not started: {}".format(error))

    running.wait()
    remove_pid()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        running.set()
        remove_pid()
        sys.exit(0)
