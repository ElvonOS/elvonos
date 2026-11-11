#!/usr/bin/env bash
# ElvonOS V1 — Build Win8DE (Labwc shell) reproducibly
#
# Clones the pinned upstream Win8DE revision, applies the ElvonOS shell fixes
# (see patches/), builds with upstream build.sh and installs the binaries into
# build/win8de/bin. Pass --install-rootfs to also copy them into the current
# rootfs (only do this while no ISO/squashfs build is running).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="${WIN8DE_WORK_DIR:-/tmp/Win8DE}"
BIN_DIR="$SCRIPT_DIR/bin"
ROOTFS="$REPO_ROOT/build/out/rootfs"

UPSTREAM_URL="https://github.com/er-bharat/Win8DE.git"
UPSTREAM_COMMIT="cc5594526cf6fd2e5957f44afaf4268e425acd45"
PATCH="$SCRIPT_DIR/patches/0001-elvonos-labwc-shell-fixes.patch"
PATCH2="$SCRIPT_DIR/patches/0002-battery-spacing.patch"
PATCH3="$SCRIPT_DIR/patches/0003-win8running-hide.patch"
PATCH4="$SCRIPT_DIR/patches/0004-start-switcher-sync.patch"
PATCH5="$SCRIPT_DIR/patches/0005-reset-launching-tiles.patch"
PATCH6="$SCRIPT_DIR/patches/0006-apps-screen-refresh.patch"
PATCH7="$SCRIPT_DIR/patches/0007-flatpak-icons.patch"
PATCH8="$SCRIPT_DIR/patches/0008-modern-taskbar.patch"
PATCH9="$SCRIPT_DIR/patches/0009-modern-desktop.patch"
PATCH10="$SCRIPT_DIR/patches/0010-start-widgets.patch"
PATCH11="$SCRIPT_DIR/patches/0011-aero-glass.patch"
PATCH12="$SCRIPT_DIR/patches/0012-live-tiles-always.patch"
PATCH13="$SCRIPT_DIR/patches/0013-frosted-glass.patch"
PATCH14="$SCRIPT_DIR/patches/0014-win8running-watch-windows-ini.patch"
PATCH15="$SCRIPT_DIR/patches/0015-taskbar-tray-context-menu-grouping.patch"
PATCH16="$SCRIPT_DIR/patches/0016-panel-position-and-start-logo.patch"
PATCH17="$SCRIPT_DIR/patches/0017-start-button-persist.patch"
PATCH18="$SCRIPT_DIR/patches/0018-elvonos-power-buttons-and-lock.patch"
PATCH19="$SCRIPT_DIR/patches/0019-start-tile-labels-and-battery.patch"
PATCH20="$SCRIPT_DIR/patches/0020-elvonos-ui-fixes.patch"

INSTALL_ROOTFS=0
for arg in "$@"; do
    case "$arg" in
        --install-rootfs) INSTALL_ROOTFS=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

SUDO=""
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then SUDO="sudo"; fi
fi

echo "==> Preparing Win8DE source in $WORK_DIR"
if [[ ! -d "$WORK_DIR/.git" ]]; then
    rm -rf "$WORK_DIR"
    git clone "$UPSTREAM_URL" "$WORK_DIR"
fi

cd "$WORK_DIR"
git fetch origin
git checkout -f "$UPSTREAM_COMMIT"
git clean -fdq

echo "==> Applying ElvonOS patches"
git apply --check "$PATCH"
git apply "$PATCH"
if [[ -f "$PATCH2" ]]; then
    git apply --check "$PATCH2"
    git apply "$PATCH2"
fi
if [[ -f "$PATCH3" ]]; then
    git apply --check "$PATCH3"
    git apply "$PATCH3"
fi
if [[ -f "$PATCH4" ]]; then
    git apply --check "$PATCH4"
    git apply "$PATCH4"
fi
if [[ -f "$PATCH5" ]]; then
    git apply --check "$PATCH5"
    git apply "$PATCH5"
fi
if [[ -f "$PATCH6" ]]; then
    git apply --check "$PATCH6"
    git apply "$PATCH6"
fi
if [[ -f "$PATCH7" ]]; then
    git apply --check "$PATCH7"
    git apply "$PATCH7"
fi
if [[ -f "$PATCH8" ]]; then
    git apply --check "$PATCH8"
    git apply "$PATCH8"
fi
if [[ -f "$PATCH9" ]]; then
    git apply --check "$PATCH9"
    git apply "$PATCH9"
fi
if [[ -f "$PATCH10" ]]; then
    git apply --check "$PATCH10"
    git apply "$PATCH10"
fi
if [[ -f "$PATCH11" ]]; then
    git apply --check "$PATCH11"
    git apply "$PATCH11"
fi
if [[ -f "$PATCH12" ]]; then
    git apply --check "$PATCH12"
    git apply "$PATCH12"
fi
if [[ -f "$PATCH13" ]]; then
    git apply --check "$PATCH13"
    git apply "$PATCH13"
fi
if [[ -f "$PATCH14" ]]; then
    git apply --check "$PATCH14"
    git apply "$PATCH14"
fi
if [[ -f "$PATCH15" ]]; then
    git apply --check "$PATCH15"
    git apply "$PATCH15"
fi
if [[ -f "$PATCH16" ]]; then
    git apply --check "$PATCH16"
    git apply "$PATCH16"
fi
if [[ -f "$PATCH17" ]]; then
    git apply --check "$PATCH17"
    git apply "$PATCH17"
fi
if [[ -f "$PATCH18" ]]; then
    git apply --check "$PATCH18"
    git apply "$PATCH18"
fi
if [[ -f "$PATCH19" ]]; then
    git apply --check "$PATCH19"
    git apply "$PATCH19"
fi
if [[ -f "$PATCH20" ]]; then
    git apply --check "$PATCH20"
    git apply "$PATCH20"
fi

echo "==> Building Win8DE"
./build.sh

echo "==> Installing binaries into $BIN_DIR"
mkdir -p "$BIN_DIR"
find "$WORK_DIR/build/bin" -maxdepth 1 -type f -executable -exec cp -f {} "$BIN_DIR/" \;

if [[ "$INSTALL_ROOTFS" == "1" ]]; then
    if [[ ! -d "$ROOTFS/usr/bin" ]]; then
        echo "Error: rootfs not found at $ROOTFS" >&2
        exit 1
    fi
    echo "==> Installing binaries into rootfs"
    for target in "$ROOTFS/usr/local/bin" "$ROOTFS/usr/bin"; do
        $SUDO mkdir -p "$target"
        for bin in "$BIN_DIR"/*; do
            $SUDO cp -f "$bin" "$target/$(basename "$bin")"
            $SUDO chown root:root "$target/$(basename "$bin")"
            $SUDO chmod 755 "$target/$(basename "$bin")"
        done
    done
fi

echo "==> Done. Binaries:"
ls -l "$BIN_DIR"
