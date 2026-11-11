#!/usr/bin/env bash
# ElvonOS V1 — Debug launch with graphical window + interactive serial console
set -euo pipefail

REPO_ROOT="/home/kirara/ElvonOS"
ISO="$REPO_ROOT/build/out/ElvonOS-1.0.0-amd64.iso"
LOG="$REPO_ROOT/build/out/qemu_debug.log"
SERIAL_SOCK="/tmp/elvonos-serial.sock"
MONITOR_SOCK="/tmp/qemu-monitor.sock"
QMP_SOCK="/tmp/qemu-qmp.sock"

rm -f "$LOG" "$SERIAL_SOCK" "$MONITOR_SOCK" "$QMP_SOCK"

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# ELVONOS_QEMU_GL=1 (default) provides virgl for Waydroid and uses SDL+GL.
# WSLg's GL stack fails eglMakeCurrent with QEMU's GTK GL area; llvmpipe is
# fast enough for this debug VM and keeps virgl available to the guest.
# Set ELVONOS_QEMU_GL=0 for the plain virtio-gpu/GTK mode (QEMU screendump
# based tests, no Android UI).
if [ "${ELVONOS_QEMU_GL:-1}" = "1" ]; then
    GPU_DEVICE="virtio-gpu-gl-pci,xres=1280,yres=800,edid=on"
    DISPLAY_OPT="sdl,gl=on"
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export GDK_BACKEND=x11
else
    GPU_DEVICE="virtio-gpu-pci,xres=1280,yres=800,edid=on"
    DISPLAY_OPT="gtk"
fi

# Only expose virtio-gpu. Without "-vga none" QEMU adds a bochs VGA (card1)
# that receives the display output while labwc renders on card0.
qemu-system-x86_64 \
    -m 4096 -smp 4 \
    -machine type=q35,accel=tcg \
    -cpu max \
    -bios /usr/share/ovmf/OVMF.fd \
    -vga none \
    -device "$GPU_DEVICE" \
    -device usb-ehci,id=ehci \
    -device usb-tablet \
    -cdrom "$ISO" \
    -boot d \
    -display "$DISPLAY_OPT" \
    -chardev socket,id=ser0,path="$SERIAL_SOCK",server=on,wait=off \
    -serial chardev:ser0 \
    -monitor unix:"$MONITOR_SOCK",server,nowait \
    -qmp unix:"$QMP_SOCK",server,nowait \
    -net nic -net user,hostfwd=tcp::2222-:22 \
    2>&1 | tee "$LOG"
