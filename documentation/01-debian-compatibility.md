# 01 — Debian 13 Compatibility Report

Target: **Debian 13 Trixie Stable, amd64**
Archive at inspection: **13.7** (released 2026-09-12)
Running development environment: **13.5**

---

## 1. Verdict

**The Debian base is compatible and appropriate.** All required base-system components are available from the official Debian 13 archive.

Two required application-platform components are **not** in Debian 13:

| Component | Debian 13 | Debian unstable | Consequence |
|---|---|---|---|
| Hyprland | not packaged | 0.57.0+ds-1 | ElvonOS must build and package a pinned Hyprland stack |
| Waydroid | not packaged | 1.6.3+ds-3 | ElvonOS must backport Waydroid, python3-gbinder, libgbinder, libglibutil |
| python3-gbinder | not packaged | 1.3.1+ds-1+b2 | Build from Debian source packaging |
| libgbinder / libglibutil | not packaged | available | Build from Debian source packaging |

This does **not** require changing the base distribution. It requires an ElvonOS package repository containing Debian-built `.deb` packages for those components, pinned and tested against Trixie.

---

## 2. Base system components

All of the following are available in Trixie main (versions from the 13.7 archive):

| Requirement | Package | Version |
|---|---|---|
| Init | `systemd` / `systemd-sysv` | 257.13-1~deb13u1 |
| Device management | `udev` | 257.13-1~deb13u1 |
| IPC | `dbus` / `dbus-user-session` | 1.16.2-2 |
| Networking | `network-manager` | 1.52.1-1 |
| Audio server | `pipewire` | 1.4.2-1 |
| Audio session | `wireplumber` | 0.5.8-2 |
| Pulse compatibility | `pipewire-pulse` | 1.4.2-1 |
| ALSA tools | `alsa-utils` | 1.2.14-1 |
| Mesa DRI | `libgl1-mesa-dri` | 25.0.7-2+deb13u1 |
| Vulkan | `mesa-vulkan-drivers` | 25.0.7-2+deb13u1 |
| Mesa tools | `mesa-utils` | 9.0.0-2+b2 |
| Kernel | `linux-image-amd64` | 6.12.107-1 |
| Kernel headers | `linux-headers-amd64` | 6.12.107-1 |
| Initramfs | `initramfs-tools` | 0.148.4 |
| Bootloader (UEFI) | `grub-efi-amd64` / `grub-efi-amd64-signed` | 2.12-9+deb13u2 / 1+2.12+9+deb13u2 |
| Secure Boot shim | `shim-signed` | 1.51~1+deb13u1+16.1-2~deb13u1 |
| AppArmor | `apparmor` / `apparmor-profiles` | 4.1.0-1 |
| Containers | `lxc` / `lxcfs` | 1:6.0.4-4+deb13u4 / 6.0.4-1+deb13u1 |
| Firewall | `nftables` / `iptables` | 1.1.3-1 / 1.8.11-2 |
| Polkit | `polkitd` / `pkexec` | 126-2 |
| Portals | `xdg-desktop-portal` | 1.20.3+ds-1 |
| XWayland | `xwayland` | 2:24.1.6-1 |

### Firmware (non-free-firmware)

The running APT configuration enables **main only**. Firmware requires `non-free-firmware` to be added.

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
| `intel-microcode` | 3.20251111.1~deb13u1 |
| `amd64-microcode` | 3.20250311.1 |

`firmware-mediatek` is required for the target laptop's MT7921 Wi-Fi/Bluetooth. `firmware-amd-graphics` is required for the Cezanne iGPU. `firmware-nvidia-gsp` is only needed if the proprietary NVIDIA driver is selected.

---

## 3. APT configuration required

The current WSL sources are:

```
deb https://deb.debian.org/debian trixie trixie-updates trixie-backports main
deb https://security.debian.org/debian-security trixie-security main
```

Target configuration must add `contrib` and `non-free-firmware`:

```
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

Notes:

- `trixie-backports` should **not** be enabled globally for V1. It may be used only for a specific, tested package with an explicit pin.
- ElvonOS custom packages must live in a separate signed repository, not in Debian's components.
- The target ISO should pin a Debian snapshot date for reproducibility. See `07-iso-strategy.md`.

---

## 4. Version alignment

| Item | Running | Target | Action |
|---|---|---|---|
| Debian point release | 13.5 | 13.7 | Build ISO from 13.7; do not in-place upgrade the WSL host as part of this project without permission |
| Kernel | Microsoft WSL 6.18 | Debian 6.12.107-1 | Test on real Debian kernel; WSL kernel is not evidence |
| Mesa | not installed | 25.0.7 | Install on target |
| Qt | not installed | 6.8.2 | Install on target |

The running WSL 13.5 is acceptable as a **packaging workspace** after build tools are installed, but it is not the reference runtime. The reference build environment must be Debian 13.7.

---

## 5. Compatibility risks

| Risk | Impact | Mitigation |
|---|---|---|
| Hyprland absent from Trixie | No compositor from APT | Build pinned 0.50.1 stack; package as ElvonOS `.deb`s |
| Waydroid absent from Trixie | No Android runtime from APT | Backport Debian sid packaging for Waydroid 1.6.3, python3-gbinder, libgbinder, libglibutil |
| Kernel BinderFS disabled | Waydroid BinderFS path unavailable | Use legacy binder devices via `binder_linux devices=`; runtime test |
| `firmware-*` not enabled | Wi-Fi/GPU may fail | Add `non-free-firmware`; install explicit firmware packages |
| Backports mixing | ABI/version drift | No global backports; pin individual packages if ever used |
| Debian point release drift | Build non-reproducibility | Pin snapshot.debian.org date and package versions |

---

## 6. Conclusion

Debian 13 provides a complete, stable foundation for ElvonOS. The two upstream application-platform stacks must be packaged by ElvonOS because Debian stable does not ship them. That is a packaging and integration task, not a reason to change the base distribution.
