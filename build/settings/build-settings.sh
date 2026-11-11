#!/usr/bin/env bash
# Build the ElvonOS Settings application.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/settings"
BUILD_DIR="/tmp/elvonos-settings"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-settings" "$ROOTFS/usr/bin/elvonos-settings"
sudo install -Dm644 "$SOURCE_DIR/elvonos-settings.desktop" "$ROOTFS/usr/share/applications/elvonos-settings.desktop"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-gaming-setup" "$ROOTFS/usr/bin/elvonos-gaming-setup"
sudo install -d "$ROOTFS/usr/share/elvonos/i18n"
sudo install -m644 "$SOURCE_DIR"/i18n/*.json "$ROOTFS/usr/share/elvonos/i18n/"
sudo chroot "$ROOTFS" update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
echo "installed settings"
