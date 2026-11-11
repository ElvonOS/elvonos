#!/usr/bin/env bash
# ElvonOS V1 — Install the Labwc desktop with Win8DE shell
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"
WIN8DE_BUILD="/tmp/Win8DE/build/bin"

echo "=================================================="
echo " ElvonOS V1 — Installing Labwc Desktop (Win8DE Shell)"
echo "=================================================="

# 1. Packages (labwc compositor + Qt6 runtime for Win8DE)
echo "==> Installing packages in rootfs..."
sudo chroot "$ROOTFS" apt-get update
sudo chroot "$ROOTFS" apt-get install -y --no-install-recommends \
    labwc sudo wlr-randr \
    libqt6core6 libqt6gui6 libqt6qml6 libqt6quick6 \
    qml6-module-qtquick-layouts qml6-module-qtquick-effects qml6-module-qtquick-controls qml6-module-qtquick-dialogs qml6-module-qtquick-particles qml6-module-qtmultimedia qt6-wayland libqt6svg6 qt6-svg-plugins qt6-image-formats-plugins \
    libgl1-mesa-dri libegl-mesa0 libgles2 libgbm1 mesa-vulkan-drivers \
    liblayershellqtinterface6 \
    adwaita-icon-theme hicolor-icon-theme breeze-icon-theme papirus-icon-theme \
    waybar wofi foot thunar brightnessctl alsa-utils swaybg zenity \
    flatpak xdg-desktop-portal xdg-desktop-portal-gtk polkitd \
    bindfs fuse3 udisks2 plymouth pulseaudio-utils grim slurp wl-clipboard zip unzip poppler-utils \
    libqt6multimedia6 qml6-module-qtmultimedia \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    cups cups-client sane-utils sane-airscan cups-pk-helper system-config-printer \
    file libglib2.0-bin xdg-utils network-manager-gnome \
    fonts-noto-cjk locales \
    bluez bluez-tools rfkill libinput-tools \
    network-manager-openvpn network-manager-openvpn-gnome openvpn wireguard-tools \
    swayidle wlopm fnott libnotify-bin

# 1b. Compile locales for every Settings interface language
echo "==> Generating locales for the supported interface languages..."
for locale_code in en_US de_DE fr_FR es_ES it_IT pt_PT nl_NL pl_PL ru_RU tr_TR uk_UA cs_CZ sv_SE zh_CN ja_JP; do
    sudo chroot "$ROOTFS" env LANG=C localedef -i "$locale_code" -f UTF-8 "$locale_code.UTF-8" \
        || echo "Warning: could not generate $locale_code.UTF-8"
done

# 2. Bash profile for auto-starting labwc on console login
echo "==> Installing bash profile for auto-start..."
sudo install -Dm644 "$REPO_ROOT/home/elvon/.bash_profile" "$ROOTFS/home/elvon/.bash_profile"

# 3. Labwc configuration (Win8DE labwc3 theme)
echo "==> Installing Labwc configuration (Win8DE labwc3)..."
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/rc.xml" "$ROOTFS/etc/xdg/labwc/rc.xml"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/menu.xml" "$ROOTFS/etc/xdg/labwc/menu.xml"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/environment" "$ROOTFS/etc/xdg/labwc/environment"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/themerc" "$ROOTFS/etc/xdg/labwc/themerc"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/themerc-override" "$ROOTFS/etc/xdg/labwc/themerc-override"
sudo install -Dm755 "$REPO_ROOT/base/configuration/labwc/autostart" "$ROOTFS/etc/xdg/labwc/autostart"

sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/rc.xml" "$ROOTFS/home/elvon/.config/labwc/rc.xml"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/menu.xml" "$ROOTFS/home/elvon/.config/labwc/menu.xml"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/environment" "$ROOTFS/home/elvon/.config/labwc/environment"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/themerc" "$ROOTFS/home/elvon/.config/labwc/themerc"
sudo install -Dm644 "$REPO_ROOT/base/configuration/labwc/themerc-override" "$ROOTFS/home/elvon/.config/labwc/themerc-override"
sudo install -Dm755 "$REPO_ROOT/base/configuration/labwc/autostart" "$ROOTFS/home/elvon/.config/labwc/autostart"

# 4e. Wayland session entry for Win8DE
echo "==> Installing Wayland session entry..."
sudo mkdir -p "$ROOTFS/usr/share/wayland-sessions"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wayland-sessions/elvonos-win8de.desktop" "$ROOTFS/usr/share/wayland-sessions/elvonos-win8de.desktop"

# 4f. Live tiles directory for Win8Start
echo "==> Creating Win8Start tiles directory..."
sudo mkdir -p "$ROOTFS/home/elvon/.config/Win8Start/tiles"
if [ -d "$REPO_ROOT/Win8Start/tiles" ]; then
    sudo cp -a "$REPO_ROOT/Win8Start/tiles/"* "$ROOTFS/home/elvon/.config/Win8Start/tiles/" 2>/dev/null || true
fi

# 4. Win8DE shell binaries (prebuilt on build host)
echo "==> Installing Win8DE shell binaries..."
for bin in "$WIN8DE_BUILD"/*; do
    if [ -f "$bin" ] && [ -x "$bin" ]; then
        name="$(basename "$bin")"
        sudo install -Dm755 "$bin" "$ROOTFS/usr/local/bin/$name"
    fi
done

# 4b. Wallpaper
echo "==> Installing wallpaper..."
sudo mkdir -p "$ROOTFS/usr/share/backgrounds/elvonos"
sudo install -Dm644 "$REPO_ROOT/wallpaper.png" "$ROOTFS/usr/share/backgrounds/elvonos/wallpaper.png"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wallpaper/glass-top.png" "$ROOTFS/usr/share/backgrounds/elvonos/glass-top.png"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wallpaper/glass-bottom.png" "$ROOTFS/usr/share/backgrounds/elvonos/glass-bottom.png"

# 4b2. Plymouth boot splash
if [ -d "$REPO_ROOT/base/configuration/plymouth/elvonos" ]; then
    echo "==> Installing Plymouth boot splash..."
    sudo install -Dm644 "$REPO_ROOT/base/configuration/plymouth/plymouthd.conf" \
        "$ROOTFS/etc/plymouth/plymouthd.conf"
    sudo mkdir -p "$ROOTFS/usr/share/plymouth/themes/elvonos"
    sudo cp -a "$REPO_ROOT/base/configuration/plymouth/elvonos/." \
        "$ROOTFS/usr/share/plymouth/themes/elvonos/"
    # Load virtio-gpu early so the splash gets an active KMS scanout in VMs.
    if ! grep -qx 'virtio_gpu' "$ROOTFS/etc/initramfs-tools/modules" 2>/dev/null; then
        echo 'virtio_gpu' | sudo tee -a "$ROOTFS/etc/initramfs-tools/modules" >/dev/null
    fi
    for d in proc dev sys; do
        mountpoint -q "$ROOTFS/$d" || sudo mount --bind "/$d" "$ROOTFS/$d"
    done
    sudo chroot "$ROOTFS" plymouth-set-default-theme elvonos >/dev/null 2>&1 || true
    sudo chroot "$ROOTFS" update-initramfs -u -k all >/dev/null 2>&1 || true
    for d in sys dev proc; do
        mountpoint -q "$ROOTFS/$d" && sudo umount "$ROOTFS/$d" || true
    done
fi

# 4c. Win8DE settings.ini
echo "==> Installing Win8DE settings.ini..."
sudo mkdir -p "$ROOTFS/home/elvon/.config/Win8DE"
sudo tee "$ROOTFS/home/elvon/.config/Win8DE/settings.ini" > /dev/null << 'EOF'
[Wallpaper]
path=/usr/share/backgrounds/elvonos/wallpaper.png
mode=fill

[General]
locale=C.UTF-8
EOF

# 5. Desktop icons (.desktop files), grouped by category
echo "==> Installing desktop icons..."
sudo mkdir -p "$ROOTFS/usr/share/applications/elvonos"
for f in "$REPO_ROOT"/base/configuration/desktop/desktop-icons/*.desktop; do
    sudo install -Dm644 "$f" "$ROOTFS/usr/share/applications/elvonos/$(basename "$f")"
done
# The Android entry also belongs in the flat application menu so Win8Start
# lists it next to the Linux applications.
sudo install -Dm644 "$REPO_ROOT/base/configuration/desktop/desktop-icons/android.desktop" \
    "$ROOTFS/usr/share/applications/android.desktop"
sudo mkdir -p "$ROOTFS/home/elvon/Desktop"
for f in "$REPO_ROOT"/base/configuration/desktop/desktop-icons/*.desktop; do
    case "$(basename "$f")" in
        files.desktop|android.desktop) group="Utilities" ;;
        *) group="System" ;;
    esac
    sudo install -Dm644 "$f" "$ROOTFS/home/elvon/Desktop/$group/$(basename "$f")"
done
# Live-only installer shortcut; the installer removes it from the target.
sudo install -Dm644 "$REPO_ROOT/base/configuration/installer/elvonos-installer.desktop" \
    "$ROOTFS/home/elvon/Desktop/Install ElvonOS.desktop"
sudo chown 1000:1000 "$ROOTFS/home/elvon/Desktop/Install ElvonOS.desktop"

# 5b. XDG user directories and a sample photo for the Gallery
for userdir in Documents Downloads Pictures Music Videos Public Templates; do
    sudo mkdir -p "$ROOTFS/home/elvon/$userdir"
    sudo chown 1000:1000 "$ROOTFS/home/elvon/$userdir"
done
sudo install -Dm644 "$REPO_ROOT/wallpaper.png" "$ROOTFS/home/elvon/Pictures/ElvonOS Wallpaper.png"
sudo chown 1000:1000 "$ROOTFS/home/elvon/Pictures/ElvonOS Wallpaper.png"

# 6. Getty autologin for elvon on tty1
echo "==> Installing getty autologin..."
sudo mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
sudo install -Dm644 "$REPO_ROOT/base/configuration/systemd/autologin.conf" "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf"

# 4g. Waydroid crash protection and health daemon
echo "==> Installing Waydroid crash protection and health daemon..."
sudo install -Dm755 "$REPO_ROOT/base/configuration/health/elvonos-healthd.py" "$ROOTFS/usr/share/elvonos/elvonos-healthd.py"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/waydroid-crash-recovery.sh" "$ROOTFS/usr/share/elvonos/waydroid-crash-recovery.sh"
sudo install -Dm644 "$REPO_ROOT/base/configuration/systemd/elvonos-healthd.service" "$ROOTFS/etc/systemd/system/elvonos-healthd.service"
sudo chroot "$ROOTFS" systemctl enable elvonos-healthd.service 2>/dev/null || true
sudo mkdir -p "$ROOTFS/var/log/elvonos/health" "$ROOTFS/var/log/elvonos/crash"

# 4d. Waydroid bridge (clipboard + notifications) and systemd user unit
if [ -f "$REPO_ROOT/base/configuration/waydroid/bridge.py" ]; then
    echo "==> Installing Waydroid clipboard/notification bridge..."
    sudo install -Dm755 "$REPO_ROOT/base/configuration/waydroid/bridge.py" "$ROOTFS/usr/bin/elvonos-waydroid-bridge"
fi
if [ -f "$REPO_ROOT/base/configuration/systemd/elvonos-waydroid.service" ]; then
    echo "==> Installing Waydroid supervisor user unit..."
    sudo install -Dm644 "$REPO_ROOT/base/configuration/systemd/elvonos-waydroid.service" \
        "$ROOTFS/usr/lib/systemd/user/elvonos-waydroid.service"
fi

# 4i. Metro icons for Win8DE
echo "==> Installing metro icons..."
sudo mkdir -p "$ROOTFS/usr/share/icons/elvonos/metro"
for icon in "$REPO_ROOT"/base/configuration/icons/metro/*; do
    [ -f "$icon" ] && sudo install -Dm644 "$icon" "$ROOTFS/usr/share/icons/elvonos/metro/$(basename "$icon")"
done

# 4j. Default Win8Start Metro tile layout generator
echo "==> Installing Win8Start default tile generator..."
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-win8start-defaults" "$ROOTFS/usr/bin/elvonos-win8start-defaults"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-menu" "$ROOTFS/usr/bin/elvonos-menu"

# 4j2. udisks2 polkit rule for the live user (drives/USB in the Explorer)
if [ -f "$REPO_ROOT/base/configuration/polkit/49-elvonos-udisks.rules" ]; then
    echo "==> Installing udisks2 polkit rule..."
    sudo install -Dm644 "$REPO_ROOT/base/configuration/polkit/49-elvonos-udisks.rules" \
        "$ROOTFS/etc/polkit-1/rules.d/49-elvonos-udisks.rules"
fi
echo "==> Installing Waydroid apps..."
sudo mkdir -p "$ROOTFS/usr/share/elvonos/waydroid/apps"
for apk in "$REPO_ROOT"/base/configuration/waydroid/apps/*.apk; do
    [ -f "$apk" ] && sudo install -Dm644 "$apk" "$ROOTFS/usr/share/elvonos/waydroid/apps/$(basename "$apk")"
done
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-apps.sh" "$ROOTFS/usr/share/elvonos/elvonos-waydroid-apps.sh"
# Rust integration binary (built by build/waydroid/build-waydroid-rs.sh).
if [ ! -x "$REPO_ROOT/build/out/elvonos-waydroid" ] || \
   [ "$REPO_ROOT/base/configuration/waydroid-rs/src/main.rs" -nt "$REPO_ROOT/build/out/elvonos-waydroid" ]; then
    ROOTFS="$ROOTFS" bash "$REPO_ROOT/build/waydroid/build-waydroid-rs.sh"
else
    sudo install -Dm755 "$REPO_ROOT/build/out/elvonos-waydroid" "$ROOTFS/usr/bin/elvonos-waydroid"
fi
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-sync" "$ROOTFS/usr/bin/elvonos-waydroid-sync"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-apk-entry" "$ROOTFS/usr/bin/elvonos-waydroid-apk-entry"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-install-apk" "$ROOTFS/usr/bin/elvonos-waydroid-install-apk"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-waydroid-image" "$ROOTFS/usr/bin/elvonos-waydroid-image"
sudo install -Dm644 "$REPO_ROOT/base/configuration/waydroid/images.json" \
    "$ROOTFS/usr/share/elvonos/waydroid/images.json"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-desktop" "$ROOTFS/usr/bin/elvonos-desktop"
sudo install -Dm644 "$REPO_ROOT/base/configuration/waydroid/Waydroid.desktop" "$ROOTFS/usr/share/applications/Waydroid.desktop"
sudo install -Dm644 "$REPO_ROOT/base/configuration/waydroid/APK-Installer.desktop" "$ROOTFS/usr/share/applications/APK-Installer.desktop"
sudo install -Dm644 "$REPO_ROOT/base/configuration/waydroid/waydroid-com.aurora.store.desktop" "$ROOTFS/home/elvon/.local/share/applications/waydroid-com.aurora.store.desktop"
sudo install -Dm644 "$REPO_ROOT/base/configuration/mimeapps.list" "$ROOTFS/home/elvon/.config/mimeapps.list"
sudo chroot "$ROOTFS" update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

# 4j. Wofi configuration
echo "==> Installing Wofi configuration..."
sudo mkdir -p "$ROOTFS/etc/wofi"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wofi/elvonos-menu.conf" "$ROOTFS/etc/wofi/elvonos-menu.conf"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wofi/elvonos-menu.css" "$ROOTFS/etc/wofi/elvonos-menu.css"

# 4k. Waybar configuration
echo "==> Installing Waybar configuration..."
sudo mkdir -p "$ROOTFS/etc/xdg/waybar"
sudo install -Dm644 "$REPO_ROOT/base/configuration/waybar/config" "$ROOTFS/etc/xdg/waybar/config"
sudo install -Dm644 "$REPO_ROOT/base/configuration/waybar/style.css" "$ROOTFS/etc/xdg/waybar/style.css"

# 4l. Environment.d
echo "==> Installing environment.d..."
sudo mkdir -p "$ROOTFS/etc/environment.d"
sudo install -Dm644 "$REPO_ROOT/base/configuration/environment.d/90-elvonos-qt.conf" "$ROOTFS/etc/environment.d/90-elvonos-qt.conf"

# 4m. Modprobe and modules-load
echo "==> Installing modprobe and modules-load..."
sudo mkdir -p "$ROOTFS/etc/modprobe.d" "$ROOTFS/etc/modules-load.d"
sudo install -Dm644 "$REPO_ROOT/base/configuration/modprobe.d/elvonos-binder.conf" "$ROOTFS/etc/modprobe.d/elvonos-binder.conf"
sudo install -Dm644 "$REPO_ROOT/base/configuration/modules-load.d/elvonos-binder.conf" "$ROOTFS/etc/modules-load.d/elvonos-binder.conf"

# 4n. Apt preferences and sources
echo "==> Installing apt preferences and sources..."
sudo mkdir -p "$ROOTFS/etc/apt/preferences.d" "$ROOTFS/etc/apt/sources.list.d"
sudo install -Dm644 "$REPO_ROOT/base/configuration/apt/preferences.d/elvonos.pref" "$ROOTFS/etc/apt/preferences.d/elvonos.pref"
for src in "$REPO_ROOT"/base/configuration/apt/sources.list.d/*; do
    [ -f "$src" ] && sudo install -Dm644 "$src" "$ROOTFS/etc/apt/sources.list.d/$(basename "$src")"
done

# 4o. Desktop shell binary
if [ -f "$REPO_ROOT/base/configuration/desktop-shell/build/elvonos-shell" ]; then
    echo "==> Installing desktop shell binary..."
    sudo install -Dm755 "$REPO_ROOT/base/configuration/desktop-shell/build/elvonos-shell" "$ROOTFS/usr/bin/elvonos-shell"
fi

# 4p. Desktop scripts
echo "==> Installing desktop scripts..."
for script in elvonos-status elvonos-menu elvonos-menu-toggle; do
    if [ -f "$REPO_ROOT/base/configuration/desktop/$script" ]; then
        sudo install -Dm755 "$REPO_ROOT/base/configuration/desktop/$script" "$ROOTFS/usr/bin/$script"
    fi
done

# 4q. Hyprland and Sway configs
echo "==> Installing Hyprland and Sway configs..."
sudo mkdir -p "$ROOTFS/etc/elvonos"
if [ -f "$REPO_ROOT/base/configuration/hypr/hyprland.conf" ]; then
    sudo install -Dm644 "$REPO_ROOT/base/configuration/hypr/hyprland.conf" "$ROOTFS/etc/elvonos/hyprland.conf"
fi
if [ -f "$REPO_ROOT/base/configuration/sway/config" ]; then
    sudo install -Dm644 "$REPO_ROOT/base/configuration/sway/config" "$ROOTFS/etc/elvonos/sway.conf"
fi

# 4r. elvonos-session-startup
if [ -f "$REPO_ROOT/base/configuration/session/elvonos-session-startup" ]; then
    echo "==> Installing session startup..."
    sudo install -Dm755 "$REPO_ROOT/base/configuration/session/elvonos-session-startup" "$ROOTFS/usr/bin/elvonos-session-startup"
fi

echo "=================================================="
echo "==> Installing SDDM theme (Win8Login)..."
if [ -d "$REPO_ROOT/Win8DE-0.9.0beta2/assets/SDDM/Win8Login" ]; then
    sudo mkdir -p "$ROOTFS/usr/share/sddm/themes"
    sudo cp -a "$REPO_ROOT/Win8DE-0.9.0beta2/assets/SDDM/Win8Login" "$ROOTFS/usr/share/sddm/themes/Win8Login"
fi

# 4s. Flathub and preinstalled Flatpak apps (Bazaar, Warehouse)
if [ -f "$SCRIPT_DIR/install-flatpak-apps.sh" ]; then
    echo "==> Installing Flathub apps..."
    bash "$SCRIPT_DIR/install-flatpak-apps.sh"
fi

# 4t. Desktop icons + bottom dock
if [ -f "$REPO_ROOT/build/desktop-extras/build-desktop-extras.sh" ]; then
    echo "==> Building desktop icons and dock..."
    bash "$REPO_ROOT/build/desktop-extras/build-desktop-extras.sh"
fi

# 4u. Explorer
if [ -f "$REPO_ROOT/build/explorer/build-explorer.sh" ]; then
    echo "==> Building Explorer..."
    bash "$REPO_ROOT/build/explorer/build-explorer.sh"
fi

# 4u2. Task Manager
if [ -f "$REPO_ROOT/build/taskmanager/build-taskmanager.sh" ]; then
    echo "==> Building Task Manager..."
    bash "$REPO_ROOT/build/taskmanager/build-taskmanager.sh"
fi

# 4u3. Gallery
if [ -f "$REPO_ROOT/build/gallery/build-gallery.sh" ]; then
    echo "==> Building Gallery..."
    bash "$REPO_ROOT/build/gallery/build-gallery.sh"
fi

# 4u4. Paint
if [ -f "$REPO_ROOT/build/paint/build-paint.sh" ]; then
    echo "==> Building Paint..."
    bash "$REPO_ROOT/build/paint/build-paint.sh"
fi

# 4u5. Defrag
if [ -f "$REPO_ROOT/build/defrag/build-defrag.sh" ]; then
    echo "==> Building Defrag..."
    bash "$REPO_ROOT/build/defrag/build-defrag.sh"
fi

# 4u6. Cleaner
if [ -f "$REPO_ROOT/build/cleaner/build-cleaner.sh" ]; then
    echo "==> Building Cleaner..."
    bash "$REPO_ROOT/build/cleaner/build-cleaner.sh"
fi

# 4u7. Control Center + performance/protection layer
if [ -f "$REPO_ROOT/build/control/build-control.sh" ]; then
    echo "==> Building Control Center..."
    bash "$REPO_ROOT/build/control/build-control.sh"
fi
echo "==> Installing performance/protection helper..."
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-tune" "$ROOTFS/usr/bin/elvonos-tune"
sudo install -Dm644 "$REPO_ROOT/base/configuration/systemd/elvonos-tune.service" \
    "$ROOTFS/etc/systemd/system/elvonos-tune.service"
sudo chroot "$ROOTFS" systemctl enable elvonos-tune.service >/dev/null 2>&1 || true

# 4u7b. Audio noise protection (PipeWire + WirePlumber + HDA power-save)
echo "==> Installing audio noise protection..."
sudo install -Dm644 "$REPO_ROOT/base/configuration/pipewire/99-elvonos-audio.conf" \
    "$ROOTFS/etc/pipewire/pipewire.conf.d/99-elvonos-audio.conf"
sudo install -Dm644 "$REPO_ROOT/base/configuration/pipewire/99-elvonos-noise.conf" \
    "$ROOTFS/etc/pipewire/pipewire.conf.d/99-elvonos-noise.conf"
sudo install -Dm644 "$REPO_ROOT/base/configuration/wireplumber/99-elvonos-audio.conf" \
    "$ROOTFS/etc/wireplumber/wireplumber.conf.d/99-elvonos-audio.conf"
sudo install -Dm644 "$REPO_ROOT/base/configuration/modprobe.d/elvonos-audio.conf" \
    "$ROOTFS/etc/modprobe.d/elvonos-audio.conf"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-audio-noise" \
    "$ROOTFS/usr/bin/elvonos-audio-noise"

# 4u7c. Notification daemon, idle defaults and display power helper
echo "==> Installing notification and power helpers..."
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-dpms" \
    "$ROOTFS/usr/bin/elvonos-dpms"
sudo install -Dm755 "$REPO_ROOT/base/configuration/scripts/elvonos-formfactor" \
    "$ROOTFS/usr/bin/elvonos-formfactor"
sudo install -Dm644 "$REPO_ROOT/base/configuration/fnott/fnott.ini" \
    "$ROOTFS/home/elvon/.config/fnott/fnott.ini"
sudo install -Dm644 "$REPO_ROOT/base/configuration/swayidle/config" \
    "$ROOTFS/home/elvon/.config/swayidle/config"
sudo chown -R 1000:1000 "$ROOTFS/home/elvon/.config/fnott" \
    "$ROOTFS/home/elvon/.config/swayidle"
sudo chroot "$ROOTFS" systemctl enable bluetooth.service >/dev/null 2>&1 || true

# 4u8. Store
if [ -f "$REPO_ROOT/build/store/build-store.sh" ]; then
    echo "==> Building Store..."
    bash "$REPO_ROOT/build/store/build-store.sh"
fi

# 4u8b. Notepad
if [ -f "$REPO_ROOT/build/notepad/build-notepad.sh" ]; then
    echo "==> Building Notepad..."
    bash "$REPO_ROOT/build/notepad/build-notepad.sh"
fi

# 4u8c. Media Player
if [ -f "$REPO_ROOT/build/media/build-media.sh" ]; then
    echo "==> Building Media Player..."
    bash "$REPO_ROOT/build/media/build-media.sh"
fi

# 4u8d. Calculator
if [ -f "$REPO_ROOT/build/calculator/build-calculator.sh" ]; then
    echo "==> Building Calculator..."
    bash "$REPO_ROOT/build/calculator/build-calculator.sh"
fi

# 4u8e. Screenshot tool
if [ -f "$REPO_ROOT/build/screenshot/build-screenshot.sh" ]; then
    echo "==> Building Screenshot tool..."
    bash "$REPO_ROOT/build/screenshot/build-screenshot.sh"
fi

# 4u8f. Archiver
if [ -f "$REPO_ROOT/build/archiver/build-archiver.sh" ]; then
    echo "==> Building Archiver..."
    bash "$REPO_ROOT/build/archiver/build-archiver.sh"
fi

# 4u8g. PDF Reader
if [ -f "$REPO_ROOT/build/pdf/build-pdf.sh" ]; then
    echo "==> Building PDF Reader..."
    bash "$REPO_ROOT/build/pdf/build-pdf.sh"
fi

# 4u8h. Print & Scan
if [ -f "$REPO_ROOT/build/printscan/build-printscan.sh" ]; then
    echo "==> Building Print & Scan..."
    bash "$REPO_ROOT/build/printscan/build-printscan.sh"
fi

# 4u8h2. Event Viewer
if [ -f "$REPO_ROOT/build/eventviewer/build-eventviewer.sh" ]; then
    echo "==> Building Event Viewer..."
    bash "$REPO_ROOT/build/eventviewer/build-eventviewer.sh"
fi

# 4u8h3. Taskbar settings
if [ -f "$REPO_ROOT/build/taskbar-settings/build-taskbar-settings.sh" ]; then
    echo "==> Building Taskbar Settings..."
    bash "$REPO_ROOT/build/taskbar-settings/build-taskbar-settings.sh"
fi

# 4u8h4. Settings
if [ -f "$REPO_ROOT/build/settings/build-settings.sh" ]; then
    echo "==> Building Settings..."
    bash "$REPO_ROOT/build/settings/build-settings.sh"
fi

# 4u8i. Package / AppImage installer
if [ -f "$REPO_ROOT/build/package-installer/build-package-installer.sh" ]; then
    echo "==> Building Package Installer..."
    bash "$REPO_ROOT/build/package-installer/build-package-installer.sh"
fi
sudo chroot "$ROOTFS" systemctl enable cups.socket >/dev/null 2>&1 || true

# 4u9. Boot splash bridge (Plymouth -> Win8DE hand-over)
if [ -f "$REPO_ROOT/build/splash/build-splash.sh" ]; then
    echo "==> Building boot splash bridge..."
    bash "$REPO_ROOT/build/splash/build-splash.sh"
fi

# 4u9. Desktop shortcuts for every ElvonOS application, sorted into groups.
# Explorer, Store, Screenshot and Media Player live in the dock only; all
# remaining applications are grouped in folders so the desktop has room for
# the user's own files and applications.
echo "==> Installing grouped desktop shortcuts..."
DESKTOP_DIR="$ROOTFS/home/elvon/Desktop"
sudo mkdir -p "$DESKTOP_DIR"
for app in explorer store screenshot media taskmanager gallery paint notepad \
           calculator archiver pdf printscan eventviewer defrag cleaner control; do
    sudo rm -f "$DESKTOP_DIR/elvonos-$app.desktop"
done
sudo rm -f "$ROOTFS/home/elvon/.config/elvonos/dock.json"

install_group_shortcut() {
    local app="$1"
    local group="$2"
    local desktop="$ROOTFS/usr/share/applications/elvonos-$app.desktop"
    [ -f "$desktop" ] || return 0
    if grep -q '^NoDisplay=true' "$desktop"; then
        return 0
    fi
    sudo install -Dm644 "$desktop" "$DESKTOP_DIR/$group/elvonos-$app.desktop"
}

for app in taskmanager control eventviewer; do
    install_group_shortcut "$app" "System"
done
for app in defrag cleaner printscan; do
    install_group_shortcut "$app" "Maintenance"
done
for app in notepad pdf archiver; do
    install_group_shortcut "$app" "Office"
done
for app in gallery paint; do
    install_group_shortcut "$app" "Media & Graphics"
done
install_group_shortcut calculator "Utilities"

# The user must be able to add files and new shortcuts to the group folders.
sudo chown -R 1000:1000 "$DESKTOP_DIR"

# 4u9b. AppImage MIME type and package handlers
echo "==> Installing AppImage MIME type..."
sudo install -Dm644 "$REPO_ROOT/base/configuration/mime/elvonos-appimage.xml" \
    "$ROOTFS/usr/share/mime/packages/elvonos-appimage.xml"
sudo chroot "$ROOTFS" update-mime-database /usr/share/mime >/dev/null 2>&1 || true

# 4v. Waydroid shared storage (user bindfs mount, started from labwc)
sudo install -Dm755 "$REPO_ROOT/base/configuration/waydroid/waydroid-storage-mount.sh" "$ROOTFS/usr/bin/elvonos-waydroid-storage"
sudo rm -f "$ROOTFS/etc/systemd/system/elvonos-waydroid-storage.service"
sudo chroot "$ROOTFS" systemctl disable elvonos-waydroid-storage.service >/dev/null 2>&1 || true

# 4w. The live user owns their home directory; root-owned ~/.local breaks
# Waydroid sessions and other first-run services.
sudo chown -R 1000:1000 "$ROOTFS/home/elvon"

echo " Labwc desktop with Win8DE shell installed successfully!"
echo "=================================================="
