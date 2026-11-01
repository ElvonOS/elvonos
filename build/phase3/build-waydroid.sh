#!/usr/bin/env bash
# ElvonOS V1 — Phase 3: Build Waydroid 1.6.3 Package for Debian 13
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WAYDROID_SRC="$REPO_ROOT/Android/waydroid-1.6.3"
OUTPUT_DIR="$REPO_ROOT/build/out/packages"

echo "=================================================="
echo " ElvonOS V1 — Building Waydroid 1.6.3 (.deb)"
echo " Source: $WAYDROID_SRC"
echo " Output: $OUTPUT_DIR"
echo "=================================================="

mkdir -p "$OUTPUT_DIR"

# 1. Ensure build dependencies and backports libraries
if ! dpkg -s python3-gbinder >/dev/null 2>&1; then
    echo "==> Installing python3-gbinder and dev dependencies from trixie-backports..."
    sudo apt-get install -y --no-install-recommends -t trixie-backports \
        libglibutil-dev libgbinder-dev python3-gbinder
fi

# 2. Build Waydroid Debian package
echo "==> Building Waydroid Debian package..."
cd "$WAYDROID_SRC"
dpkg-buildpackage -b -uc -us

echo "==> Collecting package artifacts..."
mv -f "$REPO_ROOT/Android"/waydroid_*.deb "$OUTPUT_DIR/" 2>/dev/null || true
mv -f "$REPO_ROOT/Android"/waydroid_*.buildinfo "$OUTPUT_DIR/" 2>/dev/null || true
mv -f "$REPO_ROOT/Android"/waydroid_*.changes "$OUTPUT_DIR/" 2>/dev/null || true

echo "=================================================="
echo " Waydroid package built successfully in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"/waydroid* || true
echo "=================================================="
