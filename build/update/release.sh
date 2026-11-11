#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:?Usage: release.sh VERSION}"
ISO="$REPO_ROOT/build/out/ElvonOS-$VERSION-amd64.iso"
OLD_VERSION="$(cat /tmp/elvonos-last-version 2>/dev/null || echo 1.0.0)"
OLD_ISO="$REPO_ROOT/build/out/ElvonOS-$OLD_VERSION-amd64.iso"
KEY="$HOME/.config/elvonos/keys/elvonos.key"
FEED_REPO="${FEED_REPO:-/tmp/elvonos-updates}"

echo "==> Baue ISO $VERSION"
ELVONOS_VERSION="$VERSION" REBUILD_SQUASHFS=1 \
    bash "$REPO_ROOT/build/phase7/build-iso.sh"

echo "==> Prüfsumme und Signatur"
SHA256=$(sha256sum "$ISO" | cut -d' ' -f1)
SIZE=$(stat -c %s "$ISO")
minisign -Sm "$ISO" -s "$KEY" -t "ElvonOS $VERSION"

echo "==> Delta-Patch (optional)"
DELTA=""
DELTA_SHA=""
if [ -f "$OLD_ISO" ]; then
    DELTA="$REPO_ROOT/build/out/ElvonOS-${OLD_VERSION}_to_${VERSION}.iso.zstpatch"
    zstd --patch-from="$OLD_ISO" "$ISO" -o "$DELTA"
    DELTA_SHA=$(sha256sum "$DELTA" | cut -d' ' -f1)
    minisign -Sm "$DELTA" -s "$KEY" -t "ElvonOS $VERSION delta"
fi

echo "==> GitHub Release"
FILES=("$ISO" "$ISO.minisig")
if [ -n "$DELTA" ]; then
    FILES+=("$DELTA" "$DELTA.minisig")
fi
gh release create "v$VERSION" "${FILES[@]}" \
    --repo ElvonOS/elvonos-os \
    --title "ElvonOS $VERSION" \
    --notes "ElvonOS $VERSION – Kernel, Desktop, Waydroid."

ISO_URL="https://github.com/ElvonOS/elvonos-os/releases/download/v$VERSION/$(basename "$ISO")"
DELTA_URL=""
[ -n "$DELTA" ] && DELTA_URL="https://github.com/ElvonOS/elvonos-os/releases/download/v$VERSION/$(basename "$DELTA")"

echo "==> Feed veröffentlichen"
"$REPO_ROOT/build/update/publish-feed.sh" \
    "$VERSION" "$ISO" "$SIZE" "$SHA256" "$ISO_URL" \
    "$DELTA_URL" "$DELTA_SHA"

echo "$VERSION" > /tmp/elvonos-last-version

echo "==> Fertig"
echo "ISO:    $ISO"
echo "SHA256: $SHA256"
