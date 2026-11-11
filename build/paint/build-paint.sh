#!/usr/bin/env bash
# Build the ElvonOS Paint application.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/paint"
BUILD_DIR="/tmp/elvonos-paint"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-paint" "$ROOTFS/usr/bin/elvonos-paint"
sudo install -Dm644 "$SOURCE_DIR/elvonos-paint.desktop" "$ROOTFS/usr/share/applications/elvonos-paint.desktop"
sudo chroot "$ROOTFS" update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
echo "installed paint"
