#!/bin/bash
# Waydroid crash recovery script
set -euo pipefail

LOG_DIR="/var/log/elvonos/crash"
mkdir -p "$LOG_DIR"

log_crash() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/waydroid-crash.log"
}

# Check if waydroid container is running
if ! systemctl is-active --quiet waydroid-container.service; then
    log_crash "Waydroid container not active, attempting restart..."
    # Clean up stale state
    pkill -f waydroid-net.sh 2>/dev/null || true
    rm -f /run/waydroid/* 2>/dev/null || true
    # Restart container
    if systemctl restart waydroid-container.service; then
        log_crash "Container restarted successfully"
    else
        log_crash "Container restart failed"
        exit 1
    fi
fi

# Check if waydroid session is running
if ! pgrep -f "waydroid session" >/dev/null; then
    log_crash "Waydroid session not running, attempting restart..."
    # Restart session as elvon user
    sudo -u elvon bash -c 'waydroid session start &' 2>/dev/null || true
    sleep 3
    if pgrep -f "waydroid session" >/dev/null; then
        log_crash "Session restarted successfully"
    else
        log_crash "Session restart failed"
    fi
fi

echo "Waydroid health check complete"