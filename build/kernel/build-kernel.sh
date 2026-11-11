#!/usr/bin/env bash
# ElvonOS custom kernel build
#
# Builds a Debian 6.12 kernel from linux-source with an ElvonOS config and
# installs it into the target rootfs.  Only a few options differ from the
# Debian config:
#
#   * CONFIG_LOCALVERSION="-elvonos"  (uname -r reports the ElvonOS kernel)
#   * debug info/BTF disabled          (much faster build, smaller modules)
#
# Everything else (binder, virtio-gpu with virgl, zram, amdgpu, iwlwifi, …)
# stays exactly as Debian ships it so Waydroid, the desktop and the drivers
# keep working.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="${1:-$REPO_ROOT/build/out/rootfs}"
CONFIG_SOURCE="${2:-$ROOTFS/boot/config-$(ls "$ROOTFS"/boot/config-* | head -n1 | sed 's|.*/config-||')}"
JOBS="${JOBS:-$(nproc)}"
WORK="$REPO_ROOT/build/kernel"
SOURCE_TARBALL="${SOURCE_TARBALL:-/usr/src/linux-source-6.12.tar.xz}"
TREE="$WORK/linux-source-6.12"

echo "=================================================="
echo " ElvonOS custom kernel build"
echo " Rootfs:  $ROOTFS"
echo " Config:  $CONFIG_SOURCE"
echo " Jobs:    $JOBS"
echo "=================================================="

if [ ! -f "$SOURCE_TARBALL" ]; then
    echo "Kernel source tarball not found: $SOURCE_TARBALL" >&2
    echo "Install it with: sudo apt-get install linux-source-6.12" >&2
    exit 1
fi

mkdir -p "$WORK"

if [ ! -d "$TREE" ]; then
    echo "==> Extracting $SOURCE_TARBALL ..."
    tar -C "$WORK" -xf "$SOURCE_TARBALL"
fi

if [ -z "$(ls -A "$TREE" 2>/dev/null)" ]; then
    echo "Kernel source tree is empty: $TREE" >&2
    exit 1
fi

cd "$TREE"

echo "==> Applying ElvonOS configuration ..."
cp -f "$CONFIG_SOURCE" .config
scripts/config --file .config \
    --set-str LOCALVERSION "-elvonos" \
    --disable DEBUG_INFO \
    --enable DEBUG_INFO_NONE \
    --disable DEBUG_INFO_BTF \
    --disable DEBUG_INFO_DWARF5 \
    --disable GDB_SCRIPTS

if grep -q '^CONFIG_MODULE_SIG=y' .config; then
    # Debian signs modules with a key generated at build time.  Keep the
    # behaviour, but pin the key location so the build is reproducible.
    scripts/config --file .config --set-str MODULE_SIG_KEY "certs/signing_key.pem"
fi

make olddefconfig >/dev/null

VERSION="$(make -s kernelrelease)"
echo "==> Building kernel $VERSION ..."
make -j"$JOBS" bzImage modules

echo "==> Installing modules into $ROOTFS/lib/modules/$VERSION ..."
sudo make INSTALL_MOD_PATH="$ROOTFS" modules_install

echo "==> Installing kernel image and metadata ..."
sudo install -Dm644 arch/x86/boot/bzImage "$ROOTFS/boot/vmlinuz-$VERSION"
sudo install -Dm644 System.map "$ROOTFS/boot/System.map-$VERSION"
sudo install -Dm644 .config "$ROOTFS/boot/config-$VERSION"

echo "==> Generating initramfs ..."
MOUNTS=()
for fs in proc sys dev; do
    if ! mountpoint -q "$ROOTFS/$fs"; then
        if sudo mount --bind "/$fs" "$ROOTFS/$fs" 2>/dev/null; then
            MOUNTS+=("$ROOTFS/$fs")
        fi
    fi
done
cleanup_mounts() {
    for mount_point in "${MOUNTS[@]:-}"; do
        [ -n "$mount_point" ] && sudo umount "$mount_point" 2>/dev/null || true
    done
}
trap cleanup_mounts EXIT
sudo chroot "$ROOTFS" /usr/sbin/mkinitramfs -o "/boot/initrd.img-$VERSION" "$VERSION"
cleanup_mounts
trap - EXIT

echo "==> Removing the previous kernel from the rootfs ..."
for old in "$ROOTFS"/boot/vmlinuz-* "$ROOTFS"/boot/initrd.img-* "$ROOTFS"/boot/System.map-* "$ROOTFS"/boot/config-*; do
    [ -e "$old" ] || continue
    case "$old" in
        *"$VERSION"*) continue ;;
    esac
    sudo rm -f "$old"
done
for module_dir in "$ROOTFS"/lib/modules/*; do
    [ -d "$module_dir" ] || continue
    case "$module_dir" in
        *"$VERSION"*) continue ;;
    esac
    sudo rm -rf "$module_dir"
done

sudo depmod -a -b "$ROOTFS" "$VERSION" 2>/dev/null || true

echo "==> Done: $VERSION"
ls -lh "$ROOTFS/boot/vmlinuz-$VERSION" "$ROOTFS/boot/initrd.img-$VERSION"
