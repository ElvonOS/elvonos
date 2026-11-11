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
sudo chroot "$ROOTFS" groupadd -f nopasswdlogin
if ! sudo chroot "$ROOTFS" id -u elvon >/dev/null 2>&1; then
    sudo chroot "$ROOTFS" useradd -m -s /bin/bash -u 1000 -U -G sudo,audio,video,render,input,users,nopasswdlogin elvon
else
    sudo chroot "$ROOTFS" usermod -aG nopasswdlogin elvon
fi

# Set password 'elvon' and passwordless sudo
echo "elvon:elvon" | sudo chroot "$ROOTFS" chpasswd
sudo mkdir -p "$ROOTFS/etc/sudoers.d"
echo "elvon ALL=(ALL) NOPASSWD:ALL" | sudo tee "$ROOTFS/etc/sudoers.d/elvon" >/dev/null
sudo chmod 0440 "$ROOTFS/etc/sudoers.d/elvon"

# Configure PAM for greetd to allow auto-login without password
echo "==> Configuring PAM for greetd autologin..."
cat << 'EOF' | sudo tee "$ROOTFS/etc/pam.d/greetd" >/dev/null
#%PAM-1.0
auth        sufficient  pam_succeed_if.so user = elvon
auth        sufficient  pam_succeed_if.so user ingroup nopasswdlogin
auth        include     common-auth
account     include     common-account
session     required    pam_env.so
session     optional    pam_loginuid.so
session     include     common-session
password    include     common-password
EOF

# 2. Update elvonos-session with VM/QEMU Wayland compatibility
echo "==> Updating /usr/bin/elvonos-session..."
cat << 'EOF' | sudo tee "$ROOTFS/usr/bin/elvonos-session" >/dev/null
#!/usr/bin/env bash
# ElvonOS V1 — Session Entrypoint (Labwc)
set -euo pipefail

# Wayland environment
export XDG_CURRENT_DESKTOP="ElvonOS:labwc"
export XDG_SESSION_TYPE="wayland"
export XDG_SESSION_DESKTOP="ElvonOS"
export QT_QPA_PLATFORM="wayland"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
export GDK_BACKEND="wayland"
export SDL_VIDEODRIVER="wayland"
export _JAVA_AWT_WM_NONREPARENTING=1

# Keyboard layout
export XKB_DEFAULT_LAYOUT="de,us"

# Avoid the xdg-desktop-portal timeout in the live ISO (Waybar/GTK).
export GTK_USE_PORTAL="0"

# Hardware / VM rendering flags
# WLR_BACKENDS overrides wlroots' backend auto-detection. The "libinput"
# backend must be listed explicitly, otherwise no keyboard/mouse devices
# are opened at all.
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
export WLR_BACKENDS=drm,libinput
export WLR_RENDERER=pixman
export WLR_DRM_NO_ATOMIC=1
export WLR_DRM_NO_MODIFIERS=1

# DRM device for wlroots/labwc (QEMU virtio-gpu exposes /dev/dri/card0)
if [[ -c /dev/dri/card0 ]]; then
    export WLR_DRM_DEVICES=/dev/dri/card0
fi

# Log session to both file and serial console (if available)
if [[ -c /dev/ttyS0 ]]; then
    exec > >(tee -a "$HOME/.elvonos-session.log" /dev/ttyS0) 2>&1
else
    exec > >(tee -a "$HOME/.elvonos-session.log") 2>&1
fi

echo "=================================================="
echo " Starting ElvonOS Desktop Session at $(date)"
echo "=================================================="

if command -v labwc >/dev/null 2>&1; then
    echo "==> Starting Labwc compositor..."
    if command -v dbus-run-session >/dev/null 2>&1; then
        exec dbus-run-session labwc
    else
        exec labwc
    fi
elif command -v Hyprland >/dev/null 2>&1; then
    echo "==> Labwc not found, starting Hyprland compositor..."
    HYPRLAND_CONFIG="/etc/elvonos/hyprland.conf"
    if [[ -f "$HOME/.config/elvonos/hyprland.conf" ]]; then
        HYPRLAND_CONFIG="$HOME/.config/elvonos/hyprland.conf"
    fi
    exec Hyprland --config "$HYPRLAND_CONFIG"
elif command -v sway >/dev/null 2>&1; then
    echo "==> Launching Sway compositor..."
    SWAY_CONFIG="/etc/elvonos/sway.conf"
    if [[ -f "$HOME/.config/elvonos/sway.conf" ]]; then
        SWAY_CONFIG="$HOME/.config/elvonos/sway.conf"
    fi
    exec sway -c "$SWAY_CONFIG"
else
    echo "Error: Neither Labwc, Hyprland nor Sway is installed!"
    exit 1
fi
EOF

sudo chmod +x "$ROOTFS/usr/bin/elvonos-session"
sudo cp -f "$ROOTFS/usr/bin/elvonos-session" "$REPO_ROOT/base/configuration/session/elvonos-session"

# 3. Rely on agetty autologin (already configured via autologin.conf)
# greetd/agreety is not used to avoid "agreety: not found" errors.
# Mask greetd if present to prevent conflicts.
sudo chroot "$ROOTFS" systemctl mask greetd.service 2>/dev/null || true
# Also mask serial getty to avoid ttyS0 login prompt conflicts
sudo chroot "$ROOTFS" systemctl mask serial-getty@ttyS0.service 2>/dev/null || true
# Ensure no getty on tty50 (non-existent device)
sudo chroot "$ROOTFS" systemctl mask getty@tty50.service 2>/dev/null || true
# Unmask getty@tty1 (may have been masked) and ensure it is enabled
sudo rm -f "$ROOTFS/etc/systemd/system/getty@tty1.service"
sudo chroot "$ROOTFS" systemctl unmask getty@tty1.service 2>/dev/null || true
sudo chroot "$ROOTFS" systemctl enable getty@tty1.service 2>/dev/null || true
# Remove elvonos-labwc.service entirely — labwc starts from tty1 login, not systemd
sudo rm -f "$ROOTFS/etc/systemd/system/elvonos-labwc.service"
sudo rm -f "$ROOTFS/etc/systemd/system/multi-user.target.wants/elvonos-labwc.service"
# Ensure systemd-logind is enabled for seat management
sudo chroot "$ROOTFS" systemctl enable systemd-logind.service 2>/dev/null || true

# 4. Configure Live ISO Waydroid Auto-init Service
echo "==> Setting up elvonos-waydroid-init service..."
cat << 'EOF' | sudo tee "$ROOTFS/usr/bin/elvonos-waydroid-init" >/dev/null
#!/usr/bin/env bash
# Initialize Waydroid from the images bundled on the live medium or installed
# in /etc/waydroid-extra/images (written by elvonos-installer).
#
# On the live medium the images stay on the read-only ISO and are linked, so
# the 2 GB image pair is not copied into the RAM overlay.
set -euo pipefail

LIVE_IMAGES="/run/live/medium/elvonos/waydroid"
LIVE_DEST="/usr/share/waydroid-extra/images"
INSTALLED="/etc/waydroid-extra/images"

# Waydroid mounts the image pair through loop devices.
modprobe loop 2>/dev/null || true

have_images=0
if [[ -f "$LIVE_IMAGES/system.img" && -f "$LIVE_IMAGES/vendor.img" ]]; then
    mkdir -p "$LIVE_DEST"
    ln -sf "$LIVE_IMAGES/system.img" "$LIVE_DEST/system.img"
    ln -sf "$LIVE_IMAGES/vendor.img" "$LIVE_DEST/vendor.img"
    have_images=1
elif [[ -f "$INSTALLED/system.img" && -f "$INSTALLED/vendor.img" ]]; then
    have_images=1
fi

if [[ "$have_images" == "1" && ! -f /var/lib/waydroid/waydroid.cfg ]]; then
    echo "==> Initializing Waydroid from preinstalled images..."
    waydroid init -f
fi

if [[ "$have_images" == "1" ]]; then
    for propfile in /var/lib/waydroid/waydroid_base.prop /var/lib/waydroid/waydroid.prop; do
        if [ -f "$propfile" ] && ! grep -q '^persist.waydroid.multi_windows=' "$propfile"; then
            echo 'persist.waydroid.multi_windows=true' >> "$propfile"
        fi
        if [ -f "$propfile" ] && ! grep -q '^ro.hw_timeout_multiplier=' "$propfile"; then
            echo 'ro.hw_timeout_multiplier=10' >> "$propfile"
        fi
    done
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
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF

sudo chroot "$ROOTFS" systemctl enable elvonos-waydroid-init.service 2>/dev/null || true

echo "=================================================="
echo " Desktop login & auto-start successfully configured!"
echo "=================================================="
