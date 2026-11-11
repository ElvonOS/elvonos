#!/usr/bin/env bash
# ElvonOS V1 — Phase 1: Build Debian 13 Foundation Rootfs
# Assembles minimal Debian Trixie rootfs with kernel, firmware, audio, graphics, network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$REPO_ROOT/build/out/rootfs"
LOCK_FILE="$REPO_ROOT/build/out/packages.lock"
SUITE="trixie"
MIRROR="https://deb.debian.org/debian"

PROFILE="phase1"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --out)
            OUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
        echo "Error: Root privileges required to build rootfs."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

echo "=================================================="
echo " ElvonOS V1 — Building Rootfs (Profile: $PROFILE)"
echo " Suite: $SUITE | Mirror: $MIRROR"
echo " Destination: $OUT_DIR"
echo "=================================================="

# Collect packages from required lists
LISTS=("base.list" "firmware.list" "graphics.list" "audio.list" "network.list" "security.list")
ALL_PACKAGES=()

for list_name in "${LISTS[@]}"; do
    list_path="$REPO_ROOT/base/packages/$list_name"
    if [[ -f "$list_path" ]]; then
        echo "==> Reading $list_name..."
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [[ -n "$line" ]]; then
                ALL_PACKAGES+=("$line")
            fi
        done < "$list_path"
    else
        echo "Warning: List not found: $list_path"
    fi
done

# Deduplicate package list
UNIQUE_PACKAGES=($(echo "${ALL_PACKAGES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
PACKAGE_STRING=$(IFS=, ; echo "${UNIQUE_PACKAGES[*]}")

echo "==> Total unique packages for $PROFILE: ${#UNIQUE_PACKAGES[@]}"

mkdir -p "$REPO_ROOT/build/out"
if [[ -d "$OUT_DIR" ]]; then
    echo "==> Cleaning previous rootfs at $OUT_DIR..."
    $SUDO rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

if command -v mmdebstrap >/dev/null 2>&1; then
    echo "==> Using mmdebstrap..."
    $SUDO mmdebstrap \
        --components="main,contrib,non-free-firmware" \
        --include="$PACKAGE_STRING" \
        --variant=minbase \
        "$SUITE" \
        "$OUT_DIR" \
        "$MIRROR"
elif command -v debootstrap >/dev/null 2>&1; then
    echo "==> mmdebstrap not found, using debootstrap..."
    $SUDO debootstrap \
        --components=main,contrib,non-free-firmware \
        --include="$(IFS=, ; echo "${UNIQUE_PACKAGES[*]}")" \
        --arch=amd64 \
        "$SUITE" \
        "$OUT_DIR" \
        "$MIRROR"
else
    echo "Error: Neither mmdebstrap nor debootstrap is installed. Run install-build-deps.sh."
    exit 1
fi

echo "==> Applying ElvonOS configuration templates..."

# 1. Binder configuration
$SUDO mkdir -p "$OUT_DIR/etc/modprobe.d" "$OUT_DIR/etc/modules-load.d"
$SUDO cp -f "$REPO_ROOT/base/configuration/modprobe.d/elvonos-binder.conf" "$OUT_DIR/etc/modprobe.d/"
$SUDO cp -f "$REPO_ROOT/base/configuration/modules-load.d/elvonos-binder.conf" "$OUT_DIR/etc/modules-load.d/"
# Waydroid/Flatpak use loop-mounted images; the installed system must create
# /dev/loop-control and /dev/loop* even though squashfs/live-boot already
# loaded the module on the live medium.
$SUDO cp -f "$REPO_ROOT/base/configuration/modules-load.d/elvonos-loop.conf" "$OUT_DIR/etc/modules-load.d/"

# 1b. Boot parameters shared by the live ISO and installed systems.
#     Waydroid's Android images expect the same LSM setup as the live boot.
if [ -f "$OUT_DIR/etc/default/grub" ]; then
    $SUDO sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet security=selinux apparmor=0"/' \
        "$OUT_DIR/etc/default/grub"
else
    $SUDO mkdir -p "$OUT_DIR/etc/default"
    printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet security=selinux apparmor=0"\n' | \
        $SUDO tee "$OUT_DIR/etc/default/grub" >/dev/null
fi

# 2. APT configuration
$SUDO mkdir -p "$OUT_DIR/etc/apt/sources.list.d" "$OUT_DIR/etc/apt/preferences.d"
$SUDO cp -f "$REPO_ROOT/base/configuration/apt/sources.list.d/debian.sources" "$OUT_DIR/etc/apt/sources.list.d/"
$SUDO cp -f "$REPO_ROOT/base/configuration/apt/preferences.d/elvonos.pref" "$OUT_DIR/etc/apt/preferences.d/"

# 3. Hostname and network defaults
echo "elvonos" | $SUDO tee "$OUT_DIR/etc/hostname" >/dev/null
cat << 'EOF' | $SUDO tee "$OUT_DIR/etc/hosts" >/dev/null
127.0.0.1   localhost
127.0.1.1   elvonos
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# 4. OS identification
if [[ -f "$OUT_DIR/etc/os-release" ]]; then
    $SUDO sed -i 's/^NAME=.*/NAME="ElvonOS"/' "$OUT_DIR/etc/os-release"
    $SUDO sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="ElvonOS V1 (Debian 13 Trixie)"/' "$OUT_DIR/etc/os-release"
fi

# 5. Generate package lock file
echo "==> Generating packages.lock..."
$SUDO chroot "$OUT_DIR" dpkg-query -W -f='${Package}=${Version}\n' > "$LOCK_FILE"
echo "==> Package lock written to $LOCK_FILE (${#UNIQUE_PACKAGES[@]} top-level requested, $(wc -l < "$LOCK_FILE") installed total)."

echo "=================================================="
echo " ElvonOS Phase 1 Rootfs built successfully at:"
echo " $OUT_DIR"
echo "=================================================="
