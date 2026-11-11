#!/usr/bin/env bash
# Publish an ElvonOS release and its update components.
#
# Usage: publish-update.sh <version>
#
# Uploads the ISO and signed update components to SourceForge, writes the signed
# feed (ISO + components) and pushes it to GitHub/Codeberg.
set -euo pipefail

VERSION="${1:?Usage: publish-update.sh VERSION}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ISO="$REPO_ROOT/build/out/ElvonOS-$VERSION-amd64.iso"
KEY="${ELVONOS_UPDATE_KEY_SECRET:-$HOME/.config/elvonos/keys/elvonos.key}"
PUB="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.pub}"
FEED_REPO="${FEED_REPO:-/tmp/elvonos-updates}"
ROOTFS="${ROOTFS:-$REPO_ROOT/build/out/rootfs}"
SF_USER="${SF_USER:-elvonos}"
SF_HOST="frs.sourceforge.net"
SF_RELEASE="/home/frs/project/elvonos/releases/$VERSION"
SF_COMPONENTS="/home/frs/project/elvonos/components"
BASE_URL="https://downloads.sourceforge.net/project/elvonos"
WORK="$(mktemp -d)"

[ -f "$ISO" ] || { echo "ISO missing: $ISO" >&2; exit 1; }
[ -f "$KEY" ] || { echo "signing key missing: $KEY" >&2; exit 1; }

echo "==> Building software payload"
bash "$REPO_ROOT/build/update/make-payload.sh" "$VERSION" \
    "$WORK/elvonos-apps-$VERSION.tar.zst"
PAYLOAD="$WORK/elvonos-apps-$VERSION.tar.zst"

echo "==> Signing"
minisign -Sm "$ISO" -s "$KEY" -t "ElvonOS $VERSION"
SHA256=$(sha256sum "$ISO" | cut -d' ' -f1)
SIZE=$(stat -c %s "$ISO")
printf '%s  %s\n' "$SHA256" "$(basename "$ISO")" > "$WORK/SHA256SUMS"
minisign -Sm "$WORK/SHA256SUMS" -s "$KEY" -t "ElvonOS $VERSION checksums"

minisign -Sm "$PAYLOAD" -s "$KEY" -t "ElvonOS $VERSION apps payload"
PAYLOAD_SHA=$(sha256sum "$PAYLOAD" | cut -d' ' -f1)

cp "$REPO_ROOT/base/configuration/scripts/elvonos-flatpak-setup" \
   "$WORK/flatpak-store-1.sh"
minisign -Sm "$WORK/flatpak-store-1.sh" -s "$KEY" -t "ElvonOS Flathub setup"
FLATPAK_SHA=$(sha256sum "$WORK/flatpak-store-1.sh" | cut -d' ' -f1)

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

Update components (signed):
  components/elvonos-apps-$VERSION.tar.zst
  components/flatpak-store-1.sh

Verify:
  sha256sum -c SHA256SUMS
  minisign -Vm ElvonOS-$VERSION-amd64.iso -p elvonos.pub
EOF

echo "==> Creating SourceForge directories"
printf 'mkdir %s\nmkdir %s\nmkdir %s\n' \
    "/home/frs/project/elvonos/releases" "$SF_RELEASE" "$SF_COMPONENTS" | \
    sftp -o BatchMode=yes "$SF_USER@$SF_HOST" >/dev/null 2>&1 || true

echo "==> Uploading components and checksums"
rsync -avP --timeout=120 \
    "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" "$WORK/README.txt" \
    "$ISO.minisig" \
    "$SF_USER@$SF_HOST:$SF_RELEASE/"
rsync -avP --timeout=120 \
    "$PAYLOAD" "$PAYLOAD.minisig" \
    "$WORK/flatpak-store-1.sh" "$WORK/flatpak-store-1.sh.minisig" \
    "$SF_USER@$SF_HOST:$SF_COMPONENTS/"

echo "==> Uploading ISO (resumable)"
rsync -avP --partial --timeout=300 --exclude '*.part' \
    "$ISO" "$SF_USER@$SF_HOST:$SF_RELEASE/"

echo "==> Writing feed"
python3 - "$FEED_REPO/feeds/stable.json" "$VERSION" "$SIZE" "$SHA256" \
    "$BASE_URL/releases/$VERSION/$(basename "$ISO")" \
    "$PAYLOAD_SHA" "$FLATPAK_SHA" <<'PY'
import datetime
import json
import sys

path, version, size, sha, iso_url, payload_sha, flatpak_sha = sys.argv[1:8]
base = "https://downloads.sourceforge.net/project/elvonos/components"
data = {
    "channel": "stable",
    "version": version,
    "released": datetime.datetime.now(datetime.timezone.utc)
                .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "min_supported": "1.0.0",
    "iso": {
        "url": iso_url,
        "size": int(size),
        "sha256": sha,
        "signature": iso_url + ".minisig",
    },
    "components": {
        "elvonos-apps": {
            "version": version,
            "type": "payload",
            "url": f"{base}/elvonos-apps-{version}.tar.zst",
            "sha256": payload_sha,
            "signature": f"{base}/elvonos-apps-{version}.tar.zst.minisig",
        },
        "flatpak-store": {
            "version": "1",
            "type": "script",
            "url": f"{base}/flatpak-store-1.sh",
            "sha256": flatpak_sha,
            "signature": f"{base}/flatpak-store-1.sh.minisig",
        },
    },
}
with open(path, "w") as handle:
    handle.write(json.dumps(data, indent=2) + "\n")
print(path)
PY

mkdir -p "$FEED_REPO/feeds"
minisign -Sm "$FEED_REPO/feeds/stable.json" -s "$KEY" -t "ElvonOS feed $VERSION"
cp "$PUB" "$FEED_REPO/elvonos.pub" 2>/dev/null || true

# SourceForge is the primary feed origin (no CDN cache, same host as artifacts)
printf 'mkdir /home/frs/project/elvonos/feeds\n' | \
    sftp -o BatchMode=yes "$SF_USER@$SF_HOST" >/dev/null 2>&1 || true
rsync -avP --timeout=120 \
    "$FEED_REPO/feeds/stable.json" "$FEED_REPO/feeds/stable.json.minisig" \
    "$SF_USER@$SF_HOST:/home/frs/project/elvonos/feeds/"

if [ -d "$FEED_REPO/.git" ]; then
    git -C "$FEED_REPO" add feeds elvonos.pub 2>/dev/null || true
    git -C "$FEED_REPO" commit -m "release: ElvonOS $VERSION" || true
    git -C "$FEED_REPO" push origin main || true
fi
if [ -x "$REPO_ROOT/build/update/mirror-codeberg.sh" ] && \
   [ -n "${CB_USER:-}" ]; then
    CB_USER="$CB_USER" bash "$REPO_ROOT/build/update/mirror-codeberg.sh" "$FEED_REPO" || true
fi

echo "==> Done"
echo "ISO:      $ISO"
echo "SHA256:   $SHA256"
echo "Payload:  $PAYLOAD ($PAYLOAD_SHA)"
echo "Download: $BASE_URL/releases/$VERSION/$(basename "$ISO")"
