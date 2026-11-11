#!/usr/bin/env bash
# Build the ElvonOS Archiver.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/archiver"
BUILD_DIR="/tmp/elvonos-archiver"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-archiver" "$ROOTFS/usr/bin/elvonos-archiver"
sudo install -Dm644 "$SOURCE_DIR/elvonos-archiver.desktop" "$ROOTFS/usr/share/applications/elvonos-archiver.desktop"
sudo chroot "$ROOTFS" update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
echo "installed archiver"
