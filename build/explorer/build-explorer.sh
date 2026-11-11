#!/usr/bin/env bash
# Build the ElvonOS Explorer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/explorer"
BUILD_DIR="/tmp/elvonos-explorer"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-explorer" "$ROOTFS/usr/bin/elvonos-explorer"
sudo install -Dm644 "$SOURCE_DIR/elvonos-explorer.desktop" "$ROOTFS/usr/share/applications/elvonos-explorer.desktop"
echo "installed explorer"
