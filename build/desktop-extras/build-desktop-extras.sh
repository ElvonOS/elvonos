#!/usr/bin/env bash
# Build the ElvonOS desktop-extras binary (desktop icons + bottom dock).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/desktop-extras"
BUILD_DIR="/tmp/elvonos-desktop-extras"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-desktop-extras" "$ROOTFS/usr/bin/elvonos-desktop-extras"
echo "installed $ROOTFS/usr/bin/elvonos-desktop-extras"
