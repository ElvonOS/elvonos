#!/usr/bin/env bash
# ElvonOS V1 — Configure Desktop Auto-login and Session Startup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"

echo "=================================================="
echo " ElvonOS V1 — Configuring Desktop Auto-login & Greetd"
echo "=================================================="

# 1. Create default live user 'elvon' inside rootfs
echo "==> Setting up default user 'elvon'..."
if ! sudo chroot "$ROOTFS" id -u elvon >/dev/null 2>&1; then
    sudo chroot "$ROOTFS" useradd -m -s /bin/bash -u 1000 -U -G sudo,audio,video,render,input,users elvon
fi

# Set password 'elvon' and passwordless sudo
echo "elvon:elvon" | sudo chroot "$ROOTFS" chpasswd
sudo mkdir -p "$ROOTFS/etc/sudoers.d"
echo "elvon ALL=(ALL) NOPASSWD:ALL" | sudo tee "$ROOTFS/etc/sudoers.d/elvon" >/dev/null
sudo chmod 0440 "$ROOTFS/etc/sudoers.d/elvon"

# 2. Update elvonos-session with VM/QEMU Wayland compatibility
echo "==> Updating /usr/bin/elvonos-session..."
cat << 'EOF' | sudo tee "$ROOTFS/usr/bin/elvonos-session" >/dev/null
#!/usr/bin/env bash
# ElvonOS V1 — Session Entrypoint
set -euo pipefail

# Wayland environment
export XDG_CURRENT_DESKTOP="ElvonOS:Hyprland"
export XDG_SESSION_TYPE="wayland"
export XDG_SESSION_DESKTOP="ElvonOS"
export QT_QPA_PLATFORM="wayland"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
export GDK_BACKEND="wayland"
export SDL_VIDEODRIVER="wayland"
export _JAVA_AWT_WM_NONREPARENTING=1

# Hardware / VM rendering flags
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1

# Log session
exec > >(tee -a "$HOME/.elvonos-session.log") 2>&1

echo "=================================================="
echo " Starting ElvonOS Desktop Session at $(date)"
echo "=================================================="

HYPRLAND_CONFIG="/etc/elvonos/hyprland.conf"
if [[ -f "$HOME/.config/elvonos/hyprland.conf" ]]; then
    HYPRLAND_CONFIG="$HOME/.config/elvonos/hyprland.conf"
fi

SWAY_CONFIG="/etc/elvonos/sway.conf"
if [[ -f "$HOME/.config/elvonos/sway.conf" ]]; then
    SWAY_CONFIG="$HOME/.config/elvonos/sway.conf"
fi

if command -v Hyprland >/dev/null 2>&1; then
    echo "==> Starting Hyprland compositor..."
    exec Hyprland --config "$HYPRLAND_CONFIG"
elif command -v sway >/dev/null 2>&1; then
    echo "==> Launching Sway compositor..."
    exec sway -c "$SWAY_CONFIG"
else
    echo "Error: Neither Hyprland nor Sway is installed!"
    exit 1
fi
EOF

sudo chmod +x "$ROOTFS/usr/bin/elvonos-session"
sudo cp -f "$ROOTFS/usr/bin/elvonos-session" "$REPO_ROOT/base/configuration/session/elvonos-session"

# 3. Configure Greetd for automated initial session login
echo "==> Configuring /etc/greetd/config.toml..."
sudo mkdir -p "$ROOTFS/etc/greetd"
cat << 'EOF' | sudo tee "$ROOTFS/etc/greetd/config.toml" >/dev/null
[terminal]
vt = 1

[default_session]
command = "agreety --cmd /usr/bin/elvonos-session"
user = "elvon"

[initial_session]
command = "/usr/bin/elvonos-session"
user = "elvon"
EOF

# Ensure greetd is enabled in systemd
sudo chroot "$ROOTFS" systemctl enable greetd.service 2>/dev/null || true

# 4. Configure Live ISO Waydroid Auto-init Service
echo "==> Setting up elvonos-waydroid-init service..."
cat << 'EOF' | sudo tee "$ROOTFS/usr/bin/elvonos-waydroid-init" >/dev/null
#!/usr/bin/env bash
# Initialize Waydroid images from live medium if available
set -euo pipefail

LIVE_IMAGES="/run/live/medium/elvonos/waydroid"
DEST="/var/lib/waydroid/images"

if [[ -d "$LIVE_IMAGES" && ! -f "$DEST/system.img" ]]; then
    echo "==> Initializing Waydroid from Live medium..."
    mkdir -p "$DEST"
    if [[ -f "$LIVE_IMAGES/system.img" ]]; then
        # Use symlinks on live overlay to save RAM
        ln -sf "$LIVE_IMAGES/system.img" "$DEST/system.img"
        ln -sf "$LIVE_IMAGES/vendor.img" "$DEST/vendor.img"
        waydroid init -f 2>&1 || true
        systemctl restart waydroid-container.service 2>&1 || true
    fi
fi
EOF
sudo chmod +x "$ROOTFS/usr/bin/elvonos-waydroid-init"

cat << 'EOF' | sudo tee "$ROOTFS/etc/systemd/system/elvonos-waydroid-init.service" >/dev/null
[Unit]
Description=ElvonOS Waydroid Live Image Initializer
After=local-fs.target
Before=waydroid-container.service

[Service]
Type=oneshot
ExecStart=/usr/bin/elvonos-waydroid-init
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo chroot "$ROOTFS" systemctl enable elvonos-waydroid-init.service 2>/dev/null || true

echo "=================================================="
echo " Desktop login & auto-start successfully configured!"
echo "=================================================="
