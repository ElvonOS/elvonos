#!/usr/bin/env bash
# Build the ElvonOS boot splash bridge (Qt Quick, software renderer).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
SOURCE_DIR="$REPO_ROOT/base/configuration/splash"
BUILD_DIR="/tmp/elvonos-splash-qt-build"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

sudo install -Dm755 "$BUILD_DIR/elvonos-splash" "$ROOTFS/usr/bin/elvonos-splash"
echo "installed splash"
