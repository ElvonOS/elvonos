#!/usr/bin/env bash
# ElvonOS V1 — Live desktop smoke test (QEMU debug session)
#
# Requires the VM started with build/phase1/run-desktop-qemu-debug.sh
# (GTK display, SSH on port 2222, QEMU monitor socket /tmp/qemu-monitor.sock).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO_ROOT/build/out"
MONITOR="/tmp/qemu-monitor.sock"
SSH="sshpass -p elvon ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -p 2222 elvon@127.0.0.1"
ENV="env WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=ElvonOS:labwc"

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

shot() {
    local name="$1"
    python3 - "$MONITOR" "$OUT/$name.ppm" <<'PY'
import socket, sys, time
sock, path = sys.argv[1], sys.argv[2]
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
s.sendall(("screendump %s\n" % path).encode())
read()
s.close()
PY
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
w, h, maxval = tokens
rgb = data[idx:idx + w*h*3]
raw = bytearray()
for y in range(h):
    raw.append(0)
    raw.extend(rgb[y*w*3:(y+1)*w*3])
def chunk(typ, payload):
    return struct.pack(">I", len(payload)) + typ + payload + struct.pack(">I", zlib.crc32(typ + payload) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
png += chunk(b"IEND", b"")
open(dst, "wb").write(png)
print("wrote %s: %dx%d" % (dst, w, h))
PY
    echo "screenshot: $OUT/$name.png"
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

pixel_diff() {
    python3 - "$1" "$2" <<'PY'
import sys
def read_ppm(path):
    data = open(path, "rb").read()
    if not data.startswith(b"P6"):
        raise SystemExit("not a P6 PPM")
    idx, vals = 2, []
    while len(vals) < 3:
        while data[idx:idx+1].isspace():
            idx += 1
        start = idx
        while not data[idx:idx+1].isspace():
            idx += 1
        vals.append(int(data[start:idx]))
    while data[idx:idx+1].isspace():
        idx += 1
    w, h, _ = vals
    return w, h, data[idx:idx + w*h*3]
wa, ha, a = read_ppm(sys.argv[1])
wb, hb, b = read_ppm(sys.argv[2])
if (wa, ha) != (wb, hb):
    print(10**9)
    raise SystemExit
changed = 0
for i in range(0, len(a), 3):
    if (abs(a[i] - b[i]) > 8 or abs(a[i+1] - b[i+1]) > 8
            or abs(a[i+2] - b[i+2]) > 8):
        changed += 1
print(changed)
PY
}

echo "==> Waiting for guest SSH"
for _ in $(seq 1 36); do
    if $SSH true >/dev/null 2>&1; then break; fi
    sleep 5
done
$SSH true >/dev/null 2>&1 || { echo "Guest SSH not reachable"; exit 1; }

# Leftover clients from earlier smoke-test runs slow down the modeset.
$SSH 'pkill -x foot 2>/dev/null || true'

echo "==> Waiting for desktop session"
for _ in $(seq 1 30); do
    if $SSH 'pgrep -x labwc >/dev/null && pgrep -x Win8Start >/dev/null' >/dev/null 2>&1; then break; fi
    sleep 4
done

echo "==> Shell processes"
$SSH "pgrep -a -f 'labwc|Win8Wall|Win8Running|Win8Start|Win8Corner|list-windows|Win8OSD-server|battery-daemon'" || true

echo "==> Compositor backend + input devices"
LABWC_ENV=$($SSH 'LP=$(pgrep -x labwc | head -n1); tr "\0" "\n" < /proc/$LP/environ' 2>/dev/null || true)
echo "$LABWC_ENV" | grep -E 'WLR_BACKENDS|WLR_LIBINPUT|WLR_RENDERER|WLR_DRM' || true
printf '%s\n' "$LABWC_ENV" | grep -q 'WLR_BACKENDS=drm,libinput'
expect "libinput backend enabled (WLR_BACKENDS=drm,libinput)" $?
printf '%s\n' "$LABWC_ENV" | grep -q 'WLR_LIBINPUT_NO_DEVICES'
[ $? -ne 0 ]
expect "WLR_LIBINPUT_NO_DEVICES is not set" $?
INPUT_FDS=$($SSH 'LP=$(pgrep -x labwc | head -n1); ls -l /proc/$LP/fd 2>/dev/null | grep -c "/dev/input/event"' 2>/dev/null || echo 0)
echo "  labwc open input event devices: ${INPUT_FDS:-0}"
[ "${INPUT_FDS:-0}" -ge 2 ]
expect "labwc has opened input devices" $?

echo "==> Normalise display mode (virtio-gpu defaults to 640x480)"
$SSH 'export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000
OUT=$(wlr-randr 2>/dev/null | head -n1 | cut -d" " -f1)
if [ -n "$OUT" ]; then
  if wlr-randr 2>/dev/null | grep current | grep -q "640x480 px"; then
    for _ in $(seq 1 30); do
      wlr-randr --output "$OUT" --mode 1280x768 2>/dev/null || true
      wlr-randr 2>/dev/null | grep current | grep -q "1280x768 px" && break
      sleep 1
    done
    if ! wlr-randr 2>/dev/null | grep current | grep -q "1280x768 px"; then
      for _ in $(seq 1 20); do
        wlr-randr --output "$OUT" --mode 1024x768 2>/dev/null || true
        wlr-randr 2>/dev/null | grep current | grep -q "1024x768 px" && break
        sleep 1
      done
    fi
  fi
  wlr-randr | grep current || true
fi' || true

echo "==> Waiting for Win8Start to bind to the output"
for _ in $(seq 1 15); do
    if $SSH 'grep -q "Start menu bound" /tmp/win8start.log 2>/dev/null' >/dev/null 2>&1; then break; fi
    sleep 2
done
sleep 4

echo "==> Metro tile layout"
TILES=$($SSH 'grep -c "modelX" ~/.config/Win8Start/launcher_tiles.json 2>/dev/null' 2>/dev/null || echo 0)
echo "  tiles: ${TILES:-0}"
[ "${TILES:-0}" -ge 5 ]
expect "default Metro tile layout present (${TILES:-0} tiles)" $?
$SSH 'grep -Eq "TileModel loaded: [1-9]" /tmp/win8start.log' 2>/dev/null
expect "Win8Start loaded the tile model" $?

echo "==> Desktop screenshot"
sleep 2
shot elvonos-verify-desktop
DIMS=$(python3 -c 'import sys;d=open(sys.argv[1],"rb").read(32).split();print(d[1].decode()+"x"+d[2].decode())' "$OUT/elvonos-verify-desktop.ppm")
echo "  frame: $DIMS"
[ "${DIMS%x*}" -ge 1024 ] && [ "${DIMS#*x}" -ge 768 ]
expect "display mode is at least 1024x768 (got $DIMS)" $?

echo "==> Super (Win8Start toggle)"
key meta_l
sleep 3
shot elvonos-verify-start-open
CHANGED=$(pixel_diff "$OUT/elvonos-verify-desktop.ppm" "$OUT/elvonos-verify-start-open.ppm")
if [ "$CHANGED" -lt 2000 ]; then
    # The focused layer surface can swallow the first Super press; retry once.
    key meta_l
    sleep 3
    shot elvonos-verify-start-open
    CHANGED=$(pixel_diff "$OUT/elvonos-verify-desktop.ppm" "$OUT/elvonos-verify-start-open.ppm")
fi
echo "  changed pixels after Super: $CHANGED"
[ "$CHANGED" -ge 2000 ]
expect "keyboard input changes the frame (Super toggle, $CHANGED px)" $?

key meta_l
sleep 3

echo "==> Launch foot, check window list + taskbar"
$SSH "setsid $ENV foot >/tmp/foot.log 2>&1 </dev/null & sleep 4; pgrep -a foot; echo '--- windows.ini'; cat ~/.config/list-windows/windows.ini 2>&1" || true
$SSH "grep -q 'AppID=foot' ~/.config/list-windows/windows.ini"
expect "foot window listed by list-windows" $?
sleep 2
shot elvonos-verify-foot

echo "==> Waydroid"
$SSH 'systemctl is-active --quiet waydroid-container.service'
expect "waydroid-container.service is active" $?
$SSH 'systemctl is-active --quiet elvonos-waydroid-init.service'
expect "Waydroid live-medium initializer succeeded" $?
$SSH 'grep -q "images_path = /usr/share/waydroid-extra/images" /var/lib/waydroid/waydroid.cfg'
expect "Waydroid uses the bundled preinstalled images" $?

echo "==> Summary"
if [ "$FAILURES" -eq 0 ]; then
    echo "SMOKE TEST PASSED"
else
    echo "SMOKE TEST FAILED ($FAILURES failure(s))"
    exit 1
fi
