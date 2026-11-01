#!/usr/bin/env bash
# ElvonOS V1 — Phase 7: Build Live Bootable ISO
# Assembles SquashFS, EFI/BIOS bootloader, bundled Waydroid images, and hybrid ISO image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOTFS="${1:-$REPO_ROOT/build/out/rootfs}"
ISO_STAGING="$REPO_ROOT/build/out/iso_staging"
OUTPUT_ISO="$REPO_ROOT/build/out/ElvonOS-1.0.0-amd64.iso"

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
$SUDO rm -rf "$ISO_STAGING"
mkdir -p "$ISO_STAGING/live"
mkdir -p "$ISO_STAGING/boot/grub"
mkdir -p "$ISO_STAGING/EFI/BOOT"
mkdir -p "$ISO_STAGING/elvonos/waydroid"
mkdir -p "$ISO_STAGING/.disk"

echo "ElvonOS V1 (Debian 13 Trixie - amd64)" | tee "$ISO_STAGING/.disk/info" >/dev/null

# 1. Copy Kernel and Initrd from Rootfs
echo "==> Extracting kernel and initramfs from rootfs..."
KERNEL_BIN=$(ls -1 "$ROOTFS"/boot/vmlinuz-* | head -n 1)
INITRD_BIN=$(ls -1 "$ROOTFS"/boot/initrd.img-* | head -n 1)

if [[ -z "$KERNEL_BIN" || -z "$INITRD_BIN" ]]; then
    echo "Error: Kernel or initrd missing in rootfs /boot"
    exit 1
fi

$SUDO cp -f "$KERNEL_BIN" "$ISO_STAGING/live/vmlinuz"
$SUDO cp -f "$INITRD_BIN" "$ISO_STAGING/live/initrd.img"

# 2. Bundle Waydroid Android 13 Images
echo "==> Bundling Waydroid Android 13 images..."
if [[ -f "$REPO_ROOT/Android/Waydroid-images/system.img" && -f "$REPO_ROOT/Android/Waydroid-images/vendor.img" ]]; then
    cp "$REPO_ROOT/Android/Waydroid-images/system.img" "$ISO_STAGING/elvonos/waydroid/"
    cp "$REPO_ROOT/Android/Waydroid-images/vendor.img" "$ISO_STAGING/elvonos/waydroid/"
    (cd "$ISO_STAGING/elvonos/waydroid" && sha256sum system.img vendor.img > SHA256SUMS)
    echo "==> Bundled system.img and vendor.img with checksums."
else
    echo "Warning: Waydroid images not found in Android/Waydroid-images/. ISO will build without bundled images."
fi

# 3. Create SquashFS Filesystem
echo "==> Creating filesystem.squashfs (this may take a couple of minutes)..."
$SUDO mksquashfs "$ROOTFS" "$ISO_STAGING/live/filesystem.squashfs" \
    -comp xz \
    -e "$ROOTFS/boot" \
    -e "$ROOTFS/tmp/*" \
    -e "$ROOTFS/var/cache/*" \
    -noappend

# 4. Configure GRUB for UEFI Boot
echo "==> Configuring GRUB bootloader..."
cat << 'EOF' > "$ISO_STAGING/boot/grub/grub.cfg"
set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod fat
insmod ext2
insmod all_video
insmod gfxterm

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "ElvonOS V1 Live & Installer (Debian 13 + Hyprland + Waydroid)" {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd.img
}

menuentry "ElvonOS V1 (Failsafe / Nomodeset)" {
    linux /live/vmlinuz boot=live components nomodeset
    initrd /live/initrd.img
}
EOF

# 5. Build standalone EFI boot image
echo "==> Generating EFI bootloader image..."
grub-mkstandalone \
    --format=x86_64-efi \
    --output="$ISO_STAGING/EFI/BOOT/BOOTX64.EFI" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$ISO_STAGING/boot/grub/grub.cfg"

# Create EFI FAT partition image for hybrid booting
dd if=/dev/zero of="$ISO_STAGING/boot/grub/efi.img" bs=1M count=8
mkfs.vfat "$ISO_STAGING/boot/grub/efi.img"
mmd -i "$ISO_STAGING/boot/grub/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "$ISO_STAGING/boot/grub/efi.img" "$ISO_STAGING/EFI/BOOT/BOOTX64.EFI" ::/EFI/BOOT/

# 6. Assemble Hybrid ISO with xorriso
echo "==> Generating hybrid bootable ISO with xorriso..."
mkdir -p "$(dirname "$OUTPUT_ISO")"
xorriso -as mkisofs \
    -r -V "ELVONOS_V1" \
    -J -joliet-long \
    -b boot/grub/efi.img \
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
