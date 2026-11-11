#!/bin/bash
# ElvonOS Waydroid Clipboard Bridge
# Syncs clipboard between host Wayland and Android container
set -euo pipefail

# Host → Android
host_to_android() {
    if command -v wl-paste >/dev/null 2>&1 && command -v waydroid >/dev/null 2>&1; then
        local clip
        clip=$(wl-paste 2>/dev/null || true)
        if [ -n "$clip" ]; then
            waydroid shell "am broadcast -a clipper.set -e text '$clip'" 2>/dev/null || true
        fi
    fi
}

# Android → Host
android_to_host() {
    if command -v waydroid >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
        local clip
        clip=$(waydroid shell "service call clipboard 2 2>/dev/null" 2>/dev/null || true)
        if [ -n "$clip" ]; then
            echo "$clip" | wl-copy 2>/dev/null || true
        fi
    fi
}

# Main loop
while true; do
    host_to_android
    android_to_host
    sleep 2
done