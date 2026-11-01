# 03 — Waydroid Compatibility Report

Runtime: **Waydroid 1.6.3** (vendored upstream source)
Image: **Android 13 / LineageOS 20 VANILLA `waydroid_x86_64` 2026-09-27**
Host base: **Debian 13 Trixie amd64**
Kernel: **official Debian 6.12.107-1** (BinderFS disabled)

---

## 1. Verdict

**Viable with a Debian backport and the legacy binder device path. Not yet runtime-tested.**

Waydroid is not packaged in Debian 13. Debian unstable contains the exact upstream version (1.6.3) plus the missing Python/GBinder stack, so the correct approach is to rebuild Debian's source packages for Trixie — not to use Arch packages, not to rewrite Waydroid, and not to use an experimental container runtime.

The official Debian kernel lacks BinderFS, but Waydroid's own fallback creates `/dev/anbox-binder`, `/dev/anbox-vndbinder`, and `/dev/anbox-hwbinder` through the `binder_linux` module. This must be proven on real hardware before Android compatibility is claimed.

---

## 2. Image inventory

| File | Size | Format | SHA256 |
|---|---|---|---|
| `system.img` | 1.8 GiB | ext4 | `30c87ee44412fee4f50173716a6bb7c6941d3021853f0adab4a249da8a9455ab` |
| `vendor.img` | 537 MiB | ext4 | `5cc4267517ded28f1cf60a5d2b6e8b88b15d8520de1f55a39de7764e7929a877` |

Build properties found in `system.img`:

```
ro.build.version.release=13
ro.build.version.sdk=33
ro.lineage.version=20.0-20260927-VANILLA-waydroid_x86_64
```

Notes:

- This is an Android 13 (SDK 33) LineageOS 20 VANILLA image.
- Only `system.img` and `vendor.img` are present. Waydroid OTA manifests can also reference `vendor_extra.img`; Phase 3 must verify whether this image set needs it.
- The images are external artifacts and are excluded from Git by `.gitignore`. The ISO build must include them or fetch and verify them at first boot.
- Do not assume Android 17 compatibility. The image strategy must keep the Android image separate from the host and allow future image replacement.

---

## 3. Debian package gap

| Package | Trixie | Debian unstable | Plan |
|---|---|---|---|
| `waydroid` | absent | 1.6.3+ds-3 | Rebuild Debian source package for Trixie |
| `python3-gbinder` | absent | 1.3.1+ds-1+b2 | Rebuild |
| `libgbinder1` / `libgbinder-dev` | absent | available | Rebuild |
| `libglibutil` / `libglibutil-dev` | absent | available | Rebuild |
| `lxc` | 1:6.0.4-4+deb13u4 | newer | Use Trixie package |
| `python3-gi` | 3.50.0-4+b1 | — | Use Trixie |
| `gir1.2-gtk-3.0` | 3.24.49-3 | — | Use Trixie (Waydroid's own installer GUI is internal) |
| `python3-dbus` | 1.4.0-1 | — | Use Trixie |
| `polkitd` / `pkexec` | 126-2 | — | Use Trixie |
| `pipewire-pulse` | 1.4.2-1 | — | Use Trixie |
| `nftables` | 1.1.3-1 | — | Use Trixie |

Waydroid's Debian control also requires `python3`, `dbus`, `lxc`, `python3-gbinder`, `python3-gi`, `gir1.2-gtk-3.0`, `python3-dbus`, `pkexec`, `polkitd`, `pipewire-pulse | pulseaudio`, `nftables`.

### Build order

1. `libglibutil`
2. `libgbinder`
3. `python3-gbinder`
4. `waydroid`

Build with Debian packaging (`dpkg-buildpackage`/`sbuild`) against Trixie, producing signed `.deb` files for the ElvonOS repository. Do not install Debian unstable packages directly into Trixie.

### Optional clipboard support

Waydroid's `clipboard_manager.py` imports `pyclip` and silently disables clipboard sync if it is missing. Phase 3 should add a Wayland-capable clipboard backend (`python3-pyclip` plus `wl-clipboard`, or an ElvonOS clipboard bridge) and test both directions.

---

## 4. Runtime dependency chain

```
Waydroid session (user)
  └── id.waydro.Session (session D-Bus)
        ├── notification manager  -> org.freedesktop.Notifications
        ├── clipboard manager     -> pyclip / Wayland clipboard
        └── user manager

Waydroid container (root, systemd)
  └── id.waydro.Container (system D-Bus)
        ├── LXC container
        ├── binder devices (/dev/anbox-*)
        ├── waydroid-net.sh (veth, NAT, nftables)
        └── Android system services
```

The ElvonOS Android manager must wrap these interfaces; it must not reimplement Waydroid.

---

## 5. Kernel requirements

See `02-kernel-compatibility.md` for the full analysis.

Summary:

| Requirement | Debian 6.12.107 | Consequence |
|---|---|---|
| Binder IPC | `m` | available |
| BinderFS | **not set** | use legacy devices |
| Legacy binder device parameter | supported | `modprobe binder_linux devices="anbox-binder,anbox-vndbinder,anbox-hwbinder"` |
| Ashmem | absent | not required for Android 13 (memfd present) |
| Namespaces | enabled | LXC can run |
| cgroups v2 | enabled | LXC/Waydroid can run |
| seccomp | enabled | LXC isolation |
| overlayfs | `m` | Android image overlays |
| veth / bridge / netfilter / NAT | enabled | container networking |
| DRM / Mesa / GBM | enabled | graphics |

**Runtime gate:** do not mark Waydroid compatible until the real Debian kernel boots Android, installs an APK, launches it, and passes network/audio/input tests.

---

## 6. Graphics

Waydroid renders Android windows as Wayland surfaces; Hyprland composites them. The host must provide:

- DRM/KMS and a working Mesa/EGL stack,
- GBM,
- Vulkan (for apps and Android's Vulkan path),
- GPU device access (`/dev/dri/renderD*`),
- a Wayland socket owned by the user session.

On the target laptop:

- **Default:** AMD Cezanne iGPU via `amdgpu` + Mesa RADV/ANV equivalent (RADV for AMD).
- **NVIDIA:** RTX 3070 Laptop via Nouveau or the proprietary driver. Waydroid + proprietary NVIDIA + Wayland is a separate test matrix; do not promise it for V1 until tested.
- **Software rendering:** only a diagnostic fallback; never label it as GPU acceleration.

Do not run Waydroid as root. The session must run as the logged-in user so it can access the Wayland socket and the correct GPU render node.

---

## 7. Audio

Waydroid's Android audio is routed through the host's PulseAudio-compatible socket. Trixie provides PipeWire 1.4.2 with `pipewire-pulse`. WirePlumber 0.5.8 manages devices.

Test:

- speakers and headphones,
- microphone,
- USB audio,
- Bluetooth audio (BlueZ + WirePlumber SPA Bluetooth),
- Android volume synchronization,
- no duplicate/competing PulseAudio server.

---

## 8. Networking

Waydroid uses LXC networking plus `data/scripts/waydroid-net.sh` (veth, bridge/NAT, nftables). Requirements:

- `nftables` (preferred) or `iptables`,
- IP forwarding enabled for the container,
- NAT rules created by Waydroid,
- DNS reachable from Android,
- IPv4 and IPv6 behavior tested,
- no conflict with NetworkManager or the host firewall.

Android applications must have reliable connectivity. Test with a browser, an APK that uses HTTP, and DNS resolution inside Android.

---

## 9. Integration surfaces for ElvonOS

| Capability | Interface | ElvonOS component |
|---|---|---|
| Container lifecycle | `id.waydro.Container` system D-Bus | `elvonos-android-manager` |
| Session lifecycle | `id.waydro.Session` session D-Bus | `elvonos-android-manager` (user) |
| App list | `waydroid app list` / `IPlatform.getAppsInfo` | `elvonos-app-manager` |
| App launch | `waydroid app launch <package>` / `IPlatform.launchApp` | launcher / taskbar |
| APK install | `waydroid app install <apk>` | app manager / file manager |
| APK remove | `waydroid app remove <package>` | app manager |
| Full Android UI | `waydroid show-full-ui` | launcher entry |
| Notifications | `org.freedesktop.Notifications` | ElvonOS notification service |
| Clipboard | `IClipboard` + pyclip | ElvonOS clipboard bridge |
| Multi-window | `persist.waydroid.multi_windows=true` | Hyprland window rules |
| Android settings | Android Settings activity | Settings → Android |
| Permissions | Android permission UI | Settings → Android (V1 link) |

### App icons

Waydroid's `getAppsInfo` returns name, package name, and categories, but not icon data. V1 must either:

- generate a generic icon set from package names, or
- add a small Android-side helper/API to export icons into a cache, or
- parse APK resources on the host (complex, not recommended for V1).

Do not block the launcher on icon extraction. A clean fallback is acceptable for V1.

### Notifications

Waydroid 1.6.3 forwards Android notifications to the host's `org.freedesktop.Notifications` service, including actions, images, urgency, and activation tokens. ElvonOS must implement this D-Bus service and avoid duplicating notifications. The notification center should group by Android package and preserve action callbacks.

---

## 10. Security and isolation

- Waydroid's LXC container must not receive unnecessary host privileges.
- Use the upstream AppArmor profiles (`data/configs/apparmor_profiles/`).
- Keep `lxc.cap.keep` minimal; do not add `CAP_SYS_ADMIN` beyond what Waydroid requires.
- Do not expose root or container management to ordinary users.
- Use polkit for privileged operations (start/stop container, install system images).
- Keep Android data under `/var/lib/waydroid` (or the upstream default) separate from host system files.
- Do not bundle Google Play Services. Aurora Store and F-Droid are optional user-installed or separately configured components. microG must remain optional and separately configurable.

---

## 11. Test plan and acceptance criteria

### Phase 3 gate — kernel and container

- [ ] `binder_linux` loads with the three legacy devices
- [ ] `/dev/anbox-binder`, `/dev/anbox-vndbinder`, `/dev/anbox-hwbinder` exist
- [ ] `waydroid init` succeeds with the local images
- [ ] `waydroid-container.service` starts
- [ ] `waydroid session start` succeeds as the desktop user
- [ ] Android boot completes (`waydroid status` shows RUNNING)
- [ ] `waydroid app list` returns packages

### Android functionality

- [ ] Install a local APK
- [ ] Launch an app in multi-window mode
- [ ] Launch a fullscreen app
- [ ] Network: HTTP + DNS from Android
- [ ] Audio: playback and microphone
- [ ] Clipboard: host → Android and Android → host
- [ ] Notifications: Android notification appears once, actions work
- [ ] Keyboard and mouse
- [ ] Touch/touchpad where available
- [ ] GPU acceleration: `waydroid prop get ro.hardware.egl` and a GPU-rendered app; verify renderer, not just "it opens"
- [ ] Multi-monitor window placement

### Explicit non-claims

- Do not claim Waydroid works from static inspection.
- Do not claim GPU acceleration from a software-rendered session.
- Do not claim Android 17 support; it is future work and must be tested separately.
