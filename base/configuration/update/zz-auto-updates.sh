#!/bin/bash
# Enable automatic ElvonOS updates after the software payload is installed.
set -euo pipefail

systemctl daemon-reload

mkdir -p /etc/elvonos
: > /etc/elvonos/auto-apply.enabled
CONF=/etc/elvonos/update.conf
if ! grep -q '^AUTO_APPLY=' "$CONF" 2>/dev/null; then
    printf 'AUTO_APPLY=shutdown\n' >> "$CONF"
fi

systemctl enable elvonos-update-boot.service >/dev/null 2>&1 || true
systemctl enable elvonos-update-shutdown.service >/dev/null 2>&1 || true
systemctl enable --now elvonos-update-check.timer >/dev/null 2>&1 || true

echo "automatic updates enabled (daily staging, install on shutdown/next boot)"
