#!/usr/bin/env bash
# Lädt Release-Dateien zu einem Codeberg-Release hoch (Forgejo-API).
#
# Voraussetzungen:
#   - Codeberg-Access-Token mit Scope "write:repository"
#   - Release existiert (wird hier angelegt, falls nicht vorhanden)
#
# Aufruf:
#   CB_USER=<name> CB_TOKEN=<token> [CB_REPO=elvonos-updates] \
#       bash build/update/publish-codeberg-release.sh <version> <datei> [<datei> ...]
set -euo pipefail

VERSION="${1:?Usage: publish-codeberg-release.sh VERSION FILE...}"
shift
CB_USER="${CB_USER:?CB_USER fehlt}"
CB_REPO="${CB_REPO:-elvonos-updates}"
CB_TOKEN="${CB_TOKEN:?CB_TOKEN fehlt (Scope write:repository)}"
API="https://codeberg.org/api/v1/repos/${CB_USER}/${CB_REPO}"

existing=$(curl -fsS -H "Authorization: token ${CB_TOKEN}" \
    "${API}/releases/tags/v${VERSION}" 2>/dev/null | jq -r '.id // empty' || true)

if [ -z "${existing}" ]; then
    echo "==> Lege Release v${VERSION} an"
    existing=$(curl -fsS -X POST \
        -H "Authorization: token ${CB_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"tag_name\":\"v${VERSION}\",\"name\":\"ElvonOS ${VERSION}\"}" \
        "${API}/releases" | jq -r '.id')
fi

for file in "$@"; do
    echo "==> Lade $(basename "$file") hoch"
    curl -fsS -X POST \
        -H "Authorization: token ${CB_TOKEN}" \
        -F "attachment=@${file}" \
        "${API}/releases/${existing}/assets?name=$(basename "$file")" >/dev/null
done

echo "==> Fertig: https://codeberg.org/${CB_USER}/${CB_REPO}/releases"
