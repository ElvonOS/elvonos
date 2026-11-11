#!/usr/bin/env bash
# ElvonOS V1 — Phase 7: Build Live Bootable ISO
# Assembles SquashFS, EFI/BIOS bootloader, bundled Waydroid images, and hybrid ISO image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="${1:-$REPO_ROOT/build/out/rootfs}"
VERSION="${ELVONOS_VERSION:-1.0.0}"
APPS_VERSION="${ELVONOS_APPS_VERSION:-$VERSION}"
ISO_STAGING="$REPO_ROOT/build/out/iso_staging"
OUTPUT_ISO="$REPO_ROOT/build/out/ElvonOS-$VERSION-amd64.iso"

if [[ $EUID -ne 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
        echo "Error: Root privileges required to build ISO."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

echo "=================================================="
echo " ElvonOS V1 — Building Hybrid Live ISO"
echo " Source Rootfs: $ROOTFS"
echo " Output ISO:    $OUTPUT_ISO"
echo "=================================================="

if [[ ! -d "$ROOTFS" ]]; then
    echo "Error: Rootfs not found at $ROOTFS. Run build-rootfs.sh first."
    exit 1
fi

# Clean and prepare staging
if [[ "${REBUILD_SQUASHFS:-0}" == "1" ]]; then
    $SUDO rm -rf "$ISO_STAGING"
fi
mkdir -p "$ISO_STAGING/live"
mkdir -p "$ISO_STAGING/boot/grub"
mkdir -p "$ISO_STAGING/EFI/BOOT"
mkdir -p "$ISO_STAGING/elvonos/waydroid"
mkdir -p "$ISO_STAGING/.disk"

echo "ElvonOS V1 (Debian 13 Trixie - amd64)" | tee "$ISO_STAGING/.disk/info" >/dev/null

# 1. Copy Kernel and Initrd from Rootfs
echo "==> Extracting kernel and initramfs from rootfs..."
KERNEL_BIN=$(ls -1 "$ROOTFS"/boot/vmlinuz-*elvonos* 2>/dev/null | head -n 1 || true)
[ -n "$KERNEL_BIN" ] || KERNEL_BIN=$(ls -1 "$ROOTFS"/boot/vmlinuz-* | head -n 1)
INITRD_BIN=$(ls -1 "$ROOTFS"/boot/initrd.img-*elvonos* 2>/dev/null | head -n 1 || true)
[ -n "$INITRD_BIN" ] || INITRD_BIN=$(ls -1 "$ROOTFS"/boot/initrd.img-* | head -n 1)

if [[ -z "$KERNEL_BIN" || -z "$INITRD_BIN" ]]; then
    echo "Error: Kernel or initrd missing in rootfs /boot"
    exit 1
fi

$SUDO cp -f "$KERNEL_BIN" "$ISO_STAGING/live/vmlinuz"
$SUDO cp -f "$INITRD_BIN" "$ISO_STAGING/live/initrd.img"
# Kernel-Config mitliefern (der Installer braucht sie für update-initramfs)
CONFIG_BIN=$(ls -1 "$ROOTFS"/boot/config-* 2>/dev/null | head -n 1 || true)
if [[ -n "$CONFIG_BIN" ]]; then
    $SUDO cp -f "$CONFIG_BIN" "$ISO_STAGING/live/config"
fi

# 2. Bundle Waydroid Android 16 Images
echo "==> Bundling Waydroid Android 16 images..."
WAYDROID_IMG_DIR="$REPO_ROOT/Android/Waydroid-images/android16"
if [[ -f "$WAYDROID_IMG_DIR/system.img" && -f "$WAYDROID_IMG_DIR/vendor.img" ]]; then
    cp --sparse=always "$WAYDROID_IMG_DIR/system.img" "$ISO_STAGING/elvonos/waydroid/"
    cp --sparse=always "$WAYDROID_IMG_DIR/vendor.img" "$ISO_STAGING/elvonos/waydroid/"
    (cd "$ISO_STAGING/elvonos/waydroid" && sha256sum system.img vendor.img > SHA256SUMS)
    SYS_SHA=$(sha256sum "$ISO_STAGING/elvonos/waydroid/system.img" | cut -d' ' -f1)
    VEN_SHA=$(sha256sum "$ISO_STAGING/elvonos/waydroid/vendor.img" | cut -d' ' -f1)
    python3 - "$ISO_STAGING/elvonos/waydroid/elvonos-image.json" \
        "$SYS_SHA" "$VEN_SHA" <<'PY'
import datetime, json, sys
path, sys_sha, ven_sha = sys.argv[1:4]
data = {
    "id": "android16",
    "name": "Android 16 (LineageOS 23.2 QPR2)",
    "android": "16",
    "sdk": 36,
    "vendor_type": "MAINLINE",
    "release": "20260717",
    "created": datetime.datetime.now(datetime.timezone.utc)
                .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "system": {"file": "system.img", "sha256": sys_sha},
    "vendor": {"file": "vendor.img", "sha256": ven_sha},
    "source": "https://github.com/WayDroid-ATV/waydroid-builds",
}
open(path, "w").write(json.dumps(data, indent=2) + "\n")
PY
    echo "==> Bundled Android 16 system.img and vendor.img with checksums."
elif [[ -f "$REPO_ROOT/Android/Waydroid-images/system.img" && \
        -f "$REPO_ROOT/Android/Waydroid-images/vendor.img" ]]; then
    echo "==> Android 16 images not found; falling back to Android 13 images."
    cp --sparse=always "$REPO_ROOT/Android/Waydroid-images/system.img" "$ISO_STAGING/elvonos/waydroid/"
    cp --sparse=always "$REPO_ROOT/Android/Waydroid-images/vendor.img" "$ISO_STAGING/elvonos/waydroid/"
    (cd "$ISO_STAGING/elvonos/waydroid" && sha256sum system.img vendor.img > SHA256SUMS)
    echo "==> Bundled Android 13 system.img and vendor.img with checksums."
else
    echo "Warning: Waydroid images not found in Android/Waydroid-images/."
fi

# 2b. ElvonOS version and update trust anchor (see documentation/11-*)
printf 'VERSION=%s\n' "${ELVONOS_VERSION:-1.0.0}" | \
    $SUDO tee "$ROOTFS/etc/elvonos-release" >/dev/null
# License texts shipped with the image
$SUDO install -Dm644 "$REPO_ROOT/LICENSE" "$ROOTFS/usr/share/doc/elvonos/LICENSE"
$SUDO install -Dm644 "$REPO_ROOT/LICENSES.md" "$ROOTFS/usr/share/doc/elvonos/LICENSES.md"
$SUDO install -Dm644 "$REPO_ROOT/documentation/14-licensing.md" \
    "$ROOTFS/usr/share/doc/elvonos/licensing-decision.md"
# Component version shipped with this image (payload updates compare against it)
$SUDO mkdir -p "$ROOTFS/var/lib/elvonos/components"
printf '%s\n' "$APPS_VERSION" | \
    $SUDO tee "$ROOTFS/var/lib/elvonos/components/elvonos-apps.version" >/dev/null
if [[ -x "$REPO_ROOT/build/update/install-update-key.sh" ]]; then
    ELVONOS_UPDATE_KEY="${ELVONOS_UPDATE_KEY:-$HOME/.config/elvonos/keys/elvonos.pub}" \
        bash "$REPO_ROOT/build/update/install-update-key.sh" "$ROOTFS" || \
        echo "==> No update signing key installed (optional)."
fi

# 3. Create SquashFS Filesystem
if [[ -f "$ISO_STAGING/live/filesystem.squashfs" && "${REBUILD_SQUASHFS:-0}" != "1" ]]; then
    echo "==> Reusing existing filesystem.squashfs..."
else
    echo "==> Creating filesystem.squashfs (this may take a couple of minutes)..."
    cd "$ROOTFS"
    $SUDO mksquashfs . "$ISO_STAGING/live/filesystem.squashfs" \
        -comp xz \
        -e boot \
        -e tmp/* \
        -e var/cache/apt/archives/* \
        -e proc/* \
        -e sys/* \
        -e dev/* \
        -e run/* \
        -noappend
fi

# 4. Configure GRUB for Hybrid Boot (Serial + Screen)
echo "==> Configuring GRUB bootloader..."
cat << 'EOF' > "$ISO_STAGING/boot/grub/grub.cfg"
set default=0
set timeout=3

insmod part_gpt
insmod part_msdos
insmod fat
insmod ext2
insmod iso9660
insmod all_video
insmod gfxterm

serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input console serial
terminal_output console serial

search --no-floppy --set=root --file /live/vmlinuz

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "ElvonOS V1 Live (Debian 13 + Labwc + Waydroid)" {
    linux /live/vmlinuz boot=live components apparmor=0 security=selinux console=tty0 console=ttyS0,115200n8 username=elvon nox11autologin nottyautologin quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0
    initrd /live/initrd.img
}

menuentry "ElvonOS V1 (Failsafe / Nomodeset)" {
    linux /live/vmlinuz boot=live components nomodeset apparmor=0 console=tty0 console=ttyS0,115200n8 username=elvon nox11autologin nottyautologin quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0
    initrd /live/initrd.img
}
EOF

# 5. Build BIOS and EFI bootloader images
echo "==> Generating BIOS and EFI bootloader images..."
# BIOS (i386-pc-eltorito via grub-mkimage with embedded modules)
grub-mkimage \
    -O i386-pc-eltorito \
    -o "$ISO_STAGING/boot/grub/bios.img" \
    -p /boot/grub \
    iso9660 biosdisk part_msdos part_gpt search search_fs_file linux normal test echo terminal serial font gfxterm gfxmenu all_video

# EFI (x86_64-efi)
grub-mkstandalone \
    --format=x86_64-efi \
    --output="$ISO_STAGING/EFI/BOOT/BOOTX64.EFI" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$ISO_STAGING/boot/grub/grub.cfg"

# Create clean EFI FAT partition image for UEFI booting (24MB)
rm -f "$ISO_STAGING/boot/grub/efi.img"
dd if=/dev/zero of="$ISO_STAGING/boot/grub/efi.img" bs=1M count=24
mkfs.vfat "$ISO_STAGING/boot/grub/efi.img"
mmd -i "$ISO_STAGING/boot/grub/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "$ISO_STAGING/boot/grub/efi.img" "$ISO_STAGING/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/

# 6. Assemble Hybrid ISO with xorriso
echo "==> Generating hybrid bootable ISO with xorriso..."
mkdir -p "$(dirname "$OUTPUT_ISO")"
xorriso -as mkisofs \
    -r -V "ELVONOS_V1" \
    -J -joliet-long \
    -b boot/grub/bios.img \
    -c boot/grub/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "$OUTPUT_ISO" \
    "$ISO_STAGING"

echo "==> Computing ISO checksum..."
(cd "$(dirname "$OUTPUT_ISO")" && sha256sum "$(basename "$OUTPUT_ISO")" > "$(basename "$OUTPUT_ISO").sha256")

echo "=================================================="
echo " ElvonOS V1 ISO built successfully!"
echo " ISO:      $OUTPUT_ISO"
echo " Checksum: $(cat "$OUTPUT_ISO.sha256")"
echo "=================================================="
