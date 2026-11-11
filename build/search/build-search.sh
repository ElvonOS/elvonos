#!/usr/bin/env bash
# Build the Rust desktop search index and install it into the rootfs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CRATE="$REPO_ROOT/base/configuration/search-rs"
ROOTFS="${ROOTFS:-$REPO_ROOT/build/out/rootfs}"
OUT="$REPO_ROOT/build/out/elvonos-search-index"

echo "==> Building elvonos-search-index (Rust)"
cargo build --release --manifest-path "$CRATE/Cargo.toml"
install -Dm755 "$CRATE/target/release/elvonos-search-index" "$OUT"

if [ -d "$ROOTFS/usr/bin" ]; then
    SUDO=""
    [ "$(id -u)" -ne 0 ] && sudo -n true 2>/dev/null && SUDO="sudo"
    $SUDO install -Dm755 "$OUT" "$ROOTFS/usr/bin/elvonos-search-index"
    echo "==> Installed $ROOTFS/usr/bin/elvonos-search-index"
else
    echo "Warning: rootfs not found at $ROOTFS; binary at $OUT" >&2
fi
