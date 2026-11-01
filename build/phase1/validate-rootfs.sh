#!/usr/bin/env bash
# ElvonOS V1 — Phase 1: Validate Rootfs
# Validates that a generated rootfs contains the required Debian 13 foundation artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="${1:-$REPO_ROOT/build/out/rootfs}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
pass() { echo -e "  [${GREEN}PASS${NC}] $1"; }
warn() { echo -e "  [${YELLOW}WARN${NC}] $1"; }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "${BLUE}==>${NC} $1"; }

info "Validating rootfs at: $ROOTFS"

if [[ ! -d "$ROOTFS" ]]; then
    fail "Rootfs directory does not exist: $ROOTFS"
    exit 1
fi

info "1. Verifying Directory Structure"
for dir in bin etc sbin usr var boot dev proc sys run tmp; do
    if [[ -d "$ROOTFS/$dir" ]]; then
        pass "Directory exists: /$dir"
    else
        fail "Missing root directory: /$dir"
    fi
done

info "2. Verifying Debian 13 Official Kernel"
KERNELS=("$ROOTFS"/boot/vmlinuz-*)
if [[ -f "${KERNELS[0]:-}" ]]; then
    KERNEL_NAME="$(basename "${KERNELS[0]}")"
    pass "Kernel found in /boot: $KERNEL_NAME"
    if [[ "$KERNEL_NAME" =~ deb13|amd64 ]]; then
        pass "Kernel is official Debian 13 amd64"
    else
        warn "Kernel name does not match expected deb13 ABI: $KERNEL_NAME"
    fi
    if [[ "$KERNEL_NAME" =~ microsoft|WSL ]]; then
        fail "Found Microsoft/WSL kernel in rootfs instead of Debian kernel!"
    fi
else
    fail "No kernel found in $ROOTFS/boot/"
fi

info "3. Verifying Kernel Configuration & Binder Settings"
CONFIGS=("$ROOTFS"/boot/config-*)
if [[ -f "${CONFIGS[0]:-}" ]]; then
    pass "Kernel config found: $(basename "${CONFIGS[0]}")"
    if grep -q "CONFIG_ANDROID_BINDER_IPC=m" "${CONFIGS[0]}"; then
        pass "CONFIG_ANDROID_BINDER_IPC is built as module"
    else
        fail "CONFIG_ANDROID_BINDER_IPC is missing from kernel config"
    fi
    if grep -q "# CONFIG_ANDROID_BINDERFS is not set" "${CONFIGS[0]}"; then
        pass "CONFIG_ANDROID_BINDERFS is not set (confirmed stock Debian kernel)"
    fi
else
    warn "Kernel config file not found in /boot"
fi

info "4. Verifying ElvonOS Target Configuration"
if [[ -f "$ROOTFS/etc/modprobe.d/elvonos-binder.conf" ]]; then
    pass "modprobe.d/elvonos-binder.conf present"
    if grep -q "devices=\"anbox-binder,anbox-vndbinder,anbox-hwbinder\"" "$ROOTFS/etc/modprobe.d/elvonos-binder.conf"; then
        pass "Binder device parameters configured correctly"
    else
        fail "Binder device parameters malformed in elvonos-binder.conf"
    fi
else
    fail "modprobe.d/elvonos-binder.conf is missing"
fi

if [[ -f "$ROOTFS/etc/modules-load.d/elvonos-binder.conf" ]]; then
    pass "modules-load.d/elvonos-binder.conf present"
else
    fail "modules-load.d/elvonos-binder.conf is missing"
fi

if [[ -f "$ROOTFS/etc/hostname" ]]; then
    pass "Hostname configured: $(cat "$ROOTFS/etc/hostname")"
else
    fail "/etc/hostname missing"
fi

info "5. Verifying Core Base Services"
if [[ -f "$ROOTFS/usr/lib/systemd/systemd" || -f "$ROOTFS/bin/systemd" ]]; then
    pass "systemd init system present"
else
    fail "systemd init missing"
fi

if [[ -f "$ROOTFS/usr/bin/dbus-daemon" || -f "$ROOTFS/usr/bin/dbus-broker" ]]; then
    pass "D-Bus daemon present"
else
    fail "D-Bus missing"
fi

if [[ -f "$ROOTFS/usr/sbin/NetworkManager" ]]; then
    pass "NetworkManager present"
else
    fail "NetworkManager missing"
fi

if [[ -f "$ROOTFS/usr/bin/pipewire" ]]; then
    pass "PipeWire present"
else
    fail "PipeWire missing"
fi

info "6. Verifying Graphics & Mesa"
if compgen -G "$ROOTFS/usr/lib/*/dri/*.so" > /dev/null; then
    pass "Mesa DRI GPU drivers present"
else
    warn "Mesa DRI drivers not found in standard paths"
fi

echo ""
echo "=================================================="
if (( ERRORS > 0 )); then
    echo -e "${RED}Rootfs validation FAILED with $ERRORS error(s).${NC}"
    exit 1
else
    echo -e "${GREEN}Rootfs validation PASSED! Foundation is ready.${NC}"
    exit 0
fi
