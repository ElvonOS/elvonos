#!/usr/bin/env bash
# ElvonOS V1 — Install Flathub and the preinstalled Flatpak apps
#
# Adds the Flathub remote system-wide (and for the live user), then installs
# Bazaar (app store) and Warehouse (Flatpak manager) into the system
# installation so they are available offline in the live image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
APPS=(io.github.kolunmi.Bazaar io.github.flattool.Warehouse)

echo "=================================================="
echo " ElvonOS V1 — Installing Flathub apps"
echo "=================================================="

sudo mkdir -p "$ROOTFS/var/lib/flatpak" "$ROOTFS/home/elvon/.local/share/flatpak"

need_mounts=0
for dir in proc dev sys; do
    if ! mountpoint -q "$ROOTFS/$dir"; then
        sudo mount --bind "/$dir" "$ROOTFS/$dir"
        need_mounts=1
    fi
done
cleanup() {
    if [ "$need_mounts" = "1" ]; then
        for dir in sys dev proc; do
            sudo umount "$ROOTFS/$dir" 2>/dev/null || true
        done
    fi
}
trap cleanup EXIT

echo "==> Adding Flathub remote (system)"
sudo chroot "$ROOTFS" flatpak remote-add --system --if-not-exists flathub "$REMOTE_URL"

for app in "${APPS[@]}"; do
    if sudo chroot "$ROOTFS" flatpak info --system "$app" >/dev/null 2>&1; then
        echo "==> Already installed: $app"
        continue
    fi
    echo "==> Installing $app"
    sudo chroot "$ROOTFS" flatpak install --system --noninteractive -y flathub "$app"
done

echo "==> Adding Flathub remote for user elvon"
sudo chown -R 1000:1000 "$ROOTFS/home/elvon/.local/share/flatpak" 2>/dev/null || true
sudo chroot "$ROOTFS" runuser -u elvon -- env HOME=/home/elvon \
    flatpak --user remote-add --if-not-exists flathub "$REMOTE_URL" || true

echo "==> Setting software renderer for Flatpak GTK apps"
sudo chroot "$ROOTFS" flatpak override --system --env=GSK_RENDERER=cairo io.github.kolunmi.Bazaar || true
sudo chroot "$ROOTFS" flatpak override --system --env=GSK_RENDERER=cairo io.github.flattool.Warehouse || true

echo "==> Trimming Flatpak locale extensions"
for ref in $(sudo chroot "$ROOTFS" flatpak list --system --all --columns=ref 2>/dev/null | grep '\.Locale/'); do
    sudo chroot "$ROOTFS" flatpak uninstall --system -y "$ref" >/dev/null 2>&1 || true
done

echo "==> Installed Flatpak apps"
sudo chroot "$ROOTFS" flatpak list --system --app --columns=application,origin,branch || true

echo "==> Caching the Flathub catalog for the Store"
sudo mkdir -p "$ROOTFS/usr/share/elvonos"
sudo chroot "$ROOTFS" flatpak remote-ls flathub --app \
    --columns=application,name,description \
    > "$ROOTFS/usr/share/elvonos/flathub-catalog.tsv" 2>/dev/null || true

echo "==> Exported desktop entries"
sudo find "$ROOTFS/var/lib/flatpak/exports/share/applications" -maxdepth 1 -name '*.desktop' -printf '%f\n' 2>/dev/null | sort
