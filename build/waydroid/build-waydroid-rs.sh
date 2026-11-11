#!/usr/bin/env bash
# Build and install the Rust ElvonOS Waydroid integration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="${ROOTFS:-$REPO_ROOT/build/out/rootfs}"
SOURCE_DIR="$REPO_ROOT/base/configuration/waydroid-rs"
OUTPUT="$REPO_ROOT/build/out/elvonos-waydroid"

mkdir -p "$REPO_ROOT/build/out"
echo "==> Building elvonos-waydroid (Rust, D-Bus session service)…"
(
    cd "$SOURCE_DIR"
    if [[ -f Cargo.lock ]]; then
        cargo build --release --locked
    else
        cargo build --release
    fi
)
cp -f "$SOURCE_DIR/target/release/elvonos-waydroid" "$OUTPUT"

if [[ -d "$ROOTFS" ]]; then
    sudo install -Dm755 "$OUTPUT" "$ROOTFS/usr/bin/elvonos-waydroid"
    sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-sync" \
        "$ROOTFS/usr/bin/elvonos-waydroid-sync"
    sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-install-apk" \
        "$ROOTFS/usr/bin/elvonos-waydroid-install-apk"
    sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-apk-entry" \
        "$ROOTFS/usr/bin/elvonos-waydroid-apk-entry"
    sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-apps.sh" \
        "$ROOTFS/usr/share/elvonos/elvonos-waydroid-apps.sh"
    echo "==> Installed elvonos-waydroid into $ROOTFS"
else
    echo "==> Rootfs not found; binary is at $OUTPUT"
fi
