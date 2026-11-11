#!/usr/bin/env bash
# ElvonOS V1 — Install Waydroid and Desktop Stack into Rootfs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
PKG_DIR="$REPO_ROOT/build/out/packages"

echo "=================================================="
echo " ElvonOS V1 — Integrating Waydroid & Sway into Rootfs"
echo "=================================================="

# 1. Stage custom deb packages inside rootfs
sudo mkdir -p "$ROOTFS/tmp/elvonos-pkgs"
sudo cp -f "$PKG_DIR"/*.deb "$ROOTFS/tmp/elvonos-pkgs/"

# 2. Update and install dependencies
echo "==> Installing desktop, sway, and waydroid runtime dependencies..."
sudo chroot "$ROOTFS" apt-get update
sudo chroot "$ROOTFS" apt-get install -y --no-install-recommends \
    ca-certificates \
    labwc swaybg waybar wlr-randr xwayland wl-clipboard sudo \
    python3 python3-gi gir1.2-gtk-3.0 python3-dbus \
    lxc lxcfs iptables nftables polkitd \
    grim \
    erofs-utils android-sdk-libsparse-utils attr zip unzip jq rsync e2fsprogs \
    fonts-noto fonts-noto-color-emoji

# 3. Install custom packages inside chroot
echo "==> Installing Waydroid and GBinder packages..."
sudo chroot "$ROOTFS" bash -c "dpkg -i /tmp/elvonos-pkgs/*.deb || apt-get install -y -f --no-install-recommends"

# The repackaged .deb loses the executable bit on the Python entrypoint that
# /usr/bin/waydroid points to (systemd otherwise fails with 203/EXEC), and on
# the network setup script (session start fails with PermissionError).
sudo chmod 755 "$ROOTFS/usr/lib/waydroid/waydroid.py"
sudo chmod 755 "$ROOTFS/usr/lib/waydroid/data/scripts/waydroid-net.sh"

# Clean up temporary packages
sudo rm -rf "$ROOTFS/tmp/elvonos-pkgs"

# 4. Install ElvonOS session and configs into rootfs
echo "==> Installing ElvonOS desktop session and Sway configurations..."
sudo mkdir -p "$ROOTFS/usr/bin" \
             "$ROOTFS/usr/share/wayland-sessions" \
             "$ROOTFS/etc/elvonos" \
             "$ROOTFS/usr/share/elvonos/waydroid"

sudo cp -f "$REPO_ROOT/base/configuration/session/elvonos-session" "$ROOTFS/usr/bin/"
sudo cp -f "$REPO_ROOT/base/configuration/session/elvonos-session-startup" "$ROOTFS/usr/bin/"
sudo chmod +x "$ROOTFS/usr/bin/elvonos-session" "$ROOTFS/usr/bin/elvonos-session-startup"

sudo cp -f "$REPO_ROOT/base/configuration/wayland-sessions/elvonos.desktop" "$ROOTFS/usr/share/wayland-sessions/"
sudo cp -f "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/etc/elvonos/sway.conf"
sudo cp -f "$REPO_ROOT/base/configuration/hypr/hyprland.conf" "$ROOTFS/etc/elvonos/hyprland.conf"
sudo cp -f "$REPO_ROOT/base/configuration/waydroid/elvonos-waydroid.properties" "$ROOTFS/usr/share/elvonos/waydroid/"

# 5. Enable Waydroid container service in systemd
echo "==> Enabling waydroid-container service..."
sudo chroot "$ROOTFS" systemctl enable waydroid-container.service 2>/dev/null || true

# 6. Update packages.lock
echo "==> Updating packages.lock..."
sudo chroot "$ROOTFS" dpkg-query -W -f='${Package}=${Version}\n' > "$REPO_ROOT/build/out/packages.lock"

echo "=================================================="
echo " Waydroid & Sway desktop successfully installed in rootfs!"
echo " Total packages now installed: $(wc -l < "$REPO_ROOT/build/out/packages.lock")"
echo "=================================================="
