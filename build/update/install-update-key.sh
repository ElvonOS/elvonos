#!/usr/bin/env bash
set -euo pipefail
ROOTFS="${1:-$(cd "$(dirname "$0")/../.." && pwd)/build/out/rootfs}"
KEY="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.pub}"
[ -f "$KEY" ] || { echo "Public key not found: $KEY" >&2; exit 1; }
sudo install -Dm644 "$KEY" "$ROOTFS/usr/share/elvonos/update/elvonos.pub"
echo "installed update key into $ROOTFS"
