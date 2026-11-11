#!/usr/bin/env bash
# Build the ElvonOS Media Player.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/media"
BUILD_DIR="/tmp/elvonos-media"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-media" "$ROOTFS/usr/bin/elvonos-media"
sudo install -Dm644 "$SOURCE_DIR/elvonos-media.desktop" "$ROOTFS/usr/share/applications/elvonos-media.desktop"
sudo chroot "$ROOTFS" update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
echo "installed media player"
