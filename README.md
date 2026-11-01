# ElvonOS V1

Android-first desktop operating system built on **Debian 13 (Trixie)**, the **original Debian kernel**, **Hyprland**, and **Waydroid**.

> Status: **Phase 0 inspection complete. Phase 1 scaffolded, not built.**
> No host packages were installed, no kernel changes were made, and no ISO was produced.

## Target

| Item | Value |
|---|---|
| Architecture | x86_64 / amd64 |
| Base | Debian 13 Trixie Stable (current archive: 13.7) |
| Kernel | Official `linux-image-amd64` (6.12.107-1 at inspection time) |
| Compositor | Hyprland (pinned ElvonOS build) |
| Android runtime | Waydroid 1.6.3 |
| Android image | Android 13 / LineageOS 20 VANILLA (`waydroid_x86_64`, 2026-09-27) |
| Init | systemd |
| Packages | APT / dpkg |
| UI | Qt 6 / QML + LayerShellQt (proposed) |
| Services | Rust + D-Bus |

## Read this first

1. [`documentation/00-project-status.md`](documentation/00-project-status.md) — repository and environment audit
2. [`documentation/09-decisions-required.md`](documentation/09-decisions-required.md) — open decisions and blockers
3. [`documentation/02-kernel-compatibility.md`](documentation/02-kernel-compatibility.md) — BinderFS finding and the stock-kernel path
4. [`documentation/08-roadmap.md`](documentation/08-roadmap.md) — phase gates

## Repository map (implemented content only)

```
ElvonOS/
├── Android/                  vendored Waydroid 1.6.3 source + Android images (existing input)
├── base/
│   ├── packages/             exact Debian package manifests
│   └── configuration/        target system configuration (binder, apt, session)
├── build/phase1/             Phase 1 host check and rootfs build scripts
├── documentation/            audit and architecture reports
├── tests/phase1/             read-only host and rootfs validation
├── VERSION
└── README.md
```

Directories from the master prompt are created only when they contain a real implementation. The existing `Android/` directory is kept as the upstream vendor input; ElvonOS integration code will not be placed inside it.

## Critical findings

- The development environment is **WSL2**, not the target. Its kernel is Microsoft's `6.18.54.1-microsoft-standard-WSL2`, with Binder disabled, no `/dev/kvm`, no real GPU/audio/USB, and no passwordless sudo. It can build packages and run unit tests, but it cannot validate boot, Hyprland, Waydroid, GPU, audio, or suspend.
- **Hyprland is not in Debian 13.** Debian unstable has 0.57.0, but that version needs an unstable-only C++/Lua/hypr stack. The candidate for V1 is Hyprland **0.50.1** plus pinned hypr libraries, built from source.
- **Waydroid is not in Debian 13.** Debian unstable has Waydroid 1.6.3, `python3-gbinder` 1.3.1, and `libgbinder`. These must be backported/built for Trixie.
- **The official Debian kernel has `CONFIG_ANDROID_BINDERFS` disabled.** However, its `binder_linux` module supports multiple legacy binder devices via `devices=`. Waydroid 1.6.3 explicitly falls back to that path. This is statically compatible but **not yet runtime-tested**.
- The target laptop has an AMD Cezanne iGPU and an NVIDIA RTX 3070 Laptop GPU. Waydroid should default to the AMD/Mesa path; NVIDIA needs separate validation.

## Non-negotiable rules reflected in this repository

- No Arch Linux, pacman, AUR, or Arch packages.
- No custom kernel in V1.
- No native Linux desktop application ecosystem as the user-facing platform.
- Android applications are the primary user-facing applications.
- Linux components are infrastructure only.
- No destructive system changes without explicit authorization.
