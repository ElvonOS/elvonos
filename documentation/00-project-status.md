# 00 — Current Project Status

Inspection date: **2026-11-01**
Repository: `/home/kirara/ElvonOS` (WSL Debian filesystem)
Status: **Phase 0 complete; Phase 1 not executed**

---

## 1. Repository inventory

The repository contained only the following before this audit:

| Path | Content | Size |
|---|---|---|
| `Android/waydroid-1.6.3/` | Upstream Waydroid 1.6.3 source tree | ~9 MB |
| `Android/Waydroid-images/system.img` | Android system image, ext4 | 1.8 GiB |
| `Android/Waydroid-images/vendor.img` | Android vendor image, ext4 | 537 MiB |

There was:

- no ElvonOS source code,
- no build system,
- no package manifests,
- no installer,
- no tests,
- no documentation,
- no Git repository (and no `git` binary in the WSL image).

The `Android/` directory is treated as a **vendored upstream input**, not as ElvonOS-owned code. It was not modified.

### Waydroid image identification

Extracted from the images:

```
ro.build.version.release=13
ro.build.version.sdk=33
ro.lineage.version=20.0-20260927-VANILLA-waydroid_x86_64
```

SHA256:

```
30c87ee44412fee4f50173716a6bb7c6941d3021853f0adab4a249da8a9455ab  system.img
5cc4267517ded28f1cf60a5d2b6e8b88b15d8520de1f55a39de7764e7929a877  vendor.img
```

Both are ext4 (`53 ef` superblock magic). This is an Android 13 / LineageOS 20 VANILLA Waydroid image, consistent with Waydroid 1.6.3's supported image family.

---

## 2. Development environment

| Item | Value |
|---|---|
| Host OS | Windows 10 Home 22H2, build 19045 |
| WSL distro | Debian GNU/Linux 13 (Trixie), 13.5 |
| WSL kernel | `6.18.54.1-microsoft-standard-WSL2` (Microsoft kernel, not Debian) |
| Architecture | x86_64 |
| CPU exposed to WSL | AMD Ryzen 5 5600H, 4 vCPU |
| RAM exposed | 10 GiB |
| Disk free | ~954 GiB |
| Init | systemd (running) |
| Display socket | WSLg `wayland-0` |
| GPU exposed | `/dev/dri/card0` backed by `faux_driver` (WSL virtual, not AMD/NVIDIA) |
| Audio | WSLg PulseAudio sockets only; `/dev/snd` has only a timer |
| Virtualization | No `/dev/kvm`; CPU virtualization flag not exposed |
| Privilege | `sudo` requires a password; no passwordless root |
| Toolchain | No gcc, make, cmake, rustc, cargo, git, python3, curl, wget, debootstrap, live-build, xorriso, mksquashfs |

### Running kernel is not the target kernel

`/proc/config.gz` on the WSL kernel reports:

```
# CONFIG_ANDROID_BINDER_IPC is not set
```

There is no `/dev/binder`, `/dev/vndbinder`, or `/dev/hwbinder`. The WSL kernel cannot be used to validate Waydroid or the Debian kernel compatibility path. The official Debian kernel configuration was therefore inspected from the actual `linux-image-6.12.107+deb13-amd64` package (see `02-kernel-compatibility.md`).

### WSL cannot validate

- UEFI/GRUB boot, initramfs, systemd boot, login, Hyprland startup
- DRM/KMS, AMD/NVIDIA GPU acceleration, Vulkan
- Real audio, Bluetooth, Wi-Fi, USB, touchpad, suspend/resume
- LXC/binder behavior on the Debian kernel
- Waydroid Android boot, APK install, app launch, multi-window

These require a Debian 13 bare-metal install or a Debian 13 VM with the official Debian kernel. The target laptop is the primary hardware test platform.

---

## 3. Host hardware (real machine behind WSL)

| Item | Value |
|---|---|
| System | LENOVO 82JU (Legion 5 15ACH6H class) |
| CPU | AMD Ryzen 5 5600H, 6 cores / 12 threads |
| RAM | 21.3 GB |
| iGPU | AMD Radeon Graphics (Cezanne, PCI ID `0x1638`) |
| dGPU | NVIDIA GeForce RTX 3070 Laptop GPU (GA104) |
| Storage | SK Hynix HFS512GDE9X084N 512 GB NVMe; external USB disks |
| Wi-Fi | MediaTek Wi-Fi 6 MT7921 |
| Bluetooth | MediaTek MT7921 Bluetooth |
| Ethernet | Realtek PCIe GbE |
| Audio | Realtek HD Audio + NVIDIA HDMI audio |
| Firmware | Lenovo BIOS GKCN65WW (2024-01-16) |
| Secure Boot | Not queryable without elevation; must be checked in firmware setup |

The host is a suitable first real-hardware target: AMD iGPU + NVIDIA dGPU, NVMe, Wi-Fi 6, Bluetooth, USB-C, and external displays.

---

## 4. What was verified

| Check | Result |
|---|---|
| Debian version | 13.5 running; archive 13.7 |
| APT sources | `trixie`, `trixie-updates`, `trixie-backports`, `trixie-security`; **main only** (no contrib/non-free-firmware) |
| Debian kernel package | `linux-image-amd64` 6.12.107-1, kernel ABI `6.12.107+deb13-amd64` |
| Debian kernel Binder IPC | `CONFIG_ANDROID_BINDER_IPC=m` |
| Debian kernel BinderFS | **not set** |
| Debian kernel ashmem | absent (Android 13 uses memfd) |
| Namespaces / cgroups / seccomp / overlay / veth / netfilter | enabled (module or built-in) |
| AMDGPU / i915 / Xe / Nouveau / VirtIO GPU | modules present |
| Hyprland in Trixie | **not packaged** |
| Waydroid in Trixie | **not packaged** |
| Hyprland in Debian unstable | 0.57.0+ds-1 |
| Waydroid in Debian unstable | 1.6.3+ds-3 |
| python3-gbinder in Debian unstable | 1.3.1+ds-1+b2 |
| Qt 6 in Trixie | 6.8.2 |
| LayerShellQt in Trixie | 6.3.4 |
| Calamares in Trixie | 3.3.14 |
| live-build / mmdebstrap / xorriso / squashfs-tools | available |
| Network access to deb.debian.org | yes |

Full package tables are in `06-package-plan.md`.

---

## 5. Changes made during this audit

**None to the host system.** Only new files were created inside the repository:

- `README.md`, `VERSION`, `.gitignore`
- `documentation/*`
- `base/packages/*`, `base/configuration/*`
- `build/phase1/*`, `tests/phase1/*`

No packages were installed, no services were enabled, no kernel modules were loaded, and no existing files were modified or deleted.

---

## 6. Phase status

| Phase | Status | Evidence |
|---|---|---|
| 0 — Inspection and reports | **Complete** | Documentation 00–09 |
| 1 — Debian foundation | **Complete (Gates 1–4)** | Rootfs built (546 packages), validated stock 6.12 kernel & binder configs |
| 2 — Wayland Compositor | **In Progress** | Labwc integrated as primary compositor; Hyprland build script as fallback |
| 3 — Android runtime | **Packaged & Integrated** | Waydroid 1.6.3 + GBinder .deb packages built and installed into rootfs |
| 4 — ElvonOS desktop | In Progress | ElvonOS session entrypoints, Labwc & Hyprland configs deployed |
| 5 — Android integration | **Verified in QEMU** | Waydroid 1.6.3 boots Android 13 from the bundled images; Aurora Store and microG are installed automatically on first launch |
| 6 — Hardware integration | Pending HW Boot | Drivers, firmware & modprobe rules installed in rootfs |
| 7 — Installer/ISO | **Built & Verified** | Bootable hybrid Live ISO generated and verified in QEMU (`ElvonOS-1.0.0-amd64.iso`, SHA-256 `dc0f2ac776b1e98d8b8c3a19548d40d4662dce271e7f835e4d8d58588992c295`, 2026-11-09) |
| 8 — Stabilization | In Progress | Labwc + Win8DE live boot tested in QEMU; keyboard/mouse input and Start toggle verified; real-hardware boot pending |

Latest live boot (2026-11-10, ISO SHA-256 `dc0f2ac776b1e98d8b8c3a19548d40d4662dce271e7f835e4d8d58588992c295`, 5.8 GB): The boot shows the ElvonOS splash from the initramfs through the session hand-over — dark backdrop, wordmark, subtitle, slow orbiting spinner and a gently pulsing heartbeat glow; after Plymouth quits, the Qt Quick bridge (software renderer) keeps the same artwork on screen until `Win8Running`/`Win8Start` are up and then fades out (in QEMU/TCG the splash was visible at 56–74 s and the rendered desktop at ~115 s; the long gap is TCG-specific). Full Win8DE startup chain verified — `swaybg`/`Win8Wall`, `elvonos-desktop-extras`, `list-windows`, `Win8Running`, `Win8Corner`, `Win8Start`, `Win8OSD-server`, `battery-daemon`. The Start screen renders the 13-tile layout (Aurora in the former Foot slot, Desktop in the large former Bulk Rename slot, Foot/Bulk Rename swapped) plus the live System and Calendar widget tiles; the live-tile loaders no longer depend on the Start visibility state, so Clock, System and Calendar always render. The taskbar and dock use frosted-glass wallpaper strips. `WLR_BACKENDS=drm,libinput` is active, `WLR_LIBINPUT_NO_DEVICES` is gone, labwc holds four input event devices, the QEMU autostart switches to 1280x768 before the Win8DE shell starts, Super toggles the Start screen, and foot appears in `windows.ini`. On a fresh boot the slim top taskbar is visible with its Start button, live clock/date, window count and show-desktop action; the desktop shows five icons with page dots and a bottom dock with eight pinned apps including Explorer. The Desktop tile (or `elvonos-desktop`) closes Start and reveals the wallpaper, icons and dock; Start opens as a full-screen overlay above the taskbar. A real mouse click on the Desktop tile leaves it at its normal position/scale on the next Start (1.5 s launch timeout plus reset on show, `build/win8de/patches/0005-reset-launching-tiles.patch`). Dragging a desktop icon into the dock adds it persistently (`~/.config/elvonos/dock.json`), and the desktop grid pages by horizontal drag/swipe. The refreshed application cache lists `APK Installer`, `Aurora Store`, `Bazaar`, `Warehouse` and `Waydroid`; Bazaar and Warehouse were started and render their windows in QEMU (Flatpak `GSK_RENDERER=cairo` override). `elvonos-explorer` opens from the dock and browses the Linux home; its Android-apps view uses the generated Waydroid entries, and Android storage is bound on demand via bindfs. `elvonos-explorer` is listed as an "Explorer" chip in the taskbar, opens below the top taskbar and above the dock, and provides its own minimize/maximize/close buttons and a drag grip; multi-selection, copy/cut/paste, new file/folder, properties, path entry (Ctrl+L), trash, sort direction and image thumbnails are available. A "DEVICES" sidebar section lists internal partitions and USB sticks from `lsblk`, mounts them through udisks2 and offers an eject button; mounting a virtual vfat USB stick (label `ELVONUSB`) and reading `Hallo.txt` from `/media/elvon/ELVONUSB` was verified in QEMU. A new Task Manager (`elvonos-taskmanager`) shows Linux and Android processes in the same glass style, with CPU/RAM/load summary, search, sortable columns, END/FORCE controls and a Waydroid tab. The Gallery (`elvonos-gallery`) browses local and Waydroid photos in a thumbnail grid and opens them in a zoomable full-window viewer. `elvonos-paint` adds brush/shape/fill drawing, a colour palette, layers with opacity, zoom/pan, eyedropper/text tools, canvas rotate/flip/resize, undo/redo and PNG/JPEG open/save. `elvonos-defrag` analyzes and defragments ext4 volumes, offers TRIM and streams the operation log. `elvonos-cleaner` reports and removes caches, Trash, temporary files, APT archives and rotated logs. The Control Center (`elvonos-control`) manages performance profiles, ZRAM, Waydroid limits and the nftables protection layer. The Store (`elvonos-store`) unifies the Flathub/Flatpak catalog, installed Linux apps, and Waydroid apps with an Aurora Store entry point. The tuning service applied a ~2 GB ZRAM swap and the firewall at boot (SSH stayed reachable); profile and firewall toggles were verified live. Waydroid 1.6.3 initializes from the bundled images, starts a headless session and boots Android 13; Aurora Store opens as `AppID=waydroid.com.aurora.store` in its own multi-window window and no `waydroid show-full-ui` process remains. Aurora Store 4.8.4 and microG 0.3.17 (GmsCore + Companion) are installed automatically by the `elvonos-waydroid` launcher on the first Waydroid start (package-checked and idempotent). The live test retries the SurfaceFlinger property probe with timeouts because the first-run GmsCore dexopt can briefly stall `lxc-attach`. The boot artwork now uses an **Inter Display** wordmark with a white→ice-blue gradient and a soft halo, and the new **Notepad** (`elvonos-notepad`) is the default `text/plain` handler and part of the dock defaults. The final image adds **Print & Scan** (`elvonos-printscan`, CUPS printers with queue/test-page actions, SANE scanning with 100–600 dpi to `~/Pictures/Scans`; `cups.socket` is enabled), the **Package Installer** (`elvonos-package-installer`) that opens `.deb` files with package info and an `apt-get` install log and AppImages with a make-executable-and-run action (registered as `application/x-appimage` with ELF/AI magic; `gio` detects both types and resolves the installer as default), and the desktop icon context menu (Open, Copy, Rename, Group into folder, Delete to Trash, Properties, Uninstall) with group folders created under `~/Desktop`. All in-house applications are present as desktop shortcuts and in the dock; the Print & Scan and installer windows, printer/scanner tabs, `.deb` and AppImage dialogs, the context menu and the Properties panel were verified from this ISO in QEMU. The final image also contains the **Event Viewer** (`elvonos-eventviewer`): it reads the systemd journal via `journalctl` (current boot or all boots, passwordless `sudo -n` with a plain fallback), offers source filters (All events, System services, Kernel, Authentication, Applications), level filters (All/Errors/Warnings/Info), live search, a five-second Live mode, a detail pane (level, time, source, unit, identifier, PID, host, boot ID, full message), Copy to clipboard and Save log to `~/Documents`; the All/Kernel/Errors views were verified from the final ISO with the live boot journal in QEMU. The taskbar was extended with a **system tray** (volume, network and battery indicators with tooltips and quick actions), a **window context menu** (Activate, Minimize, Maximize/Restore, Close, Close all N windows, Task Manager, Taskbar settings), a **taskbar context menu** (Close active window, Minimize all windows, Task Manager, Taskbar settings), **grouped duplicate windows** with a count badge and click-to-cycle behaviour, and the glass **Taskbar Settings** dialog for bar height (44/54/62 px), grouping, tray icons, clock, window count and titles. `list-windows` now writes stable numeric window IDs and accepts `--activate-id`, `--minimize-id`, `--maximize-id`, `--unmaximize-id`, `--close-id` and `--activate-only-id`, so identically titled windows can be addressed individually; the settings are stored in `~/.config/elvonos/taskbar.json` and applied live through a file watcher. The desktop now also carries a **search pill**: it searches installed applications and files under Desktop, Documents, Downloads, Pictures, Music and Videos, groups the hits into APPLICATIONS and FILES, supports arrow-key navigation and Enter to launch the app or open the file, and clears with Escape or a click; both the application and file searches were verified from this ISO in QEMU. The dock now contains only Explorer, Store, Screenshot and Media Player; all remaining applications are organised into the five desktop group folders System, Maintenance, Office, Media & Graphics and Utilities, leaving the desktop free for the user's own files and software. The new **Settings** app (`elvonos-settings`) covers System (info, performance profile, ZRAM), Network, Devices, Apps (Flatpak/.deb uninstall, default applications, autostart), Design (wallpaper picker), Time & Language, Gaming & VR (WineHQ/Monado/WayVR install buttons and the `.exe` Wine handler), Firewall (nftables toggle and ruleset), Privacy (clear recent/clipboard/thumbnails/history), Updates (apt check/install) and Backups (create/restore/delete tar.gz archives).

### QEMU test-environment pitfalls (resolved)

Three problems made the desktop appear broken in QEMU although labwc was rendering correctly:

1. **Dual GPU / wrong display.** The debug launcher created a default bochs VGA (`card1`) in addition to the virtio-gpu (`card0`). labwc rendered on `card0`, while the GTK window showed `card1` (the tty text console), so every screendump looked black. Fixed in `build/phase1/run-desktop-qemu-debug.sh` with `-vga none -device virtio-gpu-pci,xres=1280,yres=800,edid=on`.
2. **No input devices.** `WLR_BACKENDS=drm` overrides wlroots' backend auto-detection and loads *only* the DRM backend; the libinput backend is never created, so labwc opens no `/dev/input/event*` nodes. `WLR_LIBINPUT_NO_DEVICES=1` additionally hid the "no input devices" diagnostic. Fixed by setting `WLR_BACKENDS=drm,libinput` and removing `WLR_LIBINPUT_NO_DEVICES` in `base/configuration/session/elvonos-session`, `base/configuration/systemd/elvonos-labwc.service` and `build/phase3/configure-desktop-login.sh`.
3. **Win8DE surfaces created at the boot resolution.** Win8Wall, Win8Start and Win8Running create their layer surfaces at the output size present when the process starts. Because the virtio-gpu prefers 640x480, the Start and Apps screens stayed 640 px wide, so the app grid was clipped to the left half after the later mode switch. `base/configuration/labwc/autostart` now switches QEMU/VM guests to 1280x768 **synchronously before** starting the Win8DE shell (guarded by a DMI check; real hardware keeps its native mode).

The virtio-gpu preferred mode remains 640x480; `build/phase7/smoke-test-live.sh` still normalizes the mode defensively. On real hardware the panel's preferred mode is used automatically. The udev `seat`/`uaccess` tags on `/dev/input/event*` are not required by libinput's udev backend (it enumerates `ID_INPUT=1` devices and assigns the default seat) — the missing tags were a red herring.

Default Metro layout: `base/configuration/scripts/elvonos-win8start-defaults` runs from the labwc autostart **before** Win8Start and writes `~/.config/Win8Start/launcher_tiles.json` on first boot. It derives the half-grid from the current output resolution (so the layout is correct on real hardware and in QEMU) and creates eleven tiles: a large live Clock, Foot, Files (Thunar), Waydroid, Volume, Bulk Rename, Foot CLI, Foot Srv, Prefs, an **Aurora Store** tile (`elvonos-waydroid com.aurora.store`) and a **Desktop** tile (`elvonos-desktop`, which closes the Start screen and returns to the desktop with its taskbar visible). Existing user layouts are never overwritten. The Clock tile QML was adapted for the ~243 px tile (smaller time/date fonts and a short `ddd, dd MMM` date), and the Apps screen still shows the full application names.

### Waydroid (Android) in the live image

Waydroid needed four fixes:

1. **Executable bits.** The repackaged Waydroid `.deb` ships `usr/lib/waydroid/waydroid.py` and `usr/lib/waydroid/data/scripts/waydroid-net.sh` as 0644. `/usr/bin/waydroid` is a symlink to the former, so systemd failed with `203/EXEC` and the session with `PermissionError`. `build/phase3/install-waydroid-into-rootfs.sh` now chmods both to 0755.
2. **Preinstalled images.** Waydroid only treats `/etc/waydroid-extra/images` and `/usr/share/waydroid-extra/images` as preinstalled. The live initializer symlinks the bundled ISO images into `/usr/share/waydroid-extra/images`, so `waydroid init -f` writes `system_ota=None` / `vendor_ota=None` instead of downloading ~2.3 GB into the RAM overlay.
3. **Initializer timeout.** `elvonos-waydroid-init.service` now has `TimeoutStartSec=600` and no longer blocks on a container restart; the initializer runs synchronously before `waydroid-container.service`.
4. **Graphics in QEMU.** The plain virtio-gpu has no 3D engine, so Android's SurfaceFlinger aborted with “Failed to open any DRM device”. The debug launcher now uses `-cpu max` (Waydroid requires SSSE3) and `virtio-gpu-gl-pci` + `sdl,gl=on` with host llvmpipe/GDK X11. The guest reports `features: +virgl +edid`; Android boots to the home screen and SurfaceFlinger stays up. Set `ELVONOS_QEMU_GL=0` for the old `virtio-gpu-pci`/GTK mode (screendump-based tests, no Android UI).

`build/phase7/waydroid-test-live.sh` verifies: initializer and container active, `images_path = /usr/share/waydroid-extra/images`, Android `sys.boot_completed=1`, SurfaceFlinger running, IP `192.168.240.112`, and a `grim` screenshot of the composited Android home screen. `grim` is installed in the image for guest-side screenshots (works with the GL display, where QEMU's own `screendump` is black).

### Aurora Store and microG

The image bundles Aurora Store 4.8.4 (F-Droid build), microG Services (GmsCore) 0.3.17 and microG Companion under `/usr/share/elvonos/waydroid/apps/`. The Waydroid desktop entry (`/usr/share/applications/Waydroid.desktop`) now executes `elvonos-waydroid`: it starts a **headless** Waydroid session (`waydroid session start`), waits for `sys.boot_completed=1`, and runs `elvonos-waydroid-apps.sh`. The installer is idempotent — it checks `pm list packages` and installs only missing packages — so the first Waydroid launch installs Aurora Store and microG automatically; later launches skip them. The Metro “Waydroid” tile uses the same desktop entry. No full-screen Waydroid window is left behind.

Signature spoofing: the official Waydroid VANILLA LineageOS 20 image does not define `android.permission.FAKE_PACKAGE_SIGNATURE`. microG therefore runs and its settings UI is available, but apps that enforce Google Play Services signature checks will not accept it. Full microG spoofing requires a patched system image (the official FOSS OTA channel is empty for x86_64). Aurora Store is independent of microG and works normally.

Waydroid runs in **multi-window mode**: the live initializer appends `persist.waydroid.multi_windows=true` to the Waydroid prop files, so Android apps open as individual labwc windows (`AppID=waydroid.<package>`). The Waydroid tile only starts the headless session and does **not** leave a full-screen window; the Aurora tile opens Aurora Store in its own window. The Desktop tile runs `elvonos-desktop` (a thin wrapper that toggles the `Win8Start` overlay closed). Win8Start synchronises the left switcher/taskbar with the Start state: showing Start hides it, hiding Start shows it on the desktop (`0004-start-switcher-sync.patch`; the `Win8Running --hide`/`--show` commands come from `0003-win8running-hide.patch`). So the desktop keeps its taskbar/switcher visible, while returning to Start does not leave the switcher open. A tile launch can no longer leave the tile stuck in its launch animation: a 1.5 s launch timeout plus a reset whenever Start is shown returns the tile to its model position and scale, which fixes the **Desktop** tile remaining enlarged/offset on the next Start (`0005-reset-launching-tiles.patch`). The Win8Start battery indicator was moved 28 px away from the user card (`build/win8de/patches/0002-battery-spacing.patch`).

The next executable step is Phase 1 on a Debian 13 build host with root, followed by a boot test on the target laptop or a Debian 13 VM. See `09-decisions-required.md`.

### APK installer and Android apps in the Win8DE app list

Android content now appears in Win8DE's **Apps** screen:

- `elvonos-waydroid-sync` reads `waydroid app list` while a session is running and writes one `.desktop` entry per app to `~/.local/share/applications/waydroid-<package>.desktop` (`Exec=elvonos-waydroid <package>`). Aurora Store keeps its real icon; other apps use the Waydroid icon. Entries for uninstalled apps are removed, but an empty app list never wipes existing entries while the container is still booting. The sync runs after the bundled-app installer, after the APK installer and on every `elvonos-waydroid` launch.
- Aurora Store is also shipped as a static entry (`waydroid-com.aurora.store.desktop`), so it appears in the Apps screen immediately, before Waydroid has ever started. Clicking it starts the headless session and opens Aurora.
- `/usr/share/applications/APK-Installer.desktop` is listed in the Apps screen and starts `elvonos-waydroid-install-apk`: a Zenity file picker for one or more `.apk` files, a progress dialog while Waydroid boots, installation via `waydroid app install`, and a refresh of the generated entries. APK files opened from Thunar are installed directly through the `application/vnd.android.package-archive` MIME association (`/home/elvon/.config/mimeapps.list`).
- For an APK whose package is not yet in the session list, `elvonos-waydroid-apk-entry` reads the package name from the binary `AndroidManifest.xml` inside the APK and creates the `.desktop` entry immediately, so the app appears without waiting for the Android framework.
- Win8Start rescans the application directories whenever the Apps screen is opened and watches `~/.local/share/applications` for live changes (`0006-apps-screen-refresh.patch`), so newly installed APKs show up without restarting the shell.

### Flathub, Bazaar and Warehouse

The image installs `flatpak` with `xdg-desktop-portal`/`xdg-desktop-portal-gtk` and adds the **Flathub** remote system-wide (and for the live user `elvon`). Two Flatpak apps are preinstalled in the system installation:

- **Bazaar** (`io.github.kolunmi.Bazaar`), the Flathub app store, and
- **Warehouse** (`io.github.flattool.Warehouse`), the Flatpak manager.

Because they are installed into `/var/lib/flatpak`, their exported `.desktop` files appear in the Win8DE Apps screen without any extra setup, and they start offline. `build/phase4/install-flatpak-apps.sh` adds the remote and installs both apps idempotently; Win8Start resolves their icons from the Flatpak hicolor export directories (`0007-flatpak-icons.patch`). Both apps use the `GSK_RENDERER=cairo` Flatpak override because GTK4's GL renderer cannot initialise on the QEMU virgl device (the aggregate renderer works on real hardware as well); the first start under TCG can take 30–45 s.

### Modern top taskbar and Start surface

The desktop shell was modernised in `0009-modern-desktop.patch` (which supersedes the earlier side-bar design from `0008`):

- the taskbar is now a slim **54 px top bar** with real frosted glass: pre-blurred wallpaper strips (`glass-top.png`) behind a translucent tint, a gloss band and bottom highlight; its layer-shell exclusive zone reserves the height, so windows start below it;
- left: a modern Start button with the 2×2 logo, followed by horizontal window chips (icon + title, accent bar for the focused window, hover close button);
- right: window count, live clock/date and a **Show desktop** button that minimises all windows;
- chips support click-to-focus, middle-click close, right-click activate-only and horizontal scrolling for many windows;
- the Start surface uses a dark scrim over the wallpaper, rounded 12 px tiles with subtle borders and more spacing, a 46 px title, a centred **Search apps** pill that opens the Apps search, a modern battery pill, a circular avatar and **All apps**/**Back** pills;
- the Apps screen got the same treatment: smaller modern title, rounded search field and rounded app rows;
- the bottom dock uses the same frosted-glass wallpaper strip (`glass-bottom.png`) with a rounded mask, gloss band and translucent border.

The tile entry animation can take a few seconds under QEMU/TCG; on real hardware it completes immediately. The taskbar and Start surface were verified with foot, Thunar and Bazaar windows open.

### Widget tiles for Start

`elvonos-win8start-defaults` now adds two live widget tiles in the free column right of the app grid (`0010-start-widgets.patch`):

- **System** shows CPU load, RAM usage and battery state; the values come from the new `SystemInfo` C++ context object in Win8Start, refreshed every two seconds from `/proc`.
- **Calendar** uses the bundled Merkuro Calendar live tile.

Live tiles hide the generic tile icon, badge and name label so the widget content is not overlaid. Tiles without a command (widgets) no longer trigger the launch animation when clicked. The Start window also keeps the taskbar process alive while it is hidden, so long Start sessions no longer spawn a second top bar.

### Desktop icons and bottom dock

A new Qt6/LayerShellQt helper, `elvonos-desktop-extras`, runs from the labwc autostart and provides two surfaces:

- **Desktop icons** on the Bottom layer. The icons from `~/Desktop` (and group folders) are arranged six per row and 24 per page at 1280x800; pages are switched by horizontal drag/swipe, mouse wheel or touchpad, with page dots and a snap animation. Double-click launches the entry (or opens a group folder in the Explorer); drag starts a `.desktop` drag for the dock. A right-click menu offers **Open, Copy, Rename, Group into folder, Delete (Trash), Properties and Uninstall**; Properties shows name, type, path, size, date, command, categories and the owning dpkg/Flatpak package, and Uninstall uses `apt-get remove`/`flatpak uninstall` with confirmation. Group folders move the selected icon into `~/Desktop/<group>` and appear as folder icons. Double-clicking a group opens a glass overlay with the applications it contains (friendly names and icons); clicking a tile launches the app, **Open in Explorer** reveals the folder in the file manager and Escape closes the overlay. Phase 4 installs the remaining applications into five initial group folders so the desktop stays clear for user files: **System** (Task Manager, Control Center, Event Viewer, Settings, System, Terminal), **Maintenance** (Defrag, Cleaner, Print & Scan), **Office** (Notepad, PDF Reader, Archiver), **Media & Graphics** (Gallery, Paint) and **Utilities** (Calculator, Files, Android). Explorer, Store, Screenshot and Media Player are dock-only and not duplicated on the desktop.
- **Desktop search**: a glass search pill at the top of the desktop finds installed applications (scanned once from the `.desktop` files) and files under Desktop, Documents, Downloads, Pictures, Music and Videos. Results are grouped into **APPLICATIONS** and **FILES** with icons and paths, limited to six apps and four files for speed. The field is typed directly on the desktop (the icons layer now uses `KeyboardInteractivityOnDemand`); arrow keys move the selection, Enter launches the app (`Exec`) or opens the file (`xdg-open`), Escape or a click clears the search. The results panel is capped at 560 px and shows a "no matches" hint.
- **Bottom dock** on the Top layer with an 86 px exclusive zone. It ships with the four primary applications **Explorer, Store, Screenshot and Media Player**; click launches, right-click removes, and dropping a `.desktop` file from the desktop or Thunar adds it. Dragging a dock icon **down onto the desktop** copies its `.desktop` file into `~/Desktop`, so it becomes a desktop shortcut. The list is persisted in `~/.config/elvonos/dock.json` and reset to these four defaults on a fresh image.
- **Drag the dock downwards** (grip pill at the top) to reveal the desktop: the dock follows the pointer, triggers `Win8Running --minimize` (minimise all windows) past a 26 px threshold, and springs back into place.

The app is built by `build/desktop-extras/build-desktop-extras.sh` and installed by phase 4.

### Taskbar, system tray and window grouping

The Win8Running taskbar (Qt/QML, LayerShellQt) was extended in `build/win8de/patches/0015-taskbar-tray-context-menu-grouping.patch`:

- **System tray** on the right with volume, network (wired/wireless/offline) and battery (when present) indicators refreshed every 15 s. Tooltips show the volume percentage, SSID/interface or charge; clicking opens `pavucontrol`, `nm-connection-editor` (or the Control Center), and the battery opens the Control Center.
- **Window chip context menu** (right-click on a running window): Activate, Minimize, Maximize/Restore, Close, Close all N windows, Task Manager and Taskbar settings. Middle-click still closes the window and the close button closes the focused member of a group.
- **Taskbar context menu** (right-click on the bar): Close active window, Minimize all windows, Task Manager and Taskbar settings.
- **Duplicate window management**: windows of the same application are grouped into one taskbar button with a count badge. Clicking the group cycles through its members (the focused window advances to the next duplicate); the menu can close the entire group. `list-windows` now assigns stable numeric IDs (written as `ID` in `windows.ini`) and accepts `--activate-id`, `--minimize-id`, `--maximize-id`, `--unmaximize-id`, `--close-id` and `--activate-only-id`, so identically titled windows can be addressed individually.
- **Taskbar settings** (`elvonos-taskbar-settings`, `NoDisplay`, same glass style): bar height 44/54/62 px, duplicate grouping on/off, system tray and the volume/network/battery icons, clock, window count and window titles. Changes are saved to `~/.config/elvonos/taskbar.json` and applied live through a file watcher; the layer-shell exclusive zone follows the selected height. Reset-to-defaults and a status line are included.
- The context menu is a second LayerShellQt overlay window (`Win8Running/ContextMenu.qml`) positioned below the clicked button; it hides after an action, on Escape or after nine seconds.

The settings dialog is built by `build/taskbar-settings/build-taskbar-settings.sh` and installed by phase 4.

### Settings

`elvonos-settings` is the central settings application (glass style, 1120x610) and replaces the old Settings launcher shortcut. It has eleven sections:

- **System**: OS, kernel, hostname (editable via `hostnamectl`), CPU, memory, disk and uptime plus the performance profile (powersave/balanced/performance) and ZRAM switch from `elvonos-tune`;
- **Network**: NetworkManager devices, state and connection names, IPv4 addresses, Wi-Fi and networking toggles, a Wi-Fi scan with connect/disconnect (SSID + password dialog) and a button for `nm-connection-editor`;
- **Devices**: default audio output/input selection with volume sliders and mute toggles, display outputs with selectable modes (`wlr-randr`), input devices, and a shortcut to Print & Scan; opens `pavucontrol`;
- **Apps**: searchable inventory of Flatpaks, packages installed through the Package Installer and Debian GUI applications (protected system components are marked **SYSTEM** and cannot be removed), uninstall with confirmation, a Package Installer shortcut, default applications for ten MIME types (`xdg-mime`), and user autostart entries (`~/.config/autostart`) with toggles;
- **Design**: wallpaper picker for `/usr/share/backgrounds/elvonos` and `~/Pictures` (writes `Wallpaper/Desktop` in the Win8Settings INI, which Win8Wall watches and reloads live) and a style preview;
- **Time & Language**: timezone via `timedatectl`, NTP toggle, language via `localectl` plus `environment.d`, and a keyboard layout selector (`XKB_DEFAULT_LAYOUT`);
- **Gaming & VR**: install buttons for WineHQ (falls back to the Debian Wine packages), Monado, WayVR, Steam, Lutris, MangoHud/GameMode and Winetricks (apt/Flatpak) with a live log; a toggle registers Wine as the default `.exe`/`.msi` handler (Explorer integration through `xdg-open`); Wine configuration and Wine-prefix shortcuts;
- **Firewall**: nftables protection toggle through `elvonos-tune` and a live ruleset viewer;
- **Privacy**: clear recent files, clipboard, thumbnails, shell history, the APT package cache and all application caches;
- **Updates**: `apt-get update`/`upgrade` with the upgradable package list and log;
- **Backups**: creates `~/Documents/Backups/ElvonOS-backup-<date>.tar.gz` archives of Desktop, Documents, Downloads, Pictures, Music, Videos and the ElvonOS config, with list, verify (`tar -tzf`), restore and delete.

The gaming actions live in `base/configuration/scripts/elvonos-gaming-setup`; the app is built by `build/settings/build-settings.sh`. The curated **Settings** icon in the System desktop group launches it.

**Languages:** the Settings interface is fully available in **English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Russian, Turkish, Ukrainian, Czech, Swedish, Simplified Chinese and Japanese** (15 languages). The language selector under *Time & Language* switches the UI live (no restart), translates all sections, dialogs and dynamic counts through embedded JSON dictionaries (`i18n/<code>.json`) and persists the choice in `~/.config/elvonos/language`; the `LANG` environment is auto-detected on startup. Noto CJK fonts and UTF-8 locales for every interface language are included in the image. The system locale for other programs remains configurable separately via `localectl`/`environment.d`.

**Shell personalisation and extended settings (2026-11-08):** the taskbar Start button no longer uses the Microsoft-style four-square mark; it now shows an ElvonOS "E" made of three gradient bars, coloured from the active theme. Taskbar and dock positions are switchable (top/bottom) and update live through layer-shell anchor changes; the taskbar height remains configurable. Eight theme presets (Aero, Aurora, Emerald, Sunset, Light, Rose, Mono, Cyber) plus a full custom editor change accent, secondary accent, background, panel, surface, text, muted-text and border colours, corner radius and glass strength; the editor includes wallpaper-image previews, a live preview, per-field colour values and JSON import/export/reset. Themes can also carry a custom background image with fill mode (fill/fit/stretch) and dimming, applied to Settings and the system wallpaper. Themes are written to `~/.config/elvonos/theme.json` and propagated to the Settings app, Win8DE Start menu/taskbar, dock, desktop search pill/results panel, Explorer search bar, GTK applications, labwc window borders/menus and the Start mark. Desktop group-folder labels (System, Maintenance, Office, Media & Graphics, Utilities) and "Open in Explorer" are translated through the shared `/usr/share/elvonos/i18n` dictionaries in all 15 interface languages. `elvonos-formfactor` runs before the shell starts and detects **PC, laptop, tablet or TV** from chassis type, battery, touchscreen and display size/DPI; it writes `~/.config/elvonos/formfactor.json` with scale, touch mode, taskbar/dock height, icon size, search width and TV overscan. The desktop icons, dock, search bar and Win8DE taskbar adapt live, and *Settings → System → Device profile* allows an automatic or manual override.

**Translation and theme audit (2026-11-08):** the shared dictionaries now contain **1110 keys per language**. Every first-party application (Store, Media Player, Control Center, Task Manager, Event Viewer, Notepad, Calculator, Paint, Gallery, Cleaner, Defrag, Print & Scan, Package Installer, Screenshot, Archiver and Taskbar Settings) loads `/usr/share/elvonos/i18n/<code>.json` at runtime through a common `AppLang` bridge, switches language live, and translates C++ status/error messages as well as QML labels. Settings status messages (including dynamic templates such as *Connected to %1* or *%1 installed*) are translated through the active language dictionary; desktop context menus, search bar, properties and group labels are localized; the Explorer UI (places, device list, toolbar, context menu and search field) is localized through the same files. All apps now use a shared `AppTheme` bridge and follow the complete theme (background, panels, content surfaces, text, muted text, accent 1/2, semantic green/red tones, borders, radius, glass and light/dark contrast) instead of staying dark in light/custom themes; the wallpaper dims automatically in light themes. The launcher names, generic names and comments of all first-party `.desktop` files carry `Name[...]`, `GenericName[...]` and `Comment[...]` translations, so the Start screen and application menus follow the selected language too. New settings close common Windows/Linux gaps: **Storage** (usage summary and Cleaner shortcut), **Accessibility** (large text and cursor size, applied through GTK/environment.d for new sessions) and **Network DNS servers** with apply/reset. Network settings gained **hotspot** start/stop, **flight mode**, **VPN** profiles (NetworkManager OpenVPN/WireGuard import and connect/disconnect) and the existing LAN/WLAN list. Devices gained **mouse/touchpad** settings (pointer speed, natural scrolling, tap-to-click, left-handed via labwc `<libinput>`), **Bluetooth** (BlueZ power, scan, pair, connect) and native **printer** management (queue list, default printer, test page, system-config-printer). System gained **power** settings (screen/suspend timeouts, battery state, suspend now; generated swayidle config with `wlopm`/`elvonos-dpms`) and **notifications** (fnott daemon with a glass theme, enable/disable, test and clear). Required packages (bluez-tools, NetworkManager OpenVPN/WireGuard, fnott, libnotify-bin, system-config-printer, cups-pk-helper, libinput-tools, swayidle, wlopm, rfkill) are installed by phase 4; `fnott`, `swayidle` and the new `elvonos-dpms` helper start from the labwc autostart.

**Waydroid integration in Rust (2026-11-09):** the shell/Python glue was replaced by a dependency-free Rust binary (`base/configuration/waydroid-rs`, built with `build/waydroid/build-waydroid-rs.sh` and installed as `/usr/bin/elvonos-waydroid`). It manages container/session startup, detects the session via `/proc` instead of the Python CLI, installs APKs natively through `pm install` inside the container, reads the package name straight from the binary `AndroidManifest.xml` (pure Rust AXML parser), discovers apps through `pm list packages -3` with a label cache, and regenerates localized Start-menu entries. It adds `status [--json]`, `doctor`, `recover`, `autostart on/off`, rotating logs in `~/.local/state/elvonos/` and `notify-send` feedback. Settings → Apps gained a **Waydroid** card with live session/app count, *Start Waydroid*, *Sync Android apps*, *Start Waydroid at login* and an installed-Android-app list with *Open*/*Uninstall*. A Rust **supervisor** (`elvonos-waydroid daemon`) can keep the session warm, install missing bundled apps and refresh entries; `stop` pauses it. The legacy helper names remain as thin wrappers. A native D-Bus session service (`elvonos-waydroid session`) now owns `id.waydro.Session` and calls `id.waydro.ContainerManager.Start`, replacing the Python `waydroid session start`; `waydroid status` reports it as a normal RUNNING session and `stop` tears it down. Only the multi-window app launcher and `waydroid init` still delegate to upstream 1.6.3. In QEMU, Waydroid now requires a Virgl context (`virtio-gpu-gl-pci` + `egl-headless`, `build/phase1/run-desktop-qemu-waydroid.sh`); without it SurfaceFlinger crashes and Android never completes boot. The Win8DE taskbar no longer hides itself when the Start button is clicked, so the Start button stays available while the Start screen is open.

**Waydroid end-to-end (2026-11-09, ISO `dc0f2ac7…`):** on QEMU for Windows with WHPX and Virgl (`build/phase1/run-desktop-qemu-whpx.ps1`) Android reaches `sys.boot_completed=1` in ~40–60 s (61 s on the final ISO), `elvonos-waydroid install AuroraStore-4.8.4.apk` finishes in ~4 s, `sync` extracts the real 800×800 APK icon into `~/.local/share/icons/elvonos/android/` and writes the Start-menu entry, Settings → Apps lists the app with icon/Öffnen/Deinstallieren, and the native launcher opens `com.aurora.store/.ComposeActivity` as a real multi-window window (~3 s). `install` now installs only the APKs it was given (the bundled Aurora/Play/microG set moved to `apps`), which removes the former multi-minute timeouts. A graded graphics profile (`elvonos-waydroid graphics auto|software|gpu`) manages the rendering path; `gpu` is the default, the software profile is diagnostic only because SurfaceFlinger still aborts with `output buffer not gpu writeable` on the first app window.

**Waydroid system integration (2026-11-09):** the integration now reaches beyond app launching. A systemd user unit `elvonos-waydroid.service` runs the supervisor with `Restart=on-failure`; `elvonos-waydroid autostart on` enables it and the labwc hook only acts as fallback. `elvonos-waydroid-bridge` starts Waydroid's upstream gbinder services `waydroidclipboard` and `waydroidnotifications` standalone (the native Rust session replaces the Python session manager that used to start them), using `wl-paste`/`wl-copy` as the host clipboard backend; it is started automatically and can be toggled in Einstellungen → Apps. New commands: `storage [--json]` (Android data usage and free space), `restart` (~21 s end-to-end) and `clear-data PACKAGE`. Einstellungen → Apps gained storage display, restart, the clipboard/notification switch, an Android app search and per-app "Daten löschen"; the Explorer mounts Android storage at startup, reports its state live and opens the Android app list with `--android-apps` (also wired to the desktop Android icon). A separate "APK installieren" desktop entry opens the native APK picker, and the flat application menu lists the Android entry so Win8Start shows it.

**Metro app windows (2026-11-10):** Einstellungen → Design has a new **APP-FENSTER** card with a *Metro-App-Fenster* toggle. `elvonos-appmode metro|desktop` writes `~/.config/elvonos/app-mode` and manages a marked `<windowRules>` block in `~/.config/labwc/rc.xml` (`<windowRule identifier="*" type="normal"><action name="Maximize"/></windowRule>`), then reloads labwc with the correct `LABWC_PID`. In Metro mode every normal application window fills the surface like the Windows 8.1 Metro apps; dialogs and the shell's layer surfaces (taskbar, Start screen) are unaffected. Desktop mode removes the rule again. Because the rule lives in the compositor, every launcher (Start tiles, dock, desktop icons, Explorer) follows the mode without changes. Verified with the Settings app: Metro mode maximized/surface-filling, desktop mode a normal movable window (screenshots `metro-window.png` / `desktop-window.png`).

**Desktop features (2026-11-10):** ElvonOS now ships its own terminal, **`elvonos-terminal`** (Qt Widgets, dependency-free): PTY via `forkpty`, a grid emulator with SGR/256/true colour, cursor movement, erase/insert/delete, scrollback (4000 lines), selection/copy, paste, mouse-wheel scrolling, OSC titles and a menu with *New Window*, *Android Shell* and *Copy/Paste*. `--command`/`-e`, `--working-directory`/`-d`, `--android` and `--title` are supported; the Android profile starts an interactive `lxc-attach` shell. The window follows the ElvonOS look: it reads the colours and radius from `~/.config/elvonos/theme.json`, uses a frameless rounded frame with a compact header (☰ menu, centred title, minimize/maximize/close) instead of the default widget menu bar, and the cursor uses the theme accent. It replaces foot in the Explorer context menu (*Open in Terminal*), the Win8Start default tiles (Terminal plus an **Android Shell** tile) and is the default terminal entry. **Multi-window:** `elvonos-waydroid multiwindow on|off` sets `persist.waydroid.multi_windows` and stores the preference; Einstellungen → Apps has a **Multi-Window** toggle (restart Waydroid to apply), and `status --json` reports the setting. **NTFS/storage:** `udisks2` was missing its daemon, so the Explorer's volume mounting could not work; `udisks2`, `ntfs-3g` and `exfatprogs` are now installed, `udisks2.service` is enabled and `ntfs3` is loaded at boot. **System sounds:** `elvonos-sound` (Python) plays per-event sounds from the freedesktop theme (Debian main, DFSG-free) and reads `~/.config/elvonos/sounds.json`; Einstellungen → Design has a **SYSTEMTÖNE** card with Test/Auswählen/Zurücksetzen per event (startup, notification, error, complete, lock), the login plays the startup sound and Waydroid notifications play the notification/error sound. **Cleanups:** the Gaming → Wine installer now uses the running Debian codename (trixie) for the WineHQ repository instead of the stale bookworm URL; **WayVR** is installed from its GitHub releases (`wayvr-org/wayvr`, x86_64 AppImage with extraction fallback when FUSE is unavailable) instead of Flathub, and the status check recognises the AppImage/binary; the Explorer path placeholder is `~/Documents` and the timezone placeholder is translated (`Continent/City`); the icon audit over 64 desktop entries found only the hidden Xwayland/Zenity helpers without icons, everything user-facing resolves.

**Health layer and UI audit (2026-11-10):** `elvonos-healthd` now collects memory, disk, load, failed systemd units, GPU render nodes and Waydroid state (container/session/booted/frozen, apps, bridge, graphics profile, data usage) every 15 s, publishes `/run/elvonos/health.json` (0644) for the UI and keeps the JSONL history in `/var/log/elvonos/health/`. It sends `WATCHDOG=1` to systemd — previously the 60 s watchdog would have killed the service every minute. New CLI `elvonos-health [--json]`. Einstellungen → System gained a **ZUSTAND** card with memory, disk, load, failed services, Waydroid, bridge and warnings, refreshed every 15 s. The translation audit over 360 UI strings found no missing user-facing text — only placeholders (`/path/to/folder`, `Europe/Berlin`), product names (Steam, Wine, Lutris, Monado, WayVR, Winetricks, Explorer, Waydroid) and symbols (›, ⏏, ▤, ⚙, ✕) remain untranslated; the new strings were added to all 14 languages (1137 keys each). Two UI fixes: the Android app row in Einstellungen → Apps no longer clips the **Deinstallieren** button, and the Explorer status bar uses correct singular/plural ("1 Android app"). The Android app list is also restricted to third-party packages, so preinstalled LineageOS apps no longer appear in the list while the status counts zero.

**Custom kernel (2026-11-10):** ElvonOS now ships its own kernel. `build/kernel/build-kernel.sh` builds Debian's `linux-source-6.12` (6.12.116) with the rootfs' Debian configuration and only three differences: `CONFIG_LOCALVERSION="-elvonos"`, debug info/BTF disabled and GDB scripts disabled. Binder, virtio-gpu/Virgl, amdgpu/i915, zram, audio, Wi-Fi and all filesystems stay at Debian's values. The script installs `vmlinuz-6.12.116-elvonos`, `System.map`, `config` and `/lib/modules/6.12.116-elvonos` into the rootfs, generates the initramfs in a chroot with `mkinitramfs`, removes the previous kernel (6.12.107) and its modules, and `build/phase7/build-iso.sh` now prefers `vmlinuz-*elvonos*`. `zstd` was added to the rootfs so the initramfs is compressed. The initramfs is deliberately built with `MODULES=most` so **all drivers needed on real hardware remain available**; that makes it 546 MB (496 MB uncompressed module cpio plus a 76 MB zstd main archive) and the ISO 5.8 GB. A trim hook that removes GPU/media/sound/InfiniBand/wireless from the initramfs was evaluated and rejected for now, because those modules keep the "boots on any hardware" property and are in any case present in `/lib/modules` for the running system.

**Waydroid backup/restore and bridge hardening (2026-11-10):** `elvonos-waydroid backup [FILE]` freezes Android for a consistent snapshot, writes the data directory as `tar.zst` (default `~/Backups/waydroid-<timestamp>.tar.zst`, verified at 3.1 MB for a fresh container) and unfreezes it; `restore FILE` stops session and container, extracts with root ownership and boots Android again (without an argument it opens a Zenity picker). Einstellungen → Apps has **Android-Daten sichern** and **Android-Daten wiederherstellen** buttons for both. The clipboard/notification bridge now takes an exclusive `flock` and exits via `os._exit` on SIGTERM, and `stop` uses SIGKILL — two `bridge start` calls leave exactly one process, `stop` leaves none. The default Win8Start tile layout uses an **Android** tile (metro android icon, opens the Android app list) instead of the old Waydroid tile. Notification forwarding was re-investigated: `com.android.systemui` does run in multi-window mode and the `waydroidnotifications` service registers, but Android does not forward notifications through it, so notification forwarding remains an Android-side task; clipboard sync is unaffected.

**Waydroid deep integration (2026-11-10, ISO `dc0f2ac7…` → final build):** power, intents and file hand-over are now part of the OS. `elvonos-waydroid freeze`/`unfreeze` suspend the container through the container manager and `status` reports `Android: frozen` (plus a `frozen` field in `--json`) without probing the frozen container: read-only probes run through `lxc_probe` with a 15 s timeout and frozen state is detected with `lxc-info`, so a frozen Android can never hang status calls (measured: 68 ms). `elvonos-waydroid-lock` wraps `Win8Lock` and is used by the generated swayidle configuration, so Android freezes while the desktop is locked and resumes on unlock. `elvonos-waydroid open FILE` copies a host file into Android's `Download` folder (with the container's media ownership), triggers a media scan and fires `ACTION_VIEW` (MediaStore `content://` URI with `file://` fallback); the Explorer context menu now has **Mit Android öffnen**. `elvonos-waydroid share TEXT` starts an `ACTION_SEND` intent (targets depend on the installed Android apps).

### Explorer

`elvonos-explorer` is a Qt6/QML file manager styled like the rest of the shell:

- Linux filesystem browsing with a places sidebar (Home, Desktop, Documents, Downloads, Pictures, Music, Videos, File system), grid and list views, breadcrumb path, search, hidden-file toggle, new-folder/new-file dialogs, rename/delete actions and free-space display;
- multi-selection (Ctrl+click, Shift+range, Ctrl+A, Esc) with selection-aware context menu and status-bar selection count;
- clipboard actions (Ctrl+C/X/V) with recursive folder copy, conflict-safe names such as `name (copy)`, cut-and-move support and a paste button that appears while the file clipboard is filled;
- safe Trash handling (`QFile::moveToTrash` with a `~/.local/share/Trash/files` fallback), permanent delete (Shift+Delete) and a confirmation dialog for several items;
- properties dialog (name, type, location, size, modified, permissions, owner, group, symlink target), path entry (Ctrl+L), keyboard navigation (arrows, Home/End, Enter), Ctrl+wheel icon zoom, ascending/descending sort and image thumbnails;
- dark context menu, tooltips with name/size/date, and persistent view settings (grid/list, sort mode, sort direction, hidden files, icon size) in `QSettings`;
- client-side window controls in the toolbar (minimize, maximize/restore, close) plus a dedicated drag grip, because the Win8DE labwc theme disables server-side decorations for all windows;
- keyboard shortcuts (F5 refresh, Ctrl+H hidden files, Ctrl+N new folder, Ctrl+Shift+N new file, F2 rename, Delete, Shift+Delete permanent, Backspace up, Alt+Left/Right history, Ctrl+L path entry, Ctrl+F search) and tooltips on the toolbar;
- accepts an optional directory argument (`elvonos-explorer /path/to/folder`), which the desktop uses to open group folders; files open in their parent directory;
- **Android apps** view from the generated `waydroid-*.desktop` entries with its own search filter; clicking an app starts it through `elvonos-waydroid`;
- **Android storage** via the user-level `elvonos-waydroid-storage` bindfs helper that exposes `/var/lib/waydroid/data/media/0` as `/run/elvonos/waydroid`; it never blocks the boot and is invoked on demand from the sidebar (with status feedback if Waydroid has not initialised yet);
- **Drives / USB media** in a "DEVICES" sidebar section, enumerated from `lsblk -J` (label, size, filesystem, mount state) and refreshed every four seconds. Mounted volumes open on click; unmounted internal partitions and USB sticks are mounted through `udisksctl` (udisks2, installed in the image) and USB volumes can be ejected with the ⏏ button. `/etc/polkit-1/rules.d/49-elvonos-udisks.rules` lets the live user mount and unmount local filesystems without a polkit authentication agent;
- a desktop entry (`/usr/share/applications/elvonos-explorer.desktop`) adds it to the Apps screen and it is pinned first in the bottom dock.

The Explorer window opens at 1120x610; a labwc window rule (`identifier="elvonos-explorer"`) resizes it and places it at 80,70 so the toolbar stays below the 54 px taskbar and the status bar above the dock. `build/win8de/patches/0014-win8running-watch-windows-ini.patch` makes the taskbar watch the `~/.config/list-windows` directory and retry the INI load, because `list-windows` only creates `windows.ini` when the first window appears. Without that retry the taskbar kept showing "No open windows" and Explorer was not recognised as a window.

The Explorer is built by `build/explorer/build-explorer.sh` and installed by phase 4.

### Task Manager

`elvonos-taskmanager` is a Qt6/QML system monitor in the same glass style as the Explorer:

- **Linux tab** with all processes from `/proc` (name, PID, user, CPU %, RSS, state), sorted by CPU by default, with sortable columns (name/CPU/RAM/PID), live search, two-second refresh and a running summary (CPU %, cores, load average, RAM used/total, process count, uptime);
- **Android tab** for Waydroid: Android processes are recognised from their `/system`, `/apex`, `/vendor` command lines and the `lxc.payload.waydroid` cgroup; app processes are shown by package name with their CPU/RAM usage;
- end tasks with SIGTERM (`End task`) or SIGKILL (`Force kill`); Android apps are stopped through `am force-stop <package>` when a package name is available, using the passwordless sudo rule from the live image;
- toolbar tabs (`Ctrl+1`/`Ctrl+2`), search (`Ctrl+F`), refresh (F5), window controls and drag grip, dark dialogs, keyboard shortcuts;
- installed as `/usr/share/applications/elvonos-taskmanager.desktop`, part of the default dock and the Start app list.

The Task Manager is built by `build/taskmanager/build-taskmanager.sh` and installed by phase 4.

### Gallery

`elvonos-gallery` is a photo browser and viewer in the same glass style:

- **Linux library** with recursive image discovery for Pictures, Desktop, Downloads and the ElvonOS wallpaper folder (PNG/JPG/WebP/GIF/BMP/AVIF/SVG/TIFF, newest first, 1500-image cap, live directory watcher);
- **Android library** for Waydroid photos: Camera (`DCIM/Camera`), Pictures, Screenshots and Download, exposed through the `elvonos-waydroid-storage` bindfs helper; the app initialises the storage on start and falls back to `/var/lib/waydroid/data/media/0` when the mount is not ready;
- thumbnail grid with search, album sidebar, keyboard navigation (arrows/Enter), F5 refresh, Ctrl+1/Ctrl+2 source switching and Ctrl+F search;
- full-window viewer with previous/next, mouse-wheel zoom (50–500 %), image name/size/date/zoom in the header, Esc to close and its own minimize/maximize/close buttons and drag grip;
- installed as `/usr/share/applications/elvonos-gallery.desktop`, part of the default dock and the Start app list.

The Gallery is built by `build/gallery/build-gallery.sh` and installed by phase 4.

### Paint

`elvonos-paint` is a raster drawing application in the same glass style:

- brush, eraser, line, rectangle, ellipse, flood-fill, **eyedropper** and **text** tools with a 12-colour palette plus custom colour dialog and eight recent colours, brush size 1–60 px, a filled-shape toggle and a live cursor/brush preview;
- 1280×800 canvas with anti-aliased drawing, live shape preview while dragging, 16-state undo/redo history, clear with confirmation and a dark sidebar;
- **layer support** with a stacked layer list (top-first), visibility toggles, per-layer opacity, add/duplicate/delete/raise/lower, rename (double-click), "add image as layer", and composite rendering/saving;
- **canvas transforms** (rotate 90°, flip horizontal/vertical, resize with a width/height dialog) and **view zoom/pan** (25–800 %, mouse wheel, middle-button drag, Fit button);
- open existing images from `~/Pictures` in a thumbnail picker (document or as a new layer), save quick PNG snapshots (`Ctrl+S`) or save under a chosen name as PNG or JPEG to `~/Pictures`;
- keyboard shortcuts (B/E/L/R/O/F/I/T tools, Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y undo/redo, Ctrl+S save, Ctrl+Shift+S save as, Ctrl+O open, Ctrl+Shift+N new layer, Ctrl+Shift+D duplicate layer, Ctrl+Shift+L toggle layers panel, Ctrl+0 fit view, Ctrl+Alt+R rotate, Ctrl+Shift+H/V flip), own minimize/maximize/close buttons and drag grip;
- installed as `/usr/share/applications/elvonos-paint.desktop`, part of the default dock and the Start app list.

The Paint application is built by `build/paint/build-paint.sh` and installed by phase 4.

### Notepad

`elvonos-notepad` is a plain-text editor in the same glass style:

- frameless 1120×610 window with the shared title bar, drag grip and minimize/maximize/close buttons;
- **New / Open / Save / Save As**, word-wrap toggle, font size 9–40 px and a monospace editor with tab insertion (four spaces);
- **find & replace bar** (`Ctrl+F` / `Ctrl+H`) with case-sensitive toggle, live match count, next/previous, Replace and Replace All; **Go to line** (`Ctrl+G`); insert date/time (`F5`); recent files in the open dialog;
- custom open/save browser with directory navigation (Up, Home, Documents, editable path), folder-first listing, file sizes and a save filename field; all file I/O is UTF-8 and written atomically via `QSaveFile`;
- modified indicator in the title bar and status bar, `Ln/Col`, word/character counts and error messages; unsaved-changes dialog with Save/Discard/Cancel on New/Open/Close;
- keyboard shortcuts (`Ctrl+N/O/S`, `Ctrl+Shift+S`, `Ctrl+Q/W`, `Ctrl++/-`);
- runs on the Qt Quick **software renderer** so its first frame appears immediately even on virtualised GPUs;
- installed as `/usr/share/applications/elvonos-notepad.desktop`, default handler for `text/plain` and part of the default dock and the Start app list.

The Notepad is built by `build/notepad/build-notepad.sh` and installed by phase 4.

### Media Player

`elvonos-media` plays music and videos in the same glass style:

- Qt Multimedia (GStreamer) playback of common audio/video formats with `VideoOutput` for video and an audio placeholder with the track title/artist for music;
- **playlist** with add-file browser, "Add folder" (all supported files), remove/clear, move up/down, URL input, current-item highlight, automatic next on end-of-media and **persistence across sessions** (paths and last index are stored via QSettings);
- **shuffle**, **repeat off/all/one**, playback speed 0.5–2.0× (button and `[`/`]`), and a **sleep timer** (15/30/60/90 min with countdown in the button);
- seek bar with draggable handle, play/pause/stop/previous/next, volume slider, mute and fullscreen toggle; volume, mute and playback mode are remembered;
- title/artist metadata when available, duration/position display and error messages in the status area;
- keyboard shortcuts (`Space`, arrow keys for seek/volume, `M`, `F`, `Ctrl+O`, `Ctrl+Q/W`), drag grip and own window controls;
- supports opening a file from the command line/Explorer (`elvonos-media file.mp4`), installed as `/usr/share/applications/elvonos-media.desktop`, default handler for MP4/MKV/MP3/FLAC, in the default dock and the Start app list.

The Media Player is built by `build/media/build-media.sh` and installed by phase 4.

### Calculator

`elvonos-calculator` is a standard/scientific calculator in the same glass style:

- large right-aligned display with the running expression and a memory indicator;
- digits, decimal comma, `+ − × ÷`, `=`, `%`, sign toggle, backspace and clear;
- **scientific mode** (toggle in the title bar or `Ctrl+E`): `sin`/`cos`/`tan` with **2nd** inverse functions (`asin`/`acos`/`atan`), `ln`/`log` and `e^x`/`10^x`, `√`/`∛`, `x!`, `π`, `e`, `x^y`, and a **DEG/RAD** switch; standard-mode quick keys `√`, `x²`, `1/x`, `π`;
- memory keys `MC`, `MR`, `M+`, `M−`;
- **history panel** with the last 60 calculations; clicking a result reuses it;
- full keyboard input (digits, `+ - * /`, comma/period, `Enter`, `Backspace`, `Esc`, `F9` for sign) plus `Ctrl+Q/W`;
- own window controls and drag grip; installed as `/usr/share/applications/elvonos-calculator.desktop`, in the default dock and the Start app list.

The Calculator is built by `build/calculator/build-calculator.sh` and installed by phase 4.

### Screenshot

`elvonos-screenshot` captures the desktop in the same glass style:

- **Full screen** or **region** (interactive `slurp` selection), delay 0/3/5/10 s, optional cursor and PNG/JPEG output;
- automatic timestamped files in `~/Pictures/Screenshots`;
- **preview** of the last capture with **Copy** (`wl-copy`), **Open** (Gallery) and **Delete** (with confirmation);
- **recent screenshots** grid with thumbnails, date and size; click loads a capture into the preview;
- status messages, busy indicator, window controls and drag grip; `F5` refreshes the history, `Ctrl+Q/W` closes;
- installed as `/usr/share/applications/elvonos-screenshot.desktop`, in the default dock and the Start app list.

The Screenshot tool is built by `build/screenshot/build-screenshot.sh` and installed by phase 4.

### Archiver

`elvonos-archiver` manages ZIP and TAR archives in the same glass style:

- **Open/browse** ZIP, TAR.GZ, TAR.XZ, TAR.BZ2 and TAR archives with an entry table (name, size, date, folders);
- **extract all** to an editable destination (default `~/Downloads/<archive name>`), with a busy indicator and status/error line;
- **create archives** from files and folders with ZIP, TAR.GZ or TAR format, a destination folder/name, add-file/add-folder browser and a source list with remove;
- built-in file browser for opening archives and adding sources; toolbar with Open, Refresh and Close; `F5` refresh, `Ctrl+O` open, `Ctrl+Q/W` close;
- installed as `/usr/share/applications/elvonos-archiver.desktop`, in the default dock and the Start app list.

The Archiver is built by `build/archiver/build-archiver.sh` and installed by phase 4.

### PDF Reader

`elvonos-pdf` reads PDF documents in the same glass style:

- open PDFs through a built-in file browser (folders + `.pdf` files) with **recent documents** chips;
- page navigation with **previous/next**, a page-number field, `Home`/`End`, and a page counter;
- **zoom 25–300 %** (`+`/`-`), **Fit width**, **Fit page** (default on open) and **Reload**; arrow keys for pages, `F5` reload, `Ctrl+O` open, `Ctrl+Q/W` close;
- pages are rendered with **pdftoppm** at 140 DPI and cached in `/tmp/elvonos-pdf`, displayed in a scrollable, centred viewer with the document path and page status;
- installed as `/usr/share/applications/elvonos-pdf.desktop`, default handler for `application/pdf`, in the default dock and the Start app list.

The PDF Reader is built by `build/pdf/build-pdf.sh` and installed by phase 4.

### Print & Scan

`elvonos-printscan` combines printer and scanner management in the glass style:

- **Printers** tab: lists CUPS printers with their state and default badge, set-default and print-test-page actions, a live print queue with per-job cancel, plus a shortcut to the CUPS web interface (`http://localhost:631`);
- **Scanner** tab: lists SANE devices (`scanimage -L`), resolution 100/200/300/600 dpi, Color/Grayscale, and a scan action that writes timestamped PNG files to `~/Pictures/Scans`; the last scan is previewed with Open/Open-folder actions;
- `F5` refreshes, `Ctrl+1/2` switch tabs, busy indicator and status footer; CUPS is installed and `cups.socket` is enabled;
- installed as `/usr/share/applications/elvonos-printscan.desktop`, in the default dock and the Start app list.

The Print & Scan tool is built by `build/printscan/build-printscan.sh` and installed by phase 4.

### Event Viewer

`elvonos-eventviewer` shows the systemd journal in the glass style:

- reads the last 800 entries as JSON via `journalctl` (passwordless `sudo -n` for the system journal, with a plain fallback), newest first, for the current boot or all boots;
- **sources**: All events, System services (`_SYSTEMD_UNIT`), Kernel (`_TRANSPORT=kernel`), Authentication (sshd/sudo/logind/polkit) and Applications;
- **level filters** All/Errors/Warnings/Info, live text search, and a Live toggle that refreshes every 5 seconds;
- event list with time, severity dot, message, identifier/unit and source; the detail panel shows level, time, source, unit, identifier, PID, host and boot ID plus the full message;
- **Copy** puts the selected message on the clipboard, **Save log** exports the visible events to `~/Documents/ElvonOS-events-<date>.log`; `F5` refreshes, `Ctrl+F` focuses the search, `Ctrl+Q` closes;
- installed as `/usr/share/applications/elvonos-eventviewer.desktop`, part of the desktop shortcuts, the default dock and the Start app list.

The Event Viewer is built by `build/eventviewer/build-eventviewer.sh` and installed by phase 4.

### Package Installer (AppImage and .deb)

Double-clicking a `.deb` or AppImage (registered as `application/x-appimage`) opens `elvonos-package-installer`:

- `.deb`: shows package name, version and description (read with `dpkg-deb`), with a confirmation dialog and an **Install package** action that runs `sudo -n apt-get install -y ./<file>` and displays the full apt log;
- AppImage: shows the file details and a **Run application** action that makes the file executable and starts it detached;
- both offer "Open folder"; the handler is hidden from menus (`NoDisplay=true`) and only appears for its file types;
- built by `build/package-installer/build-package-installer.sh`; the MIME definition lives in `base/configuration/mime/elvonos-appimage.xml`.

### Defrag

`elvonos-defrag` is a disk optimizer in the same glass style:

- lists mounted filesystems from `lsblk` (label, device, filesystem, size, free space, mount point) with a support badge;
- **ext4 analysis** (`e4defrag -c`) and **defragmentation** (`e4defrag`); btrfs (`btrfs filesystem defragment -r`) and XFS (`xfs_fsr`) are used when their tools are present;
- **TRIM** for mounted filesystems via `fstrim -v`;
- asynchronous execution with a live monospace log, busy indicator, task text, result line, cancellation and a confirmation dialog before defragmenting;
- volume list keyboard navigation (`Up`/`Down`), `Ctrl+Shift+A` analyze, `Ctrl+Shift+D` defragment, `Ctrl+Shift+T` TRIM, F5 refresh, window controls and drag grip;
- installed as `/usr/share/applications/elvonos-defrag.desktop`, part of the default dock and the Start app list.

The Defrag tool is built by `build/defrag/build-defrag.sh` and installed by phase 4.

### Cleaner

`elvonos-cleaner` frees disk space in the same glass style:

- category list with sizes and checkboxes: **Application cache** (`~/.cache`), **Trash**, **Temporary files** (user files in `/tmp` and `/var/tmp` older than 24 h), **APT package cache** and **rotated logs**;
- safe defaults: only application cache and Trash are preselected; the system categories are opt-in;
- scan on start and via F5, live selection/reclaimable summary, confirmation dialog, live log and a "last cleaned" figure;
- synchronous cleanup with direct deletion for user data and passwordless `sudo -n` (`find … -delete`) for the APT cache and rotated logs;
- keyboard: `Ctrl+Shift+C` opens the confirmation, window controls and drag grip;
- installed as `/usr/share/applications/elvonos-cleaner.desktop`, part of the default dock and the Start app list.

The Cleaner is built by `build/cleaner/build-cleaner.sh` and installed by phase 4.

### Performance & Protection

`elvonos-tune` is the root helper behind the Control Center and the boot service `elvonos-tune.service`:

- **profiles** Balanced / Performance / Powersave: CPU governor (schedutil/performance/powersave when cpufreq is available), energy-performance preference, `vm.swappiness`, `vm.vfs_cache_pressure` and dirty ratios;
- **ZRAM**: creates/activates a zstd-compressed swap device sized at 50 % of RAM (falls back to lz4hc/lzo), and can disable/reset it;
- **Waydroid protection**: caps the Android container cgroup at 75 % of RAM (`memory.high`) and raises its `cpu.weight` to 200; removing the limit restores `max`/100;
- **firewall**: an nftables `inet elvonos` table with a default-drop input policy that allows loopback, established/related traffic, ICMP/ICMPv6, DHCP replies and SSH (tcp/22);
- state is stored in `/var/lib/elvonos/tune.state`; the boot service re-applies the saved profile, ZRAM and firewall (defaults: balanced, ZRAM on, firewall on).

`elvonos-control` is the matching Control Center app with three tabs:

- **Performance**: CPU governor, memory/swap/ZRAM/load cards, profile buttons, ZRAM and Waydroid-protection toggles;
- **Protection**: firewall status and enable/disable action, Waydroid container state and memory limit, list of allowed inbound traffic and a short explanation of the layered setup;
- **Audio**: noise-protection status/toggle, the active default microphone and a restart action, plus an explanation of laptop interference;
- live status refresh (5 s), passwordless-sudo actions, result/busy footer, window controls and drag grip.

### Audio noise protection

Laptop boards place the HDA codec close to the GPU/CPU power stages, which can couple electrical noise into the audio path. ElvonOS ships software-side mitigation:

- **PipeWire noise suppression**: `libpipewire-module-echo-cancel` with the WebRTC backend (`webrtc.noise_suppression`, high-pass filter, gain control) creates the virtual **ElvonOS Noise-Free Microphone** (PipeWire node `echo-cancel-source`); WirePlumber prefers it as the default source;
- **stable buffering**: 48 kHz with a 1024-frame quantum (min 256/max 2048) avoids underrun crackle at the cost of ~21 ms latency;
- **no codec power-save**: `/etc/modprobe.d/elvonos-audio.conf` sets `snd_hda_intel power_save=0 power_save_controller=N`, and WirePlumber disables ALSA suspend-on-idle, removing the typical power-state pops/clicks;
- `elvonos-audio-noise on|off|status|restart` toggles the noise configuration by renaming the drop-in to `*.disabled` and restarting the user PipeWire/WirePlumber stack; the Control Center Audio tab drives it and shows the default source;
- hard electrical coil whine that persists in silence cannot be removed in software; the Audio tab documents the headphone/external-DAC workaround.

The helper is installed by phase 4 and enabled as a boot service; the app is built by `build/control/build-control.sh` and installed with a desktop entry, dock and Start entry.

### Store

`elvonos-store` combines Linux and Android app sources in one glass-style window:

- **Linux tab**: Flathub catalog via `flatpak remote-ls flathub --app`, installed apps via `flatpak list --app`; installed entries are shown first with an **Open** button and a remove action, other catalog entries offer **Install**; install/uninstall use `flatpak install -y` / `flatpak uninstall -y` with a live status line, and installed-only apps are merged in when the remote catalog is unavailable. A cached catalog is shipped in `/usr/share/elvonos/flathub-catalog.tsv` (generated at image build), so the Store still lists ~3,400 apps offline;
- **Android tab**: lists the installed Waydroid apps from the generated `waydroid-*.desktop` entries with icons and **Open**, plus an Aurora Store banner whose **Open Aurora Store** button starts the Android store for new installs and updates;
- search filters both catalogs, tabs show the current counts, F5 refreshes, `Ctrl+1`/`Ctrl+2` switch tabs, and the usual window controls/drag grip are included;
- installed as `/usr/share/applications/elvonos-store.desktop`, part of the default dock and the Start app list.

The Store is built by `build/store/build-store.sh` and installed by phase 4.

### Boot splash and shell shortcuts

The live image boots with a Plymouth theme named `elvonos`: a dark 1920×1080 backdrop, an **Inter Display SemiBold** wordmark with a white→ice-blue gradient and a soft blue halo, a "Performance · Protection · Android" subtitle and an orbiting eight-dot spinner. The spinner advances once every ~0.36 s (one revolution every ~2.9 s) instead of changing on every frame, and `glow.png` is layered behind the wordmark with a slow two-thump heartbeat (2.4 s cycle) that makes the backdrop breathe. The theme is installed into the initramfs, and the GRUB entries use `quiet splash plymouth.ignore-serial-consoles` so the graphical splash is shown on tty0 while the serial console remains available for debugging. `virtio_gpu` is added to `/etc/initramfs-tools/modules` so VMs get an active KMS scanout for the splash. Files live in `base/configuration/plymouth/elvonos/`; the theme is installed and the initramfs regenerated by phase 4.

Plymouth hands over to `elvonos-splash`, a small Qt6/Quick bridge (`base/configuration/splash/`, built by `build/splash/build-splash.sh`) started first from the labwc autostart. It shows the same background, wordmark, heartbeat halo and spinner in a frameless full-screen window while the Win8DE shell starts, then fades out when `Win8Running` and `Win8Start` are running (the `/tmp/elvonos-desktop-ready` marker written at the end of the autostart is accepted as an additional signal). It is deliberately a **normal window with `QT_QUICK_BACKEND=software`**: Qt Quick's OpenGL scene graph needs several seconds for its first frame on virtualised GPUs, and layer-shell overlays are not reliably composited by labwc in those VMs. Minimum display time is 4 s, grace after readiness 3 s, failsafe 20 s; this removes the visible gap between Plymouth and the first rendered desktop frame.

With the unified Store in place, the Start Metro layout now shows a **Store** tile in the former Aurora slot, and the standalone Aurora and Bazaar entries were removed from the default dock (existing `dock.json` files are filtered on load).

The default Start layout was also adjusted: Aurora takes the former Foot slot, Desktop takes the large former Bulk Rename slot, and Foot/Bulk Rename move to the former Aurora/Desktop slots.

### Live installer and update system (2026-11-10)

- **`elvonos-installer`** (Bash + Zenity) installs the running live system to a
  GPT disk: BIOS boot + 512 MiB EFI + ext4 root, `rsync -aHAXx` copy,
  kernel/initrd from the live medium, fresh `machine-id` and SSH host keys,
  GRUB for UEFI and BIOS, plus a `grub-mkstandalone` fallback at
  `EFI/BOOT/BOOTX64.EFI`. See `13-live-installer.md`.
- **Verified in QEMU/WHPX**: install from ISO to `/dev/vda`, then boot from the
  disk — kernel `6.12.116-elvonos`, `/dev/vda3` ext4, `/dev/vda2` vfat,
  `systemctl is-system-running` = `running`, 0 failed units, SSH/Healthd/
  Waydroid active.
- **Free update system**: minisign key pair in `~/.config/elvonos/keys`
  (public key `RWS/qURuN49P6KiggSTz8FJLVushtqbyI/32lPvZgJzPklLsEu7oEgPk`),
  static signed feed at
  `https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json`
  with a Codeberg mirror, and `elvonos-update check|download|apply`
  (user cache, `curl` + `minisign` + `jq`). The Settings **ELVONOS UPDATES**
  card drives the same client.
- **Published release 1.0.7**: ISO
  `ae7a725ce5bf9de2d00c947192d6abd3b2d8a84591b3d0a51ead958b24b97cff`
  (6,222,405,632 B) on SourceForge
  (`/home/frs/project/elvonos/releases/1.0.7/`) with `.minisig`,
  `SHA256SUMS` and `SHA256SUMS.minisig`; includes the 1.0.7 software line
  (`elvonos-apps 1.0.7-7`), auto-update units and the fixed Start layout.
- **Update layers (1.0.1)**: Debian OS packages (`apt-get upgrade`), ElvonOS
  software as signed `.tar.zst` payloads, signed script components (first:
  `flatpak-store` / Flathub setup), Flatpak metadata refresh, ISO for
  kernel/bootloader changes.
- **Update test (2026-11-11, 1.0.7)**: fresh 1.0.7 install → `check` reported
  11 OS updates, `flatpak-store` and `zz-auto-updates` → `apply` upgraded
  Debian packages, configured Flathub and enabled the auto-update units →
  final `check` returned `"update": false`, `"os_updates": 0`,
  `"components": []`. Feed primary: SourceForge; fallbacks: GitHub and
  Codeberg. APT failures do not abort component updates.
- **Software update 1.0.4-2**: Settings → Updates now shows the last check
  time, OS/component counts, a live log and the ISO hint; `elvonos-update log`
  reads user/root logs. Delivered as a signed payload on top of 1.0.3.
- **Source code published (2026-11-11)**: GitHub
  <https://github.com/ElvonOS/elvonos> (primary), Codeberg mirror
  <https://codeberg.org/ElvonOS/elvonos>, and a signed
  `ElvonOS-1.0.7-src.tar.zst` in the SourceForge release directory.
- **Next release (planned)**: **1.0.4** — remaining hardening (U6 test matrix),
  delta ISO updates, channels, Store update-all and SBOM. Details:
  `documentation/17-release-plan.md`.
