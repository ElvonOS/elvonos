#!/bin/bash
# Expose Waydroid's shared storage to the desktop user via bindfs.
# Runs as a normal user from the labwc autostart; never blocks the boot.
# The Android data directory is owned by root, so the check and the mount use
# passwordless sudo.
set -u
DST=/run/elvonos/waydroid

USER_NAME=${ELVONOS_USER:-}
if [ -z "$USER_NAME" ] && [ -d /run/user/1000 ]; then
    USER_NAME=$(stat -c %U /run/user/1000 2>/dev/null || true)
fi
[ -n "$USER_NAME" ] || USER_NAME=elvon
USER_HOME=$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6)
[ -n "$USER_HOME" ] || USER_HOME=/home/$USER_NAME

exists() { [ -d "$1" ] || sudo -n test -d "$1" 2>/dev/null; }

SRC=""
for _ in $(seq 1 30); do
    for candidate in "$USER_HOME/.local/share/waydroid/data/media/0" \
                     "/var/lib/waydroid/data/media/0"; do
        if exists "$candidate"; then
            SRC="$candidate"
            break 2
        fi
    done
    sleep 1
done
[ -n "$SRC" ] || exit 0

sudo -n mkdir -p "$DST" 2>/dev/null || mkdir -p "$DST" 2>/dev/null || exit 0
mountpoint -q "$DST" && exit 0

if command -v bindfs >/dev/null 2>&1; then
    sudo -n bindfs -u "$USER_NAME" -g "$USER_NAME" -p 0755 "$SRC" "$DST" 2>/dev/null \
        || bindfs -u "$USER_NAME" -g "$USER_NAME" -p 0755 "$SRC" "$DST" 2>/dev/null \
        || true
else
    sudo -n mount --bind "$SRC" "$DST" 2>/dev/null || true
fi
