# 08 — Development Roadmap

Principle: **no phase is marked complete without evidence.** A build log, a test output, or a hardware observation is evidence. An assumption is not.

---

## Phase 0 — Inspection and reports (complete)

Deliverables:

- repository/environment audit,
- Debian 13 compatibility report,
- official Debian kernel report,
- Waydroid compatibility report,
- Hyprland package report,
- hardware report,
- package plan,
- ISO strategy,
- this roadmap,
- open decisions.

Exit criteria: reports written; no false claims; no system changes.

---

## Phase 1 — Debian foundation

Goal: a minimal Debian 13.7 amd64 system with the official kernel, firmware, networking, audio, graphics, and boot working on real hardware.

Deliverables:

- `base/packages/*.list` and `base/configuration/*` (this repository),
- `build/phase1/check-host.sh` (read-only),
- `build/phase1/install-build-deps.sh` (requires explicit root authorization),
- `build/phase1/build-rootfs.sh` (mmdebstrap/live-build rootfs),
- `build/phase1/validate-rootfs.sh`,
- a bootable Phase 1 image or a Debian 13 VM/host install,
- test evidence: boot log, kernel version, firmware loaded, NetworkManager, PipeWire, Mesa.

Exit criteria:

- [ ] Debian 13.7 boots on UEFI with the official `linux-image-amd64`.
- [ ] `uname -r` shows the Debian kernel, not Microsoft/WSL.
- [ ] `modprobe binder_linux devices="anbox-binder,anbox-vndbinder,anbox-hwbinder"` creates all three devices.
- [ ] Wi-Fi/Ethernet, audio, and at least one GPU render node work.
- [ ] `systemctl --failed` is clean.
- [ ] The previous kernel is retained in GRUB.

Risks: firmware missing, Secure Boot, WSL not representative, no root authorization yet.

---

## Phase 2 — Wayland foundation

Goal: Hyprland 0.50.1 builds on Trixie and runs a real session on the target AMD iGPU.

Deliverables:

- pinned source lock and SHA256,
- `.deb` packages for hyprland-protocols, hyprwayland-scanner, hyprutils, hyprlang, hyprcursor, hyprgraphics, aquamarine, Hyprland,
- session file and default config generator,
- SDDM or greetd integration,
- input/display/audio tests.

Exit criteria:

- [ ] All packages build from source on Debian 13.7 with GCC 14.2.
- [ ] Hyprland starts on AMD iGPU.
- [ ] Keyboard, mouse, touchpad, multi-monitor work.
- [ ] PipeWire/WirePlumber audio works.
- [ ] `hyprctl -j monitors/clients/workspaces` returns valid JSON.
- [ ] A LayerShellQt test panel reserves space.
- [ ] Logout/restart is clean.

Risks: C++26/GCC 14, aquamarine DRM, hybrid NVIDIA.

---

## Phase 3 — Android runtime

Goal: Waydroid 1.6.3 boots Android 13 on the official Debian kernel and runs an APK.

Deliverables:

- ElvonOS backports of libglibutil, libgbinder, python3-gbinder, waydroid,
- binder module configuration,
- Waydroid image installation and checksum verification,
- container/session services,
- network/audio/clipboard/notification smoke tests.

Exit criteria:

- [ ] `waydroid init` succeeds with the local images.
- [ ] Container and session start as user/root with minimal privileges.
- [ ] Android boots.
- [ ] APK installs and launches.
- [ ] Network, audio, clipboard, notifications, keyboard/mouse, multi-window work.
- [ ] GPU renderer is verified; software rendering is labeled as such.

Risks: legacy binder context separation, LXC/AppArmor, cgroup v2, NVIDIA.

---

## Phase 4 — ElvonOS desktop

Goal: an independent Qt 6/QML desktop shell: taskbar, launcher, settings, file manager, widgets, notifications, quick settings.

Deliverables:

- `elvonos-shell` (panel, launcher, quick settings, notification center),
- `elvonos-settings`,
- `elvonos-files`,
- `elvonos-widgets`,
- `elvonos-notifications` D-Bus service,
- theme and icon system,
- settings backend services.

Exit criteria:

- [ ] Panel starts on Hyprland and reserves space.
- [ ] Launcher lists Android apps from Waydroid.
- [ ] Settings sections work through D-Bus, not direct file edits.
- [ ] File manager exposes user-friendly roots and Android shared storage.
- [ ] Notifications are unified and not duplicated.
- [ ] Multi-monitor panel behavior works.
- [ ] No Hyprland config files are exposed to users.

Risks: app icons, layer-shell/Qt integration, notification action callbacks, scope creep.

---

## Phase 5 — Android integration

Goal: Android apps feel native on the ElvonOS desktop.

Deliverables:

- app manager (install/remove/launch/update notifications),
- multi-window launching and window rules,
- notification actions,
- clipboard bridge,
- file access to Android shared storage,
- Android settings entry,
- Aurora Store/F-Droid integration points (optional, user-installed),
- microG optional configuration.

Exit criteria:

- [ ] Launching an app from launcher/taskbar works.
- [ ] Multiple Android windows coexist and are managed by Hyprland.
- [ ] Android notifications appear once with working actions.
- [ ] Clipboard works both directions.
- [ ] APK install from the file manager works.
- [ ] No Google Play Services bundled.
- [ ] microG remains optional.

Risks: Waydroid API limits, icon extraction, Android permission UI, licensing.

---

## Phase 6 — Hardware integration

Goal: validated AMD, Intel, and NVIDIA behavior on real hardware.

Deliverables:

- hardware service and detection,
- GPU selection policy,
- firmware/microcode selection,
- Wi-Fi/Bluetooth/audio/storage tests,
- suspend/resume,
- thermal/power monitoring,
- hardware test reports.

Exit criteria:

- [ ] AMD iGPU: Hyprland + Waydroid GPU rendering.
- [ ] NVIDIA: documented supported configuration (Nouveau or proprietary).
- [ ] Intel: tested on available hardware.
- [ ] Wi-Fi/Bluetooth/audio/USB/suspend pass on the target laptop.
- [ ] No unsupported hardware is advertised as supported.

Risks: NVIDIA Wayland/Waydroid, MediaTek firmware, hybrid graphics.

---

## Phase 7 — Installer and ISO

Goal: a bootable ElvonOS V1 ISO with Calamares installation and first-boot setup.

Deliverables:

- live-build configuration,
- Calamares branding and modules,
- custom package repository on the ISO,
- Waydroid images in the ISO,
- first-boot wizard,
- recovery entry,
- signed checksums.

Exit criteria:

- [ ] ISO builds reproducibly on Debian 13.7.
- [ ] UEFI and BIOS boot.
- [ ] Install completes on a spare disk/VM.
- [ ] First boot reaches the ElvonOS desktop.
- [ ] Waydroid initializes without manual commands.
- [ ] Reboot preserves user and Android data.
- [ ] Secure Boot works with the signed Debian kernel.

Risks: ISO size, Calamares post-install, Secure Boot, Waydroid first-boot time.

---

## Phase 8 — Stabilization

Goal: release ElvonOS V1.

Deliverables:

- regression test results,
- update/recovery validation,
- performance/power checks,
- documentation,
- release notes and known issues,
- signed release artifacts.

Exit criteria:

- [ ] No critical boot/desktop/Android regressions.
- [ ] Updates preserve user data and retain the previous kernel.
- [ ] Recovery path is tested.
- [ ] Hardware matrix is documented with evidence.
- [ ] Known limitations are published (NVIDIA, Android 17, microG, etc.).

---

## Immediate next actions (Phase 1)

1. Obtain explicit authorization for root package installation on a Debian 13 build host (or WSL, for packaging only).
2. Install the build toolchain from `06-package-plan.md`.
3. Run `build/phase1/check-host.sh` and record the output.
4. Build a minimal Debian 13.7 rootfs with `mmdebstrap` or install a Debian 13.7 VM.
5. Test the binder legacy-device path on the official Debian kernel.
6. Record evidence in `documentation/test-results/phase1.md`.

Do not start Phase 2 until Phase 1 boot evidence exists on the Debian kernel.
