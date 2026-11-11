#!/usr/bin/env bash
# ElvonOS V1 — Install the Sway start menu, status line, and taskbar config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"

echo "=================================================="
echo " ElvonOS V1 — Installing Start Menu & Taskbar"
echo "=================================================="

sudo install -Dm755 "$REPO_ROOT/base/configuration/desktop/elvonos-menu" "$ROOTFS/usr/bin/elvonos-menu"
sudo install -Dm755 "$REPO_ROOT/base/configuration/desktop/elvonos-status" "$ROOTFS/usr/bin/elvonos-status"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wofi/elvonos-menu.conf" "$ROOTFS/etc/wofi/elvonos-menu.conf"

sudo install -Dm644 "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/etc/elvonos/sway.conf"
sudo install -Dm644 "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/usr/share/elvonos/sway/config"
sudo install -Dm644 "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/home/elvon/.config/sway/config"
sudo install -Dm644 "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/home/elvon/.config/elvonos/sway.conf"

sudo chown -R 1000:1000 "$ROOTFS/home/elvon"

echo "==> Installed:"
echo "    /usr/bin/elvonos-menu"
echo "    /usr/bin/elvonos-status"
echo "    /etc/wofi/elvonos-menu.conf"
echo "    /etc/elvonos/sway.conf"
echo "=================================================="
