#!/usr/bin/env bash
# Build a signed-updatable payload of the ElvonOS software (our apps, scripts,
# desktop integration). The updater verifies sha256 + minisign and extracts it
# over / on an installed system.
#
# Usage: make-payload.sh <version> [output]
set -euo pipefail

VERSION="${1:?Usage: make-payload.sh VERSION [OUTPUT]}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROOTFS="${ROOTFS:-$REPO_ROOT/build/out/rootfs}"
OUT="${2:-$REPO_ROOT/build/out/payloads/elvonos-apps-$VERSION.tar.zst}"

[ -d "$ROOTFS" ] || { echo "rootfs not found: $ROOTFS" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

cd "$ROOTFS"
paths=()
for dir in \
    usr/lib/elvonos \
    usr/share/elvonos \
    usr/share/backgrounds/elvonos \
    usr/share/sounds/elvonos \
    usr/share/doc/elvonos \
    etc/elvonos; do
    [ -e "$dir" ] && paths+=("$dir")
done
[ -d usr/share/applications/elvonos ] && paths+=("usr/share/applications/elvonos")
for f in usr/share/applications/elvonos*.desktop \
         usr/share/wayland-sessions/elvonos.desktop \
         etc/systemd/system/elvonos-*.service \
         etc/systemd/system/elvonos-*.timer; do
    if [ -e "$f" ] || [ -L "$f" ]; then paths+=("$f"); fi
done
while IFS= read -r f; do paths+=("$f"); done < <(
    find usr/bin -maxdepth 1 -type f \( -name 'elvonos-*' -o -name 'Win8*' \) -print
)
while IFS= read -r f; do paths+=("$f"); done < <(
    find usr/local/bin -maxdepth 1 -type f -name 'Win8*' -print 2>/dev/null
)
while IFS= read -r f; do paths+=("$f"); done < <(
    find usr/share/icons -type f \( -name 'elvonos-*' -o -name 'Win8*' \) -print 2>/dev/null
)

tar --zstd --owner=0 --group=0 --numeric-owner \
    --exclude='*.apk' \
    -cf "$OUT" "${paths[@]}"

size=$(stat -c %s "$OUT")
sha=$(sha256sum "$OUT" | cut -d' ' -f1)
echo "$OUT"
echo "size=$size"
echo "sha256=$sha"
