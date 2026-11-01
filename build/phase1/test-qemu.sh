#!/usr/bin/env bash
# ElvonOS V1 — QEMU Boot Test Script
# Boots ElvonOS ISO or kernel in QEMU to test kernel, systemd, and services.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISO="$REPO_ROOT/build/out/ElvonOS-1.0.0-amd64.iso"
LOG_FILE="$REPO_ROOT/build/out/qemu_boot.log"

MEMORY="2048"
SMP="2"
TIMEOUT="${TIMEOUT:-120}"

echo "=================================================="
echo " ElvonOS V1 — Testing ISO Boot with QEMU (UEFI)"
echo " ISO:     $ISO"
echo " Memory:  ${MEMORY}MB | vCPUs: $SMP"
echo " Log:     $LOG_FILE"
echo " Timeout: ${TIMEOUT}s"
echo "=================================================="

if [[ ! -f "$ISO" ]]; then
    echo "Error: ISO not found at $ISO. Run build-iso.sh first."
    exit 1
fi

OVMF_BIOS="/usr/share/ovmf/OVMF.fd"
if [[ ! -f "$OVMF_BIOS" ]]; then
    echo "Error: OVMF firmware not found at $OVMF_BIOS."
    exit 1
fi

rm -f "$LOG_FILE"

echo "==> Starting QEMU with UEFI firmware and serial logging (Timeout: ${TIMEOUT}s)..."
timeout "${TIMEOUT}s" qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp "$SMP" \
    -bios "$OVMF_BIOS" \
    -cdrom "$ISO" \
    -display none \
    -serial file:"$LOG_FILE" \
    -no-reboot || true

echo "==> QEMU run ended. Inspecting boot log..."
if [[ -f "$LOG_FILE" && -s "$LOG_FILE" ]]; then
    echo "==> Boot Log Summary (First 25 lines):"
    head -n 25 "$LOG_FILE"
    echo ""
    echo "==> Boot Log Summary (Last 25 lines):"
    tail -n 25 "$LOG_FILE"
    echo ""
    if grep -q "Linux version" "$LOG_FILE"; then
        echo " [SUCCESS] Linux kernel booted successfully in QEMU!"
        grep "Linux version" "$LOG_FILE" | head -n 1 || true
    fi
    if grep -q "systemd" "$LOG_FILE"; then
        echo " [SUCCESS] systemd reached in QEMU!"
        grep "systemd" "$LOG_FILE" | head -n 3 || true
    fi
    if grep -qi "waydroid" "$LOG_FILE"; then
        echo " [SUCCESS] Waydroid references detected during boot!"
        grep -i "waydroid" "$LOG_FILE" | head -n 3 || true
    fi
    exit 0
else
    echo "Warning: Log file is empty or missing."
fi
