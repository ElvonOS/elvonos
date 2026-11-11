#!/bin/bash
# Enable automatic ElvonOS updates after the software payload is installed.
set -euo pipefail

systemctl daemon-reload

if command -v elvonos-update-policy >/dev/null 2>&1; then
    elvonos-update-policy on >/dev/null
fi

systemctl enable elvonos-update-shutdown.service >/dev/null 2>&1 || true
systemctl enable --now elvonos-update-check.timer >/dev/null 2>&1 || true

echo "automatic updates enabled (daily check, install on shutdown)"
