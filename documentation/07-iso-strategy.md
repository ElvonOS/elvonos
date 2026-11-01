# 07 — ISO Generation Strategy

Goal: a bootable **ElvonOS V1 ISO** that installs a working Debian 13 + Hyprland + Waydroid system without asking the user to install either stack manually.

---

## 1. Build-host requirement

The final ISO **must be built on Debian 13 amd64 with root**, not in the WSL guest.

Reasons:

- live-build/mmdebstrap need chroot/mount operations that WSL does not reliably provide.
- The WSL kernel is not the Debian kernel; boot artifacts must be produced and tested against the real one.
- Loop devices, filesystem creation, and GRUB installation are more reliable on a normal Debian host or VM.

Recommended build environments:

1. Debian 13.7 VM with 8+ GB RAM, 40+ GB free disk, UEFI firmware.
2. A dedicated Debian 13.7 bare-metal build machine.
3. The target laptop booted from a Debian 13 live environment (for final validation only).

WSL may be used for source editing, package metadata checks, and unit tests, but not as the authoritative ISO builder.

---

## 2. Approach

**live-build + Calamares** is the selected V1 path.

| Layer | Tool | Purpose |
|---|---|---|
| Live rootfs | `live-build` 1:20250505+deb13u1 | Debian live system, squashfs, boot menu |
| Installer | `calamares` 3.3.14-1 + `calamares-settings-debian` 13.0.13-1 | Partitioning, user creation, bootloader, post-install |
| Boot | GRUB EFI + BIOS hybrid | UEFI Secure Boot and legacy BIOS |
| Compression | `squashfs-tools` | Live filesystem |
| ISO assembly | `xorriso` | Hybrid ISO |
| Custom packages | ElvonOS signed repo | Hyprland, Waydroid, desktop, services |

Why not a custom installer in V1: Calamares already provides partitioning, encryption, user creation, locale, and bootloader installation. Building a custom installer would delay V1 without improving the Android-first experience. The ElvonOS identity belongs in branding, first-boot setup, and the desktop — not in reimplementing disk partitioning.

Why not the Debian Installer preseed: it is robust but not a friendly live-install experience, and Calamares integrates cleanly with a live session.

---

## 3. ISO contents

```
/
├── live/
│   ├── vmlinuz
│   ├── initrd.img
│   └── filesystem.squashfs
├── boot/
│   ├── grub/            UEFI
│   └── isolinux/        BIOS fallback
├── EFI/BOOT/BOOTX64.EFI
├── elvonos/
│   ├── packages/        custom .deb files + Packages.gz + signature
│   ├── waydroid/        system.img, vendor.img, checksums
│   └── branding/        logos, Calamares branding, first-boot assets
└── .disk/
```

Live rootfs packages:

- Debian base and firmware from the manifests in `06-package-plan.md`,
- Calamares and its Debian settings,
- ElvonOS Hyprland/Waydroid/desktop `.deb` packages,
- live-boot/live-config,
- NetworkManager, PipeWire, Mesa,
- a live user and autologin for the live session,
- the ElvonOS installer launcher.

Waydroid images:

- Include `system.img` and `vendor.img` in the ISO for an offline first boot.
- Verify SHA256 before copying.
- If ISO size becomes a problem, provide a first-boot download path with checksum verification and a clear failure message. Do not silently download unverified images.

Estimated ISO size: **3–4 GiB** (2.3 GiB images plus live rootfs and packages). This is acceptable for V1; document it.

---

## 4. Reproducibility

- Pin a **snapshot.debian.org** date in the build configuration; do not build against a moving `trixie` archive.
- Record every resolved package version in `build/out/packages.lock`.
- Pin custom package source tarballs and SHA256 in `build/sources.lock`.
- Set `SOURCE_DATE_EPOCH` for the build.
- Sign the ElvonOS repository and the ISO checksum file.
- Keep build logs in `build/logs/` with timestamps and command lines.
- Do not embed credentials, tokens, or private keys in the ISO.

---

## 5. Installation flow

1. Boot ISO (UEFI preferred; BIOS fallback).
2. Live session starts Hyprland + ElvonOS shell (or a minimal installer session if the full shell is not ready).
3. User launches **Install ElvonOS**.
4. Calamares:
   - language/keyboard,
   - disk selection and partitioning (erase disk, install alongside, manual; LUKS optional),
   - user account creation,
   - timezone,
   - bootloader installation (GRUB EFI; BIOS fallback),
   - summary and install.
5. Post-install:
   - copy/install ElvonOS custom packages,
   - enable `elvonos-*` services,
   - generate the Hyprland configuration,
   - initialize Waydroid with the bundled images,
   - configure the ElvonOS session in the display manager,
   - create the first-boot marker.
6. Reboot into the installed system.
7. First-boot wizard:
   - network check,
   - Android setup (Waydroid initialization if not already done),
   - optional Aurora Store/F-Droid installation instructions,
   - optional microG configuration (never bundled by default),
   - privacy/telemetry choice (default: off).

The user must not need a terminal, `waydroid init`, or Hyprland configuration to reach a working desktop.

---

## 6. Boot and Secure Boot

- UEFI: `grub-efi-amd64-signed` + `shim-signed`; Debian signed kernel.
- BIOS: `grub-pc-bin` + isolinux fallback for old machines; not the primary target.
- Secure Boot: the stock Debian kernel and in-tree binder module preserve compatibility. Any future out-of-tree module would require signing and is out of V1 scope.
- GRUB menu retains the previous kernel after updates.
- Recovery entry: boot the ISO in recovery mode, or use the installed `elvonos-recovery` tool.

---

## 7. Recovery strategy

V1 recovery is **tool + bootloader**, not a full A/B image system:

- GRUB previous-kernel entry.
- `elvonos-recovery` can:
  - reinstall the desktop/compositor packages,
  - reset Waydroid (with explicit confirmation and data backup),
  - roll back the last APT transaction where possible,
  - restore network/audio defaults,
  - collect logs for support.
- User data is never overwritten by a system update.
- Android data lives under the Waydroid data directory, separate from host system files.
- Optional btrfs snapshots are future work; do not promise them in V1.

---

## 8. Test plan

### Build validation

- [ ] ISO builds from a clean Debian 13.7 host with a single command.
- [ ] Build log contains resolved versions and source checksums.
- [ ] ISO checksum file verifies.
- [ ] No credentials or build-host paths leak into the image.

### Boot validation

- [ ] UEFI boot on the target laptop (Secure Boot on and off).
- [ ] BIOS boot in a VM.
- [ ] GRUB menu and kernel/initramfs load.
- [ ] systemd reaches multi-user/graphical target.
- [ ] Hyprland session starts.
- [ ] ElvonOS shell starts.
- [ ] Live installer launches.

### Install validation

- [ ] Erase-disk install on a spare disk/VM.
- [ ] UEFI boot entry created.
- [ ] User account and password work.
- [ ] First boot reaches the ElvonOS desktop.
- [ ] Waydroid initializes from bundled images.
- [ ] APK install and launch work.
- [ ] Reboot preserves user data and Android data.

### Real hardware

- [ ] Wi-Fi/Bluetooth/audio/GPU after install.
- [ ] Suspend/resume.
- [ ] External monitor.
- [ ] USB storage.
- [ ] Kernel update retains the previous kernel and boots.

Virtual machines are supplementary. The release gate requires physical hardware evidence.
