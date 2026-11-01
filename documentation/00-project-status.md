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
| 0 — Inspection and reports | **Complete** | This document set |
| 1 — Debian foundation | Scaffolded, not built | Package manifests + scripts; no rootfs/ISO yet |
| 2 — Wayland/Hyprland | Not started | Hyprland build plan only |
| 3 — Android runtime | Not started | Waydroid backport plan only |
| 4 — ElvonOS desktop | Not started | UI architecture proposed |
| 5 — Android integration | Not started | D-Bus surfaces identified |
| 6 — Hardware integration | Not started | Host inventory only |
| 7 — Installer/ISO | Not started | Strategy only |
| 8 — Stabilization | Not started | — |

The next executable step is Phase 1 on a Debian 13 build host with root, followed by a boot test on the target laptop or a Debian 13 VM. See `09-decisions-required.md`.
