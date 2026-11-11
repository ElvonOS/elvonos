# Upstream base, forks and ElvonOS changes (English)

This document records exactly what ElvonOS 1.0 is built from, which upstream
projects were forked or patched, and what was changed. It complements
[`14-licensing.md`](14-licensing.md) and [`06-package-plan.md`](06-package-plan.md).

## 1. Base operating system

| Item | Value |
|---|---|
| Distribution base | **Debian 13 "Trixie"** (amd64) |
| Bootstrap | `mmdebstrap` (falls back to `debootstrap`) into `build/out/rootfs` |
| Package sources | Debian stable + `trixie-updates` + `trixie-security` only (no unstable, no global backports) |
| Init | systemd 257 |
| Desktop protocol | Wayland (labwc/wlroots) |
| Live system | Debian `live-boot`/`live-config` with an overlay root |
| Bootloader | GRUB 2.12 (UEFI + BIOS) |

ElvonOS is a **distribution**: it aggregates Debian packages with its own
desktop shell, applications, kernel build, installer and update system.

## 2. Component overview

| Component | Upstream | Version / commit | License | ElvonOS involvement |
|---|---|---|---|---|
| Linux kernel | Debian `linux-source-6.12` | 6.12.116 | GPL-2.0-only | Rebuilt with a small config delta, `-elvonos` localversion |
| GRUB | GNU GRUB (Debian) | 2.12-9+deb13u2 | GPL-3.0-or-later | Installer integration + standalone EFI fallback |
| labwc | labwc/labwc (Debian) | 0.8.3-1 | GPL-2.0-or-later | **Not forked**; configuration only |
| Win8DE shell | `github.com/er-bharat/Win8DE` | `cc5594526cf6fd2e5957f44afaf4268e425acd45` (0.9.0-beta2) | GPL-2.0 | **Forked with 18 patches** (see §3) |
| Waydroid | `waydroid/waydroid` | 1.6.3 | GPL-3.0-or-later | Vendored source + service/property patches + Rust wrapper |
| Android image | LineageOS 23.2 / Android 16 VANILLA (x86_64), WayDroid-ATV build 20260717 | 2026-07-17 | Apache-2.0, LineageOS and component licenses | Bundled unmodified as `system.img`/`vendor.img`; `elvonos-waydroid-image` manages and repacks custom images |
| Qt | Qt 6 (Debian) | 6.8.2 | LGPL-3.0 / GPL-3.0 | Toolkit for ElvonOS apps |
| PipeWire / WirePlumber | upstream (Debian) | Debian 13 | MIT | Noise-suppression and buffer configuration |
| libinput / wlroots | upstream (Debian) | Debian 13 | MIT | Unchanged |
| Plymouth | upstream (Debian) | 24.004.60 | GPL-2.0-or-later | Custom `elvonos` theme |
| Inter font | rsms/inter | 4.x | SIL OFL 1.1 | UI typeface |
| minisign | jedisct1/minisign | 0.11 | BSD-2-Clause | Update signatures |

## 3. Win8DE fork (GPL-2.0)

ElvonOS uses the Windows-8-style **Win8DE** shell from
`https://github.com/er-bharat/Win8DE` at commit
`cc5594526cf6fd2e5957f44afaf4268e425acd45`. The fork is reproduced by
`build/win8de/build-win8de.sh`; patches live in `build/win8de/patches/`.

| Patch | What it changes |
|---|---|
| 0001 | labwc shell fixes (window/layer integration) |
| 0002 | battery indicator spacing |
| 0003 | Win8Running: hide instead of close |
| 0004 | start-menu/window-switcher synchronisation |
| 0005 | reset "launching" tile state |
| 0006 | refresh the all-apps screen |
| 0007 | Flatpak application icons |
| 0008 | modern taskbar (layout, grouping, tray) |
| 0009 | modern desktop (icons, wallpaper handling) |
| 0010 | Start screen widgets (clock, system, weather tile) |
| 0011 | Aero-glass styling |
| 0012 | live tiles always active |
| 0013 | frosted-glass effects |
| 0014 | Win8Running watches `windows.ini` |
| 0015 | taskbar tray, context menu and grouping |
| 0016 | panel position and Start logo |
| 0017 | Start button stays visible |
| 0018 | **always-visible Restart/Shut down buttons** and a 15 s stale single-instance lock |

Additional ElvonOS-side shell changes (not in the Win8DE source):

- `base/configuration/labwc/rc.xml`: Super toggles Start, hot corners, window
  rules, **Metro mode** implemented as a `Maximize` window rule.
- `base/configuration/labwc/autostart`: session order, splash bridge, tray,
  Waydroid storage, health daemon, stale-lock cleanup.
- `Win8Start` default tile layout generator (`elvonos-win8start-defaults`).

## 4. Waydroid integration

- Upstream **Waydroid 1.6.3** source is vendored in `Android/waydroid-1.6.3/`.
- Patched `systemd/waydroid-container.service`:
  - preloads `binder_linux` with the three legacy device names Waydroid probes,
  - fails early when binder devices are missing,
  - restarts on failure with bounded retries and longer start/stop timeouts,
  - cleans up `waydroid-net.sh` on stop.
- `base/configuration/waydroid/elvonos-waydroid.properties`: multi-window mode,
  GBM gralloc + Mesa EGL, hidden Android window decorations, suspend disabled.
- `base/configuration/waydroid-rs/`: **`elvonos-waydroid`**, a Rust client with
  `open FILE`, `share TEXT`, `freeze`/`unfreeze`, `backup`/`restore`,
  `multiwindow on|off`, a singleton bridge and lock-screen hook.
- Android 16 images (LineageOS 23.2 QPR2 VANILLA + MAINLINE vendor) are
  bundled unmodified; the ISO ships `system.img`, `vendor.img`,
  `SHA256SUMS` and `elvonos-image.json`. `elvonos-waydroid-image` can
  download verified releases and build custom images (EROFS/ext4).

## 5. ElvonOS applications and services

Written for ElvonOS in C++/Qt 6 (QML UI, gold/blue Win8DE styling):

| App / service | Purpose |
|---|---|
| Settings (`elvonos-settings`) | system, network, devices, apps, design, time, gaming, firewall, privacy, updates, backups |
| Terminal (`elvonos-terminal`) | PTY terminal with ANSI/256/true colour, selection, Android shell |
| Files / Explorer | file manager with Android storage bridge |
| Store | Flathub + Android app catalog |
| Control Center | performance, protection, audio |
| Calculator, Notepad, Archiver, PDF viewer, Screenshot, Paint, Gallery, Media, Event Viewer, Task Manager, Cleaner, Defrag, Print/Scan | desktop utilities |
| `elvonos-installer` | live installer (see `13-live-installer.md`) |
| `elvonos-firstboot` | first-boot installation of optional software |
| `elvonos-update` | signed update client (see `15-free-updates.md`) |
| `elvonos-healthd` | 15 s watchdog, `/run/elvonos/health.json` |
| `elvonos-tune`, `elvonos-appmode`, `elvonos-sound`, `elvonos-gaming-setup`, `elvonos-waydroid` | system tuning, Metro/desktop switch, sounds, gaming setup, Android integration |

## 6. Kernel

The kernel is Debian's `linux-source-6.12` rebuilt with only:

| Option | Value | Reason |
|---|---|---|
| `CONFIG_LOCALVERSION` | `-elvonos` | identify the ElvonOS kernel |
| `CONFIG_DEBUG_INFO` / `BTF` / `DWARF5` / `GDB_SCRIPTS` | off | faster build, smaller modules |

Everything else (Binder, virtio-gpu/Virgl, NTFS3, zram, GPU, Wi-Fi, audio,
filesystems) stays at Debian's values. The initramfs is generated with
`MODULES=most`, so **all drivers remain available**, including in the
initramfs. The exact configuration is kept in
`build/kernel/elvonos-6.12.config`.

## 7. Boot, splash, themes

- GRUB menu with live and failsafe entries; the installer writes UEFI and BIOS
  GRUB plus an unsigned `grub-mkstandalone` fallback at `EFI/BOOT/BOOTX64.EFI`.
- Plymouth theme **`elvonos`**: dark gradient background, Inter wordmark,
  orbiting dots, heartbeat halo; followed by `elvonos-splash` (Qt Quick,
  software renderer) until the shell is ready.
- Desktop theme, icons, wallpapers and system sounds are ElvonOS assets
  (`base/configuration/{labwc,icons,media,plymouth,splash}`).

## 8. Installer and update system

- **Installer**: Bash + Zenity, GPT (BIOS + EFI), ext4, `rsync` copy, locale,
  keyboard, time zone, user/password, hostname, optional software queue,
  GRUB/initramfs setup (details in `13-live-installer.md`).
- **Updates**: static signed feed (`stable.json` + `.minisig`) on GitHub and
  Codeberg; ISOs on SourceForge; `elvonos-update` verifies sha256 + minisign
  before use (details in `15-free-updates.md`).
- **Update layers**:
  - Debian base OS packages via `apt-get upgrade`,
  - ElvonOS software as a signed `.tar.zst` **payload** (apps, Store, Settings,
    Terminal, installer, scripts, desktop entries) extracted over `/`,
  - signed **script components** for setup actions (e.g. Flathub for the Store),
  - Flatpak metadata refresh,
  - a new ISO for kernel/bootloader/live-image changes.

## 9. Not forked / unchanged

- Debian packages (binaries and data) are used as shipped by Debian.
- The kernel source is Debian's; only the configuration differs.
- labwc, wlroots, Wayland, PipeWire, NetworkManager, udisks2, GRUB and the
  Android images are unmodified upstream builds.
- Waydroid core code is unmodified; only its service unit and properties are
  patched.

## 10. Reproducibility

- Win8DE: pinned commit + `patches/0001…0018` (applied by `build-win8de.sh`).
- Kernel: `build/kernel/build-kernel.sh` + saved config.
- Rootfs: `build/phase1/build-rootfs.sh` and the package lists in
  `base/packages/`.
- ISO: `build/phase7/build-iso.sh`.
- Every release artifact is published with `SHA256SUMS` and a minisign
  signature.

## 11. Screenshots

English screenshots are hosted on SourceForge:
<https://sourceforge.net/projects/elvonos/files/screenshots/>
