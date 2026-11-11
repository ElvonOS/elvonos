#!/usr/bin/env bash
# Build the ElvonOS Gallery.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/gallery"
BUILD_DIR="/tmp/elvonos-gallery"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-gallery" "$ROOTFS/usr/bin/elvonos-gallery"
sudo install -Dm644 "$SOURCE_DIR/elvonos-gallery.desktop" "$ROOTFS/usr/share/applications/elvonos-gallery.desktop"
sudo chroot "$ROOTFS" update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
echo "installed gallery"
