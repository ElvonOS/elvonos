#!/usr/bin/env bash
# ElvonOS debug launch with maximum TCG CPU parallelism.
#
# The normal debug launcher uses `-machine type=q35,accel=tcg` (single-threaded
# TCG semantics).  This variant enables MTTCG, uses all host CPUs as vCPUs and
# `-cpu max`, which makes Android/Waydroid boot substantially faster in QEMU.
set -euo pipefail

REPO_ROOT="/home/kirara/ElvonOS"
ISO="$REPO_ROOT/build/out/ElvonOS-1.0.0-amd64.iso"
LOG="$REPO_ROOT/build/out/qemu_maxcpu.log"
SERIAL_SOCK="/tmp/elvonos-serial.sock"
MONITOR_SOCK="/tmp/qemu-monitor.sock"
QMP_SOCK="/tmp/qemu-qmp.sock"

rm -f "$LOG" "$SERIAL_SOCK" "$MONITOR_SOCK" "$QMP_SOCK"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export GDK_BACKEND=x11

CPUS="${ELVONOS_QEMU_CPUS:-$(nproc)}"
RAM="${ELVONOS_QEMU_RAM:-4096}"

qemu-system-x86_64 \
    -m "$RAM" -smp "$CPUS" \
    -machine type=q35 \
    -accel tcg,thread=multi \
    -cpu max \
    -bios /usr/share/ovmf/OVMF.fd \
    -vga none \
    -device virtio-gpu-pci,xres=1280,yres=800,edid=on \
    -device usb-ehci,id=ehci \
    -device usb-tablet \
    -cdrom "$ISO" \
    -boot d \
    -display gtk \
    -chardev socket,id=ser0,path="$SERIAL_SOCK",server=on,wait=off \
    -serial chardev:ser0 \
    -monitor unix:"$MONITOR_SOCK",server,nowait \
    -qmp unix:"$QMP_SOCK",server,nowait \
    -net nic -net user,hostfwd=tcp::2222-:22 \
    2>&1 | tee "$LOG"
