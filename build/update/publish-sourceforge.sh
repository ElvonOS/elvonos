#!/usr/bin/env bash
# Veröffentlicht ein ElvonOS-ISO auf SourceForge, signiert es und aktualisiert
# den Update-Feed (GitHub + optional Codeberg).
#
# Aufruf:
#   publish-sourceforge.sh <version>
#
# Voraussetzungen:
#   - ~/.config/elvonos/keys/elvonos.{key,pub}
#   - SSH-Zugang elvonos@frs.sourceforge.net
#   - Clone des Feed-Repos (FEED_REPO, Standard /tmp/elvonos-updates)
set -euo pipefail

VERSION="${1:?Usage: publish-sourceforge.sh VERSION}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ISO="$REPO_ROOT/build/out/ElvonOS-$VERSION-amd64.iso"
KEY="${ELVONOS_UPDATE_KEY_SECRET:-$HOME/.config/elvonos/keys/elvonos.key}"
PUB="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.pub}"
FEED_REPO="${FEED_REPO:-/tmp/elvonos-updates}"
SF_USER="${SF_USER:-elvonos}"
SF_HOST="frs.sourceforge.net"
SF_DIR="/home/frs/project/elvonos/releases/$VERSION"
BASE_URL="https://downloads.sourceforge.net/project/elvonos/releases/$VERSION"

[ -f "$ISO" ] || { echo "ISO fehlt: $ISO" >&2; exit 1; }
[ -f "$KEY" ] || { echo "Signaturschlüssel fehlt: $KEY" >&2; exit 1; }

echo "==> Signiere ISO"
minisign -Sm "$ISO" -s "$KEY" -t "ElvonOS $VERSION"

echo "==> Prüfsummen"
SHA256=$(sha256sum "$ISO" | cut -d' ' -f1)
SIZE=$(stat -c %s "$ISO")
WORK=$(mktemp -d)
cat > "$WORK/SHA256SUMS" <<EOF
$SHA256  $(basename "$ISO")
EOF
minisign -Sm "$WORK/SHA256SUMS" -s "$KEY" -t "ElvonOS $VERSION checksums"

cat > "$WORK/README.txt" <<EOF
ElvonOS $VERSION (live ISO)

Base:    Debian 13 Trixie
Kernel:  6.12.116-elvonos (BinderFS, Virgl, NTFS3, all Debian drivers)
Desktop: Win8DE (labwc), ElvonOS apps, Waydroid
Install: boot the ISO, start "Install Elvon OS"

Files:
  ElvonOS-$VERSION-amd64.iso
  ElvonOS-$VERSION-amd64.iso.minisig
  SHA256SUMS
  SHA256SUMS.minisig

Verify:
  sha256sum -c SHA256SUMS
  minisign -Vm ElvonOS-$VERSION-amd64.iso -p elvonos.pub
EOF

echo "==> Erstelle Release-Verzeichnis"
printf 'mkdir %s\nmkdir %s\n' \
    "/home/frs/project/elvonos/releases" "$SF_DIR" | \
    sftp -o BatchMode=yes "$SF_USER@$SF_HOST" >/dev/null 2>&1 || true

echo "==> Lade Prüfsummen hoch"
rsync -avP --timeout=120 \
    "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" \
    "$WORK/README.txt" \
    "$ISO.minisig" \
    "$SF_USER@$SF_HOST:$SF_DIR/"

echo "==> Lade ISO hoch (wiederaufnehmbar)"
rsync -avP --partial --timeout=300 --exclude '*.part' \
    "$ISO" "$SF_USER@$SF_HOST:$SF_DIR/"

echo "==> Update-Feed"
mkdir -p "$FEED_REPO/feeds"
python3 - "$FEED_REPO/feeds/stable.json" "$VERSION" "$SIZE" "$SHA256" \
    "$BASE_URL/$(basename "$ISO")" <<'PY'
import datetime
import json
import sys

path, version, size, sha, url = sys.argv[1:6]
data = {
    "channel": "stable",
    "version": version,
    "released": datetime.datetime.now(datetime.timezone.utc)
                .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "min_supported": "1.0.0",
    "iso": {
        "url": url,
        "size": int(size),
        "sha256": sha,
        "signature": url + ".minisig",
    },
}
with open(path, "w") as handle:
    handle.write(json.dumps(data, indent=2) + "\n")
print(path)
PY
minisign -Sm "$FEED_REPO/feeds/stable.json" -s "$KEY" -t "ElvonOS feed $VERSION"
cp "$PUB" "$FEED_REPO/elvonos.pub" 2>/dev/null || true

if [ -d "$FEED_REPO/.git" ]; then
    git -C "$FEED_REPO" add feeds README.md elvonos.pub 2>/dev/null || true
    git -C "$FEED_REPO" commit -m "feed: ElvonOS $VERSION (SourceForge)" || true
    git -C "$FEED_REPO" push origin main || true
fi

echo "==> Fertig"
echo "ISO:      $ISO"
echo "SHA256:   $SHA256"
echo "Download: $BASE_URL/$(basename "$ISO")"
echo "Feed:     https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json"
