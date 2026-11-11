#!/usr/bin/env bash
# Spiegel eines ElvonOS-Repositories nach Codeberg.
#
# Voraussetzungen:
#   - Codeberg-Konto + Repo (z. B. elvonos-updates) vorhanden
#   - SSH-Key im Codeberg-Konto hinterlegt (Settings → SSH/GPG Keys)
#
# Aufruf:
#   CB_USER=<name> [CB_REPO=elvonos-updates] bash build/update/mirror-codeberg.sh [REPO-PFAD]
set -euo pipefail

SOURCE="${1:-/tmp/elvonos-updates}"
CB_USER="${CB_USER:?Codeberg-Benutzername fehlt (CB_USER=<name>)}"
CB_REPO="${CB_REPO:-elvonos-updates}"
REMOTE="codeberg"

cd "$SOURCE"
git remote remove "$REMOTE" 2>/dev/null || true
git remote add "$REMOTE" "git@codeberg.org:${CB_USER}/${CB_REPO}.git"

echo "==> Spiegele $(git remote get-url origin 2>/dev/null || echo "$SOURCE") nach Codeberg"
git push --mirror "$REMOTE"

echo "==> Fertig: https://codeberg.org/${CB_USER}/${CB_REPO}"
