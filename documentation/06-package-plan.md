# 06 — Exact Package Installation Plan

All versions below were read from the official Debian 13.7 archive on **2026-11-01**. They are a snapshot, not a promise that the archive will never change. The ISO build must pin a Debian snapshot date and record the resolved versions.

---

## 1. Repository configuration

### Target and build host

```
# /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
```

Do **not** enable `trixie-backports` globally. Do **not** add Debian unstable. ElvonOS custom packages go into a separate signed repository.

---

## 2. Target base packages

### 2.1 Core system

| Package | Version |
|---|---|
| `systemd` | 257.13-1~deb13u1 |
| `systemd-sysv` | 257.13-1~deb13u1 |
| `dbus` | 1.16.2-2 |
| `dbus-user-session` | 1.16.2-2 |
| `udev` | 257.13-1~deb13u1 |
| `kmod` | Trixie |
| `initramfs-tools` | 0.148.4 |
| `linux-image-amd64` | 6.12.107-1 |
| `linux-headers-amd64` | 6.12.107-1 |
| `linux-base` | 4.12.1 |
| `firmware-linux-free` | Trixie main |
| `grub-efi-amd64` | 2.12-9+deb13u2 |
| `grub-efi-amd64-signed` | 1+2.12+9+deb13u2 |
| `shim-signed` | 1.51~1+deb13u1+16.1-2~deb13u1 |
| `efibootmgr` | Trixie |
| `dosfstools` | 4.2-1.2 |
| `e2fsprogs` | 1.47.2-3+b12 |
| `parted` | 3.6-5 |
| `gdisk` | 1.0.10-2 |
| `cryptsetup` | Trixie (if encrypted install is offered) |
| `btrfs-progs` | 6.14-1 (only if btrfs is selected) |

### 2.2 Networking

| Package | Version |
|---|---|
| `network-manager` | 1.52.1-1 |
| `wpasupplicant` | Trixie |
| `wireless-regdb` | Trixie |
| `dnsmasq-base` | Trixie |
| `iproute2` | Trixie |
| `nftables` | 1.1.3-1 |
| `iptables` | 1.8.11-2 |
| `bluez` | Trixie |
| `bluez-firmware` | Trixie (if present) |

### 2.3 Audio

| Package | Version |
|---|---|
| `pipewire` | 1.4.2-1 |
| `pipewire-pulse` | 1.4.2-1 |
| `wireplumber` | 0.5.8-2 |
| `alsa-utils` | 1.2.14-1 |
| `libspa-0.2-bluetooth` | Trixie |
| `firmware-sof-signed` | 2025.01-1 |

### 2.4 Graphics

| Package | Version |
|---|---|
| `libgl1-mesa-dri` | 25.0.7-2+deb13u1 |
| `mesa-vulkan-drivers` | 25.0.7-2+deb13u1 |
| `mesa-utils` | 9.0.0-2+b2 |
| `vulkan-tools` | Trixie |
| `libegl1` | Trixie |
| `libgles2` | Trixie |
| `libgbm1` | 25.0.7-2+deb13u1 |
| `libdrm2` | 2.4.124-2 |
| `xwayland` | 2:24.1.6-1 |

### 2.5 Firmware and microcode (non-free-firmware)

| Package | Version |
|---|---|
| `firmware-linux` | 20250410-2 |
| `firmware-amd-graphics` | 20250410-2 |
| `firmware-mediatek` | 20250410-2 |
| `firmware-realtek` | 20250410-2 |
| `firmware-misc-nonfree` | 20250410-2 |
| `firmware-sof-signed` | 2025.01-1 |
| `firmware-nvidia-gsp` | 550.163.01-2 |
| `firmware-nvidia-graphics` | 20250410-2 |
| `amd64-microcode` | 3.20250311.1 |
| `intel-microcode` | 3.20251111.1~deb13u1 |

Install `amd64-microcode` on AMD systems. Install `intel-microcode` only on Intel systems. Do not install both unconditionally; the installer/hardware service should select the correct one.

### 2.6 Security and container base

| Package | Version |
|---|---|
| `apparmor` | 4.1.0-1 |
| `apparmor-profiles` | 4.1.0-1 |
| `polkitd` | 126-2 |
| `pkexec` | 126-2 |
| `lxc` | 1:6.0.4-4+deb13u4 |
| `lxcfs` | 6.0.4-1+deb13u1 |
| `xdg-desktop-portal` | 1.20.3+ds-1 |
| `xdg-desktop-portal-gtk` | 1.15.3-1 (fallback portal) |

### 2.7 Waydroid runtime

| Package | Source |
|---|---|
| `waydroid` 1.6.3+ds-3 | ElvonOS backport |
| `python3-gbinder` 1.3.1+ds-1+b2 | ElvonOS backport |
| `libgbinder1` | ElvonOS backport |
| `libglibutil` | ElvonOS backport |
| `python3` | Trixie 3.13.5-1 |
| `python3-gi` | 3.50.0-4+b1 |
| `gir1.2-gtk-3.0` | 3.24.49-3 |
| `python3-dbus` | 1.4.0-1 |
| `python3-pyclip` / `wl-clipboard` | optional clipboard bridge |

`waydroid` must not run as root in the user session. The system container service is the only root component.

### 2.8 Desktop runtime (Qt 6 / QML)

| Package | Version |
|---|---|
| `libqt6core6t64` | 6.8.2+dfsg-9+deb13u2 |
| `libqt6gui6` | 6.8.2+dfsg-9+deb13u2 |
| `libqt6qml6` | 6.8.2+dfsg-7 |
| `libqt6quick6` | 6.8.2+dfsg-7 |
| `libqt6quickcontrols2-6` | 6.8.2+dfsg-7 |
| `libqt6waylandclient6` | 6.8.2-4 |
| `libqt6svg6` | 6.8.2-3 |
| `libqt6dbus6` | 6.8.2+dfsg-9+deb13u2 |
| `layer-shell-qt` | 6.3.4-1 |
| `liblayershellqtinterface6` | 6.3.4-1 |
| `qml6-module-qtquick-controls` | 6.8.2+dfsg-7 |
| `qml6-module-qtquick-layouts` | 6.8.2+dfsg-7 |
| `qml6-module-qtquick-window` | 6.8.2+dfsg-7 |
| `qml6-module-qtquick-templates` | 6.8.2+dfsg-7 |
| `qml6-module-qt5compat-graphicaleffects` | 6.8.2-3+b1 |
| `qt6-translations-l10n` | 6.8.2-2 |
| `fonts-noto` / `fonts-noto-color-emoji` | Trixie |
| `sddm` | 0.21.0+git20250502.4fe234b-2 (provisional) |

`greetd` 0.10.3-4 + `tuigreet` 0.9.1-5 is a minimal fallback for development images.

### 2.9 Hyprland runtime

Built by ElvonOS (see `04-hyprland-report.md`):

- `hyprland` 0.50.1
- `aquamarine` 0.9.3
- `hyprutils` 0.8.2
- `hyprlang` 0.6.x
- `hyprcursor` 0.1.13
- `hyprgraphics` 0.1.4
- `hyprland-protocols` 0.6.4
- `hyprwayland-scanner` 0.3.10+

Runtime system packages: `libinput10`, `libxkbcommon0`, `libwayland-server0`, `libdrm2`, `libgbm1`, `libegl1`, `libgles2`, `libpixman-1-0`, `libcairo2`, `libpango-1.0-0`, `liblcms2-2`, `libcanberra0`, `libseat1`, `libdisplay-info2`, `hwdata`, `libre2-11`, `libudis86-0`, `libtomlplusplus3t64`, `libmuparser2v5`.

---

## 3. Build-host packages (not target)

These are needed to build the custom packages and ISO, not to run ElvonOS:

| Group | Packages |
|---|---|
| Toolchain | `git`, `cmake` 3.31.6-2, `ninja-build` 1.12.1-1, `g++` 4:14.2.0-1, `pkg-config` 1.8.1-4 |
| Debian packaging | `debhelper` 13.24.2, `devscripts` 2.25.15+deb13u1, `equivs` 2.3.2, `lintian` 2.122.0, `dh-python` 6.20250414, `dh-apparmor` 4.1.0-1 |
| Python | `python3` 3.13.5-1, `python3-pip`, `python3-venv`, `python3-dev` |
| ISO | `live-build` 1:20250505+deb13u1, `mmdebstrap` 1.5.7-1+deb13u1, `debootstrap` 1.0.141, `squashfs-tools` 1:4.6.1-1, `xorriso` 1.5.6-1.2+b1, `grub-efi-amd64-bin` 2.12-9+deb13u2, `grub-pc-bin` 2.12-9+deb13u2, `mtools` 4.0.48-1, `dosfstools` 4.2-1.2, `parted` 3.6-5, `gdisk` 1.0.10-2, `cryptsetup-bin` 2:2.7.5-2, `btrfs-progs` 6.14-1 |
| Utilities | `curl`, `xz-utils`, `jq`, `rsync` |
| Hyprland build | `libwayland-dev` 1.23.1-3, `wayland-protocols` 1.44-1, `libxkbcommon-dev` 1.7.0-2, `libinput-dev` 1.28.1-1+deb13u1, `libdrm-dev` 2.4.124-2, `libgbm-dev` 25.0.7-2+deb13u1, `libegl-dev` 1.7.0-1+b2, `libgles-dev` 1.7.0-1+b2, `libgl-dev`, `libudev-dev`, `libseat-dev` 0.9.1-1, `libdisplay-info-dev` 0.2.0-2, `hwdata` 0.394-1, `libxcb1-dev`, `libxcb-composite0-dev`, `libxcb-errors-dev` 1.0.1-4, `libxcb-icccm4-dev` 0.4.2-1, `libxcb-render0-dev`, `libxcb-res0-dev`, `libxcb-xfixes0-dev`, `libpixman-1-dev` 0.44.0-3, `libcairo2-dev` 1.18.4-1+b1, `libpango1.0-dev` 1.56.3-1, `liblcms2-dev` 2.16-2+deb13u2, `libcanberra-dev` 0.30-18, `libglib2.0-dev` 2.84.4-3~deb13u5, `libxcursor-dev`, `libtomlplusplus-dev` 3.4.0+ds-0.2+b1, `libmuparser-dev` 2.3.4-1+b1, `libudis86-dev` 0+20221013-1.1, `libre2-dev` 20240702-3+b1, `uuid-dev`, `libzip-dev` 1.11.3-2, `libmagic-dev` 1:5.46-5, `libjpeg-dev` 1:2.1.5-4, `libwebp-dev` 1.5.0-0.1 |
| Waydroid build | `libglib2.0-dev`, `libgbinder-dev` (custom), `libglibutil-dev` (custom), `python3-dev`, `dh-python`, `dh-apparmor`, `pkg-config` |
| Desktop build | `qt6-base-dev` 6.8.2+dfsg-9+deb13u2, `qt6-declarative-dev` 6.8.2+dfsg-7, `qt6-wayland-dev` 6.8.2-4, `qt6-svg-dev` 6.8.2-3, `qt6-tools-dev` 6.8.2-5, `liblayershellqtinterface-dev` (verify exact name), `qml6-module-*` dev packages |
| Rust services | `rustc` 1.85.1+dfsg1-1+deb13u1, `cargo` 1.85.1+dfsg1-1+deb13u1, `libssl-dev` 3.5.7-1~deb13u2, `libdbus-1-dev` 1.16.2-2 |

### Install command (not executed)

```bash
sudo apt update
sudo apt install --no-install-recommends \
  systemd systemd-sysv dbus dbus-user-session udev kmod initramfs-tools \
  linux-image-amd64 linux-headers-amd64 linux-base firmware-linux-free \
  grub-efi-amd64 grub-efi-amd64-signed shim-signed efibootmgr \
  dosfstools e2fsprogs parted gdisk \
  network-manager wpasupplicant wireless-regdb dnsmasq-base iproute2 \
  nftables iptables bluez \
  pipewire pipewire-pulse wireplumber alsa-utils libspa-0.2-bluetooth \
  libgl1-mesa-dri mesa-vulkan-drivers mesa-utils vulkan-tools libegl1 libgles2 \
  firmware-amd-graphics firmware-mediatek firmware-realtek firmware-misc-nonfree \
  firmware-sof-signed firmware-nvidia-gsp firmware-nvidia-graphics amd64-microcode \
  apparmor apparmor-profiles polkitd pkexec lxc lxcfs \
  xdg-desktop-portal xdg-desktop-portal-gtk xwayland \
  python3 python3-gi gir1.2-gtk-3.0 python3-dbus \
  sddm fonts-noto fonts-noto-color-emoji
```

This command is a **plan**, not a tested install. The actual Phase 1 script must be idempotent, log every action, and stop on error.

---

## 4. Package pinning and updates

- Do not hold `linux-image-amd64`; kernel updates must remain enabled.
- Do not enable unstable/backports globally.
- Custom packages carry `ElvonOS` in the maintainer field and a version suffix such as `+elvonos1`.
- The ElvonOS repository is signed; APT verifies signatures.
- The ISO build records the exact resolved versions in `build/out/packages.lock`.
- Previous kernels are retained by `initramfs-tools`/GRUB; do not run `apt autoremove` blindly in the update service.

---

## 5. Package installation order

1. Core system, kernel, firmware, bootloader
2. Networking, audio, graphics
3. Security/container base
4. Hyprland stack (custom)
5. Waydroid stack (custom)
6. Desktop runtime and ElvonOS shell
7. Installer/live environment (ISO only)

Each layer must have a smoke test before the next layer is added. Do not build the full ISO first and debug backwards.
