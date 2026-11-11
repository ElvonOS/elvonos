#!/usr/bin/env bash
# ElvonOS V1 — Live Waydroid test (QEMU debug session, GL/virgl launcher)
#
# Start the VM with:
#   ELVONOS_QEMU_GL=1 build/phase1/run-desktop-qemu-debug.sh
#
# Verifies the live-medium initializer, the container service, Android boot,
# and captures the composited desktop with grim (works with the GL display).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO_ROOT/build/out"
MONITOR="/tmp/qemu-monitor.sock"
SSH="sshpass -p elvon ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p 2222 elvon@127.0.0.1"

FAILURES=0
expect() {
    local label="$1" status="$2"
    if [ "$status" -eq 0 ]; then
        echo "  PASS: $label"
    else
        echo "  FAIL: $label"
        FAILURES=$((FAILURES + 1))
    fi
}

key() {
    python3 - "$MONITOR" "$1" <<'PY'
import socket, sys, time
sock, key = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock)
s.settimeout(3)
def read():
    data = b""
    end = time.time() + 5
    while time.time() < end:
        try:
            chunk = s.recv(4096)
        except socket.timeout:
            break
        if not chunk:
            break
        data += chunk
        if b"(qemu)" in data:
            break
    return data
read()
s.sendall(("sendkey %s\n" % key).encode())
read()
s.close()
PY
}

guest_shot() {
    local name="$1"
    $SSH 'bash -s' <<'REMOTE'
LP=$(pgrep -x labwc | head -n1)
tr '\0' '\n' < /proc/$LP/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' > /tmp/elvonos-shot-env
set -a; . /tmp/elvonos-shot-env; set +a
grim -t ppm /tmp/elvonos-waydroid.ppm
REMOTE
    $SSH 'base64 /tmp/elvonos-waydroid.ppm' | base64 -d > "$OUT/$name.ppm"
    python3 - "$OUT/$name.ppm" "$OUT/$name.png" <<'PY'
import struct, sys, zlib
src, dst = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
if not data.startswith(b"P6"):
    raise SystemExit("not a P6 PPM")
idx, tokens = 2, []
while len(tokens) < 3:
    while idx < len(data) and data[idx:idx+1].isspace():
        idx += 1
    start = idx
    while idx < len(data) and not data[idx:idx+1].isspace():
        idx += 1
    tokens.append(int(data[start:idx]))
while idx < len(data) and data[idx:idx+1].isspace():
    idx += 1
w, h, _ = tokens
rgb = data[idx:idx + w*h*3]
raw = bytearray()
for y in range(h):
    raw.append(0)
    raw.extend(rgb[y*w*3:(y+1)*w*3])
def chunk(typ, payload):
    return struct.pack(">I", len(payload)) + typ + payload + struct.pack(">I", zlib.crc32(typ + payload) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 6))
png += chunk(b"IEND", b"")
open(dst, "wb").write(png)
print("screenshot: %s (%dx%d)" % (dst, w, h))
PY
}

echo "==> Waiting for guest SSH"
for _ in $(seq 1 36); do
    if $SSH true >/dev/null 2>&1; then break; fi
    sleep 5
done
$SSH true >/dev/null 2>&1 || { echo "Guest SSH not reachable"; exit 1; }

echo "==> Waydroid services"
for _ in $(seq 1 30); do
    if $SSH 'systemctl is-active --quiet waydroid-container.service' >/dev/null 2>&1; then break; fi
    sleep 3
done
$SSH 'systemctl is-active --quiet elvonos-waydroid-init.service'
expect "live-medium initializer succeeded" $?
$SSH 'systemctl is-active --quiet waydroid-container.service'
expect "waydroid-container.service is active" $?
$SSH 'grep -q "images_path = /usr/share/waydroid-extra/images" /var/lib/waydroid/waydroid.cfg'
expect "Waydroid uses the bundled preinstalled images" $?
$SSH 'test -s /usr/share/waydroid-extra/images/system.img && test -s /usr/share/waydroid-extra/images/vendor.img'
expect "bundled system/vendor images are linked" $?

echo "==> Hide the Start screen"
for _ in $(seq 1 6); do
    state=$($SSH 'grep -E "Start shown|Start hidden" /tmp/win8start.log 2>/dev/null | tail -1')
    case "$state" in *shown*) key meta_l; sleep 2 ;; *) break ;; esac
done

echo "==> Start Waydroid session/UI"
if ! $SSH 'waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"' >/dev/null 2>&1; then
    $SSH 'bash -s' <<'REMOTE'
LP=$(pgrep -x labwc | head -n1)
tr '\0' '\n' < /proc/$LP/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_SEAT|XDG_SESSION_TYPE)=' > /tmp/elvonos-wayland-env
set -a; . /tmp/elvonos-wayland-env; set +a
export PATH=/usr/local/bin:/usr/bin:/bin
pkill -f 'waydroid show-full-ui' 2>/dev/null
setsid elvonos-waydroid >/tmp/elvonos-waydroid-launch.log 2>&1 </dev/null &
REMOTE
fi
sleep 8
$SSH 'waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"'
expect "Waydroid session is running" $?

echo "==> Headless mode (no full-screen UI window)"
if $SSH 'pgrep -f "[w]aydroid show-full-ui" >/dev/null' 2>/dev/null; then
    expect "no persistent full-screen Waydroid window" 1
else
    expect "no persistent full-screen Waydroid window" 0
fi

echo "==> Waiting for Android boot (up to ~8 min)"
BOOT=""
for _ in $(seq 1 32); do
    BOOT=$($SSH 'timeout 20 sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- getprop sys.boot_completed 2>/dev/null' | tr -d '\r\n')
    if [ "$BOOT" = "1" ]; then break; fi
    sleep 15
done
[ "$BOOT" = "1" ]
expect "Android boot completed" $?

echo "==> Bundled Android apps (Aurora Store / microG)"
for _ in $(seq 1 30); do
    if $SSH 'timeout 15 sudo -n lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- pm list packages 2>/dev/null | grep -q package:com.google.android.gms' >/dev/null 2>&1; then break; fi
    sleep 2
done
$SSH 'timeout 20 sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- pm list packages 2>/dev/null | grep -q package:com.aurora.store'
expect "Aurora Store installed" $?
$SSH 'timeout 20 sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- pm list packages 2>/dev/null | grep -q package:com.google.android.gms'
expect "microG Services (GmsCore) installed" $?
$SSH 'timeout 20 sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- pm list packages 2>/dev/null | grep -q package:com.android.vending'
expect "microG Companion installed" $?

echo "==> SurfaceFlinger (after the first-run package installation)"
SF_STATE=""
for _ in $(seq 1 24); do
    SF_STATE=$($SSH 'timeout 20 sudo lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- getprop init.svc.surfaceflinger 2>/dev/null' | tr -d '\r\n')
    [ "$SF_STATE" = "running" ] && break
    sleep 5
done
[ "$SF_STATE" = "running" ]
expect "SurfaceFlinger is running ($SF_STATE)" $?

echo "==> Multi-window app launch (Aurora)"
$SSH 'bash -s' <<'REMOTE'
LP=$(pgrep -x labwc | head -n1)
tr '\0' '\n' < /proc/$LP/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' > /tmp/elvonos-app-env
set -a; . /tmp/elvonos-app-env; set +a
waydroid app launch com.aurora.store
REMOTE
sleep 6
$SSH 'grep -q "AppID=waydroid.com.aurora.store" ~/.config/list-windows/windows.ini'
expect "Aurora opens as its own multi-window window" $?
sleep 4

echo "==> Capture desktop with grim"
guest_shot elvonos-waydroid

echo "==> Status"
$SSH 'waydroid status 2>&1' || true
echo "==> Summary"
if [ "$FAILURES" -eq 0 ]; then
    echo "WAYDROID TEST PASSED"
else
    echo "WAYDROID TEST FAILED ($FAILURES failure(s))"
    exit 1
fi
