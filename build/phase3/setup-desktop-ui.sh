#!/usr/bin/env bash
# ElvonOS V1 — Setup Desktop UI, Swaybar, and Welcome message
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"

echo "==> Configuring Sway & Desktop UI..."

# 1. Copy Sway configuration
sudo mkdir -p "$ROOTFS/etc/elvonos" "$ROOTFS/usr/share/elvonos/sway"
sudo cp -f "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/etc/elvonos/sway.conf"
sudo cp -f "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/usr/share/elvonos/sway/config"

# 2. Add Welcome Banner to bashrc
cat << 'EOF' | sudo tee -a "$ROOTFS/etc/skel/.bashrc" >/dev/null

echo -e "\033[1;36m"
cat << 'BANNER'
  _____ _                 ___  ____  
 | ____| |_   _____  _ __/ _ \/ ___| 
 |  _| | \ \ / / _ \| '_ \ | | \___ \ 
 | |___| |\ V / (_) | | | | |_| |___) |
 |_____|_| \_/ \___/|_| |_|\___/|____/ 
BANNER
echo -e "\033[0;32mWelcome to ElvonOS V1 (Debian 13 Trixie + Labwc + Waydroid)\033[0m"
echo -e "Shortcuts:"
echo -e "  \033[1mSuper + Enter\033[0m : Terminal (foot)"
echo -e "  \033[1mSuper + D\033[0m     : App Launcher (wofi)"
echo -e "  \033[1mSuper + Q\033[0m     : Close Window"
echo -e "  \033[1mSuper + F\033[0m     : Fullscreen"
echo -e ""
EOF

if [[ -d "$ROOTFS/home/elvon" ]]; then
    sudo cp -f "$ROOTFS/etc/skel/.bashrc" "$ROOTFS/home/elvon/.bashrc"
    sudo chown 1000:1000 "$ROOTFS/home/elvon/.bashrc"
fi

echo "==> Desktop UI configured successfully!"
