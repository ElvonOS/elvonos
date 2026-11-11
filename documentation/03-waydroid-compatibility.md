# 03 — Waydroid Compatibility Report

Runtime: **Waydroid 1.6.3** (vendored upstream source)
Image: **Android 13 / LineageOS 20 VANILLA `waydroid_x86_64` 2026-09-27**
Host base: **Debian 13 Trixie amd64**
Kernel: **official Debian 6.12.107-1** (BinderFS disabled)

---

## 1. Verdict

**Viable with a Debian backport and the legacy binder device path. Not yet runtime-tested.**

Waydroid is not packaged in Debian 13. Debian unstable contains the exact upstream version (1.6.3) plus the missing Python/GBinder stack, so the host packages are rebuilt from Debian source for Trixie — not from Arch packages and not with an experimental container runtime.

The ElvonOS-owned glue is now a Rust implementation (`base/configuration/waydroid-rs`, `/usr/bin/elvonos-waydroid`) that replaces the old shell/Python helpers: container and session control, native `pm install`, APK manifest parsing, app discovery/labels, Start-menu synchronisation, status/JSON, doctor, recovery, autostart, logging and notifications. Upstream Waydroid 1.6.3 remains the Android/container runtime for now; replacing its Python session manager and multi-window launcher is the next, separate phase described in section 9.

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
| Container lifecycle | `systemctl` + `lxc-attach` | `elvonos-waydroid` (Rust) |
| Session lifecycle | native `id.waydro.Session` + `ContainerManager.Start` | `elvonos-waydroid session` (Rust) |
| App list | `pm list packages -3` + `dumpsys package` labels | `elvonos-waydroid list` (Rust) |
| App launch | `waydroid app launch <package>` / `IPlatform.launchApp` | launcher / taskbar (upstream, next phase) |
| APK install | `pm install` inside the container | `elvonos-waydroid install` (Rust) |
| APK remove | `pm uninstall` inside the container | `elvonos-waydroid remove` (Rust) |
| Full Android UI | `waydroid show-full-ui` | launcher entry (upstream, next phase) |
| Notifications | `org.freedesktop.Notifications` | ElvonOS notification service |
| Clipboard | `IClipboard` + pyclip | ElvonOS clipboard bridge |
| Multi-window | `persist.waydroid.multi_windows=true` | Hyprland window rules |
| Android settings | Android Settings activity | Settings → Android |
| Permissions | Android permission UI | Settings → Android (V1 link) |

### Rust integration (implemented)

`base/configuration/waydroid-rs` is a dependency-free Rust binary installed as
`/usr/bin/elvonos-waydroid`.  It owns the ElvonOS side of Waydroid:

- `elvonos-waydroid session` owns `id.waydro.Session` on the session bus and
  calls `id.waydro.ContainerManager.Start` directly over D-Bus; the Python
  `waydroid session start` is no longer used in the normal path.
- `start` / `stop` / `recover` control `waydroid-container.service` and the
  native session; `status [--json]` reports container, session, boot state and
  app count.
- Session state is detected natively by scanning `/proc` for the native session
  process; the Python CLI is only a fallback.
- APK installation and removal use `pm install` / `pm uninstall` inside the
  container.  The APK is streamed into `/data/local/tmp` over `lxc-attach`, so
  no host path needs to be mounted.
- App discovery uses `pm list packages -3`; labels come from a local cache and
  `dumpsys package`, with the upstream `waydroid app list` only as fallback.
- `apk-entry` parses the binary `AndroidManifest.xml` in pure Rust and creates a
  Start-menu entry without a running session.
- `sync` regenerates `.desktop` entries with localized `GenericName`/`Comment`
  for all 15 ElvonOS languages.
- `autostart on/off` is honoured by the labwc autostart; Settings → Apps shows a
  Waydroid card with session/app count and start/sync/autostart controls.
- State and logs live in `~/.local/state/elvonos/`; user feedback uses
  `notify-send`.  `doctor` verifies binary, images, LXC, binder, sudo and
  session.

### Next phase: window launcher and initializer

The session service is now native Rust: it owns `id.waydro.Session` and calls
`ContainerManager.Start`, which performs the networking, mounts, LXC start and
hardware manager setup.  Remaining upstream dependencies:

1. **Multi-window launcher.** Rust now resolves the launcher activity and starts
   it with `am start` (setting `waydroid.active_apps`) and verifies the task; if
   the task surface does not appear it falls back to `waydroid app launch`.  A
   fully native launcher needs to call the Android `IPlatform` service
   (gbinder/NDK) and map the resulting Wayland surfaces as individual
   `xdg_toplevel` windows without the Python fallback.
2. **Initializer.** `waydroid init` still downloads/verifies images, unpacks the
   rootfs and writes the first-boot properties.  This can be reimplemented in
   Rust with image checksum verification and the existing overlay layout.
3. **Optional services.** Android notifications and clipboard sync currently
   come from Waydroid's Python services; they can be reimplemented on top of the
   ElvonOS notification daemon and wl-clipboard.

Everything else (session, container lifecycle, APK parsing/install/remove, app
list/labels, desktop sync, supervisor, settings UI) is ElvonOS-owned Rust.

### App icons

Waydroid's `getAppsInfo` returns name, package name, and categories, but not icon
data.  The Rust integration extracts the real launcher icon without an
Android-side helper:

1. `dumpsys package <pkg>` yields `application-icon-<density>:'res/…png|webp'`.
2. `pm path <pkg>` yields the base APK path inside the container.
3. The APK is streamed out with `lxc-attach cat`, the highest-density icon entry
   is extracted with `unzip`, and the result is cached under
   `~/.local/share/icons/elvonos/android/`.
4. The Start-menu entry uses that icon; the Settings app list shows it too.

A generic `waydroid` icon remains the fallback for adaptive XML icons or when
the session is unavailable.

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

### Test environment limitation

Older TCG tests in WSL could leave `system_server` restarting during boot, after
which `pm install` failed with a null `PackageManagerInternal`.  Three causes
were found and fixed:

1. **Wrong work at the wrong time.**  `elvonos-waydroid install APK` used to
   install the bundled Aurora Store, Play Store and microG (108 MB) as a side
   effect.  On a slow emulated boot that dominated the runtime and starved the
   container.  `install` now installs only the APKs that were passed; the
   bundled set belongs to `elvonos-waydroid apps`.
2. **No Virgl.**  Without Virgl, SurfaceFlinger aborts with
   `output buffer not gpu writeable`, then `system_server` dies with
   `Surface$OutOfResourcesException: DEAD_OBJECT` every ~30 s.  A software
   profile (`gralloc=default`, `egl=angle`, Mesa llvmpipe) was tested and is
   **not** a workaround: SurfaceFlinger still aborts on the first app window.
   Virgl is required; `elvonos-waydroid graphics gpu|software|auto` manages the
   profile, the default is `gpu`.
3. **QEMU host choice matters.**  On Windows, QEMU with WHPX and
   `-device virtio-gpu-gl-pci -display egl-headless` is ~7x faster than TCG
   inside WSL: Android reaches `sys.boot_completed=1` in about 37 s, a native
   `pm install` of Aurora takes ~4 s and the native launcher opens the app in
   ~3 s.  Use `build/phase1/run-desktop-qemu-whpx.ps1`; SSH is forwarded to
   tcp/2222 and reachable from WSL through the default-gateway address.

### Verified end-to-end (live ISO, Windows QEMU + WHPX + Virgl)

- Native session `RUNNING`, `Container: active`, `Android: booted`.
- `elvonos-waydroid install AuroraStore-4.8.4.apk` → `pm install` success in ~4 s.
- `elvonos-waydroid sync` creates `waydroid-com.aurora.store.desktop` and
  extracts the real APK launcher icon (800×800 PNG) into
  `~/.local/share/icons/elvonos/android/`.
- Einstellungen → Apps lists the app with icon and **Öffnen** /
  **Deinstallieren** actions.
- `elvonos-waydroid com.aurora.store` starts
  `com.aurora.store/.ComposeActivity`; `mCurrentFocus` is the app window, i.e.
  a real Wayland multi-window window on the ElvonOS desktop.


### System integration

- **Supervisor:** `elvonos-waydroid.service` is a systemd *user* unit
  (`/usr/lib/systemd/user/`) running `elvonos-waydroid daemon` with
  `Restart=on-failure`.  `elvonos-waydroid autostart on` enables it; the labwc
  autostart hook only runs the daemon when the unit is not active.
- **Clipboard and notifications:** the native Rust session replaces Waydroid's
  Python session manager, which used to start the `waydroidclipboard` and
  `waydroidnotifications` gbinder services.  `elvonos-waydroid-bridge` starts
  those upstream services standalone, with `wl-paste`/`wl-copy` as the host
  clipboard backend (no `pyclip` dependency).  It is started by
  `elvonos-waydroid` once Android is reachable and can be toggled in
  Einstellungen → Apps.  Both binder services register successfully.  Note that
  Android only *emits* notifications while `com.android.systemui` is running;
  in multi-window mode SystemUI is not started, so notification forwarding
  becomes active in full-UI sessions, while clipboard sync works in both.
- **Storage:** `elvonos-waydroid storage [--json]` reports Android data usage
  and the free space of the hosting filesystem.  The shared storage is
  `~/.local/share/waydroid/data/media/0` (Waydroid ≥ 1.4; the legacy
  `/var/lib/waydroid/data` is still accepted) and is bind-mounted to
  `/run/elvonos/waydroid` at login and on demand.  Einstellungen → Apps shows
  the usage in the Waydroid card.
- **Explorer:** the Android storage is mounted at login and on demand at
  `~/.local/share/waydroid/data/media/0` → `/run/elvonos/waydroid`; the desktop
  Android icon and `elvonos-explorer` open the Android app list
  (`--android-apps`).
- **Settings:** start, restart, sync, Android settings, APK install, autostart,
  clipboard bridge, per-app open/clear-data/uninstall and an Android app search
  live in the Waydroid card.
- **Power:** `elvonos-waydroid freeze`/`unfreeze` freeze the container through
  the container manager.  `elvonos-waydroid-lock` wraps `Win8Lock` and is used
  by the generated swayidle configuration; Android is frozen while the desktop
  is locked and resumed after unlocking.  `status` shows `Android: frozen` and
  the JSON has a `frozen` field.  Frozen containers are never probed with
  `lxc-attach`, so status calls cannot hang.
- **Intents:** `elvonos-waydroid open FILE` copies the file into Android's
  `Download` folder, runs a media scan, resolves the MediaStore content URI and
  fires `ACTION_VIEW` (falling back to a `file://` URI).  The Explorer context
  menu has **Mit Android öffnen**.  `elvonos-waydroid share TEXT` starts an
  `ACTION_SEND` intent; actual targets depend on the installed Android apps.

### Explicit non-claims

- Do not claim Waydroid works from static inspection.
- Do not claim GPU acceleration from a software-rendered session.
- Do not claim Android 17 support; it is future work and must be tested separately.
