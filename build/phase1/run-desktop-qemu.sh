#!/usr/bin/env bash
# ElvonOS V1 — Launch QEMU with Graphical Desktop Window (WSLg)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISO="$REPO_ROOT/build/out/ElvonOS-1.0.0-amd64.iso"
LOG_FILE="$REPO_ROOT/build/out/qemu_desktop.log"
OVMF_BIOS="/usr/share/ovmf/OVMF.fd"

MEMORY="${MEMORY:-4096}"
SMP="${SMP:-4}"

echo "=================================================="
echo " ElvonOS V1 — Launching Desktop in QEMU GUI"
echo " ISO:     $ISO"
echo " Memory:  ${MEMORY}MB | vCPUs: $SMP"
echo " Display: GTK / WSLg"
echo " Log:     $LOG_FILE"
echo "=================================================="

if [[ ! -f "$ISO" ]]; then
    echo "Error: ISO not found at $ISO. Run build-iso.sh first."
    exit 1
fi

rm -f "$LOG_FILE"

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# Determine display backend (GTK or SDL via WSLg)
DISPLAY_OPT="-display gtk"
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "Notice: No GUI display detected in WSL environment; falling back to -display none + VNC (:0)"
    DISPLAY_OPT="-display none -vnc :0"
fi

qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp "$SMP" \
    -machine type=q35,accel=tcg \
    -bios "$OVMF_BIOS" \
    -device virtio-vga \
    -device usb-ehci,id=ehci \
    -device usb-tablet \
    -cdrom "$ISO" \
    -boot d \
    $DISPLAY_OPT \
    -serial file:"$LOG_FILE" \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait \
    -net nic -net user,hostfwd=tcp::2222-:22
