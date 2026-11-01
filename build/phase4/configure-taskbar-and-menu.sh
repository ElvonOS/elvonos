#!/usr/bin/env bash
# ElvonOS V1 — Configure Bottom Taskbar, Start Menu, and App Launcher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="$REPO_ROOT/build/out/rootfs"

echo "=================================================="
echo " ElvonOS V1 — Setting up Taskbar & Start Menu"
echo "=================================================="

# 1. Configure Waybar (Bottom Taskbar with Start Menu button & Window List)
echo "==> Configuring Waybar taskbar..."
sudo mkdir -p "$ROOTFS/etc/xdg/waybar"

cat << 'EOF' | sudo tee "$ROOTFS/etc/xdg/waybar/config.jsonc" >/dev/null
{
    "layer": "top",
    "position": "bottom",
    "height": 44,
    "modules-left": ["custom/start", "custom/term", "custom/files", "custom/android", "wlr/taskbar"],
    "modules-center": ["sway/workspaces"],
    "modules-right": ["pulseaudio", "network", "clock", "custom/power"],

    "custom/start": {
        "format": " 🚀 Start ",
        "tooltip-format": "ElvonOS Startmenü",
        "on-click": "wofi --show drun --prompt 'Apps suchen...' --width 480 --height 580"
    },
    "custom/term": {
        "format": "  ",
        "tooltip-format": "Terminal",
        "on-click": "foot"
    },
    "custom/files": {
        "format": " 📁 ",
        "tooltip-format": "Dateimanager",
        "on-click": "thunar"
    },
    "custom/android": {
        "format": " 🤖 ",
        "tooltip-format": "Android Apps (Waydroid)",
        "on-click": "waydroid show-full-ui"
    },
    "wlr/taskbar": {
        "format": "{icon} {title}",
        "icon-size": 22,
        "icon-theme": "Papirus-Dark",
        "tooltip-format": "{title}",
        "on-click": "activate",
        "on-click-middle": "close",
        "max-length": 30
    },
    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "🔇",
        "format-icons": {
            "default": ["🔈", "🔉", "🔊"]
        },
        "on-click": "pavucontrol"
    },
    "network": {
        "format-wifi": " {essid}",
        "format-ethernet": "󰈀 LAN",
        "format-disconnected": "󰖪 Offline",
        "tooltip-format": "{ifname}: {ipaddr}"
    },
    "clock": {
        "format": " {:%H:%M  📅 %d.%m.%Y}",
        "tooltip-format": "{:%A, %d. %B %Y}"
    },
    "custom/power": {
        "format": " ⏻ ",
        "tooltip-format": "Ausschalten",
        "on-click": "swaynag -t warning -m 'System beenden?' -b 'Herunterfahren' 'systemctl poweroff' -b 'Neustart' 'systemctl reboot'"
    }
}
EOF

cat << 'EOF' | sudo tee "$ROOTFS/etc/xdg/waybar/style.css" >/dev/null
* {
    border: none;
    border-radius: 0;
    font-family: "Noto Sans", sans-serif;
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background-color: rgba(24, 25, 38, 0.95);
    border-top: 2px solid #363a4f;
    color: #cad3f5;
}

#custom-start {
    background: linear-gradient(135deg, #8aadf4, #b7bdf8);
    color: #181926;
    font-weight: bold;
    padding: 0 14px;
    margin: 4px 6px;
    border-radius: 8px;
    font-size: 15px;
}

#custom-start:hover {
    background: linear-gradient(135deg, #b7bdf8, #c6a0f6);
}

#custom-term, #custom-files, #custom-android {
    background-color: #24273a;
    color: #8aadf4;
    padding: 0 12px;
    margin: 4px 3px;
    border-radius: 6px;
    font-size: 16px;
}

#custom-term:hover, #custom-files:hover, #custom-android:hover {
    background-color: #363a4f;
    color: #a6da95;
}

#taskbar button {
    background-color: #24273a;
    color: #cad3f5;
    padding: 0 12px;
    margin: 4px 4px;
    border-radius: 6px;
    border-bottom: 2px solid transparent;
}

#taskbar button.active {
    background-color: #363a4f;
    border-bottom: 2px solid #8aadf4;
    color: #ffffff;
}

#taskbar button:hover {
    background-color: #494d64;
}

#workspaces button {
    padding: 0 10px;
    background-color: transparent;
    color: #8087a2;
    margin: 4px 2px;
    border-radius: 6px;
}

#workspaces button.focused {
    background-color: #8aadf4;
    color: #181926;
    font-weight: bold;
}

#pulseaudio, #network, #clock, #custom-power {
    padding: 0 12px;
    margin: 4px 4px;
    background-color: #24273a;
    border-radius: 6px;
    color: #cad3f5;
}

#custom-power {
    background-color: #ed8796;
    color: #181926;
    font-weight: bold;
}

#custom-power:hover {
    background-color: #ee99a0;
}
EOF

# 2. Configure Wofi Start Menu Style
echo "==> Configuring Wofi Start Menu theme..."
sudo mkdir -p "$ROOTFS/etc/wofi"

cat << 'EOF' | sudo tee "$ROOTFS/etc/wofi/style.css" >/dev/null
window {
    margin: 0px;
    border: 2px solid #8aadf4;
    border-radius: 12px;
    background-color: rgba(24, 25, 38, 0.98);
    font-family: "Noto Sans", sans-serif;
    font-size: 14px;
}

#input {
    margin: 12px;
    padding: 10px;
    border-radius: 8px;
    border: 1px solid #494d64;
    background-color: #1e2030;
    color: #cad3f5;
}

#inner-box {
    margin: 8px;
}

#outer-box {
    margin: 8px;
}

#entry {
    padding: 8px 12px;
    margin: 2px;
    border-radius: 6px;
    color: #cad3f5;
}

#entry:selected {
    background-color: #8aadf4;
    color: #181926;
    font-weight: bold;
}
EOF

cat << 'EOF' | sudo tee "$ROOTFS/etc/wofi/config" >/dev/null
width=480
height=580
prompt=Apps suchen...
show=drun
allow_images=true
image_size=32
insensitive=true
EOF

# 3. Configure Sway for Clean Desktop (Wallpaper + Bottom Taskbar)
echo "==> Updating Sway configuration..."
cat << 'EOF' | sudo tee "$ROOTFS/etc/elvonos/sway.conf" >/dev/null
# ElvonOS V1 — Sway Desktop Configuration
set $mod Mod4

# Appearance & Background
output * bg #1e2030 solid_color
font pango:Noto Sans 11
default_border pixel 2
default_floating_border pixel 2
gaps inner 6
gaps outer 10

# Input configuration
input type:touchpad {
    dwt enabled
    tap enabled
    natural_scroll enabled
}

input type:keyboard {
    xkb_layout "de,us"
}

# Window Rules
for_window [app_id="Waydroid"] floating enable, border normal 2
for_window [class="Waydroid"] floating enable, border normal 2
for_window [app_id="wofi"] floating enable, border none
for_window [app_id="pavucontrol"] floating enable
for_window [app_id="thunar"] floating enable

# Bottom Taskbar
bar {
    swaybar_command waybar
}

# Keybindings
bindsym $mod+Return exec foot
bindsym $mod+d exec wofi
bindsym $mod+q kill
bindsym $mod+f fullscreen toggle
bindsym $mod+space floating toggle

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

# Autostart ElvonOS background session
exec /usr/bin/elvonos-session-startup
EOF

sudo cp -f "$ROOTFS/etc/elvonos/sway.conf" "$REPO_ROOT/base/configuration/sway/config"

# 4. Sync configs to /etc/skel and /home/elvon
sudo mkdir -p "$ROOTFS/home/elvon/.config/waybar" "$ROOTFS/home/elvon/.config/wofi" "$ROOTFS/home/elvon/.config/sway"
sudo cp -rf "$ROOTFS/etc/xdg/waybar/"* "$ROOTFS/home/elvon/.config/waybar/"
sudo cp -rf "$ROOTFS/etc/wofi/"* "$ROOTFS/home/elvon/.config/wofi/"
sudo cp -f "$ROOTFS/etc/elvonos/sway.conf" "$ROOTFS/home/elvon/.config/sway/config"
sudo chown -R 1000:1000 "$ROOTFS/home/elvon/.config"

echo "=================================================="
echo " Taskbar & Start Menu setup complete!"
echo "=================================================="
