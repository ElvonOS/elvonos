#!/usr/bin/env bash
# ElvonOS V1 — Phase 1: Install Build Dependencies
# Reads base/packages/build-host.list and installs build dependencies on Debian 13 host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIST_FILE="$REPO_ROOT/base/packages/build-host.list"

ASSUME_YES=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
    ASSUME_YES=true
fi

if [[ $EUID -ne 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
        echo "Error: This script requires root privileges to install packages."
        echo "Run with sudo or pass --yes if sudo is configured."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

if [[ ! -f "$LIST_FILE" ]]; then
    echo "Error: Package list not found at $LIST_FILE"
    exit 1
fi

echo "==> Reading packages from base/packages/build-host.list..."
PACKAGES=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ -n "$line" ]]; then
        PACKAGES+=("$line")
    fi
done < "$LIST_FILE"

echo "==> Found ${#PACKAGES[@]} packages to install."

APT_FLAGS=("-y" "--no-install-recommends")
if [[ "$ASSUME_YES" != "true" ]]; then
    read -r -p "Proceed with installing ${#PACKAGES[@]} packages? [y/N] " response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Aborted by user."
        exit 0
    fi
fi

echo "==> Updating package index..."
$SUDO apt-get update

echo "==> Installing build dependencies..."
# Filter any packages that might not be available or install them in batch
$SUDO apt-get install "${APT_FLAGS[@]}" "${PACKAGES[@]}"

echo "==> Build dependencies installed successfully."
