#!/usr/bin/env bash
# ElvonOS V1 — Phase 1: Static Tests
# Verifies repository manifests, configurations, and prerequisites without root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
ERRORS=0

pass() { echo -e "  [${GREEN}PASS${NC}] $1"; }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; ERRORS=$((ERRORS + 1)); }

echo "==> Running ElvonOS Phase 1 Static Tests..."

# 1. Package lists existence
for list in base firmware graphics audio network security desktop waydroid installer build-host hyprland-build waydroid-build; do
    file="$REPO_ROOT/base/packages/$list.list"
    if [[ -f "$file" ]]; then
        count=$(grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' | wc -l)
        pass "List present: $list.list ($count packages)"
    else
        fail "List missing: $list.list"
    fi
done

# 2. Target configuration files
for conf in \
    base/configuration/modprobe.d/elvonos-binder.conf \
    base/configuration/modules-load.d/elvonos-binder.conf \
    base/configuration/apt/sources.list.d/debian.sources \
    base/configuration/apt/preferences.d/elvonos.pref \
    base/configuration/wayland-sessions/elvonos.desktop \
    base/configuration/environment.d/90-elvonos-qt.conf \
    base/configuration/waydroid/elvonos-waydroid.properties; do
    if [[ -f "$REPO_ROOT/$conf" ]]; then
        pass "Config present: $conf"
    else
        fail "Config missing: $conf"
    fi
done

# 3. Android image artifacts
if [[ -f "$REPO_ROOT/Android/Waydroid-images/system.img" && -f "$REPO_ROOT/Android/Waydroid-images/vendor.img" ]]; then
    pass "Android 13 images present in Android/Waydroid-images/"
else
    fail "Android images missing in Android/Waydroid-images/"
fi

# 4. Phase 1 scripts
for script in check-host.sh install-build-deps.sh build-rootfs.sh validate-rootfs.sh; do
    if [[ -x "$REPO_ROOT/build/phase1/$script" ]]; then
        pass "Script executable: build/phase1/$script"
    else
        fail "Script missing or not executable: build/phase1/$script"
    fi
done

echo ""
if (( ERRORS > 0 )); then
    echo -e "${RED}Static tests FAILED with $ERRORS error(s).${NC}"
    exit 1
else
    echo -e "${GREEN}All Phase 1 Static Tests PASSED.${NC}"
    exit 0
fi
