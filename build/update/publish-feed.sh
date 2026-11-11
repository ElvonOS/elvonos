#!/usr/bin/env bash
# Erzeugt feeds/stable.json (+ Signatur) aus einem Release.
# Aufruf: publish-feed.sh <version> <iso> <size> <sha256> <iso-url> [delta-url delta-sha]
set -euo pipefail

VERSION="$1"
ISO="$2"
SIZE="$3"
SHA256="$4"
ISO_URL="$5"
DELTA_URL="${6:-}"
DELTA_SHA="${7:-}"
FEED_REPO="${FEED_REPO:-/tmp/elvonos-updates}"
KEY="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.key}"
FEED="$FEED_REPO/feeds/stable.json"

mkdir -p "$FEED_REPO/feeds"

python3 - "$FEED" "$VERSION" "$SIZE" "$SHA256" "$ISO_URL" "$DELTA_URL" "$DELTA_SHA" <<'PY'
import datetime
import json
import os
import sys

feed, version, size, sha, url, durl, dsha = sys.argv[1:8]
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
if durl:
    data["delta"] = {
        "from": open("/tmp/elvonos-last-version").read().strip()
                if os.path.exists("/tmp/elvonos-last-version") else "1.0.0",
        "url": durl,
        "sha256": dsha,
        "signature": durl + ".minisig",
    }
with open(feed, "w") as handle:
    handle.write(json.dumps(data, indent=2) + "\n")
print(feed)
PY

minisign -Sm "$FEED" -s "$KEY" -t "ElvonOS feed $VERSION"

cd "$FEED_REPO"
git add feeds
git commit -m "feed: ElvonOS $VERSION"
git push origin main
