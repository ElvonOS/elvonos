# elvonos-waydroid (Rust)

ElvonOS-owned integration layer for Waydroid.  It replaces the old shell and
Python helper scripts while keeping the upstream Waydroid 1.6.3 session/UI as
the Android backend (for now).

## Build

```sh
# once on the build host
sudo apt install cargo rustc libdbus-1-dev pkg-config

bash build/waydroid/build-waydroid-rs.sh
```

The crate is dependency-pinned (`Cargo.lock`) and the crates are vendored under
`vendor/`, so the build works offline.  The binary is installed as
`/usr/bin/elvonos-waydroid` into `build/out/rootfs`; it links `libdbus-1`
(runtime is already part of the image).

## Commands

| Command | Purpose |
|---|---|
| `elvonos-waydroid [PACKAGE]` | Start container/session, install bundled apps, refresh entries, launch an app |
| `elvonos-waydroid start` / `stop` | Control container and session |
| `elvonos-waydroid status [--json]` | Container, session, Android boot state and app count |
| `elvonos-waydroid sync` | Rebuild the Start-menu entries from the native package manager |
| `elvonos-waydroid list [--json]` | List installed Android apps (label + package) |
| `elvonos-waydroid install [APK…]` | Install one or more APKs (Zenity picker when omitted) |
| `elvonos-waydroid remove PACKAGE` | Uninstall an Android app and remove its entry |
| `elvonos-waydroid apps` | Install bundled Aurora Store and microG |
| `elvonos-waydroid apk-entry APK [LABEL]` | Create a single `.desktop` entry, works without a session |
| `elvonos-waydroid doctor` | Diagnose container, images, binder, sudo and session |
| `elvonos-waydroid recover` | Restart a stuck container/session |
| `elvonos-waydroid daemon [--once]` | Supervise session/apps in the background (autostart) |
| `elvonos-waydroid autostart on/off` | Warm start at login (honoured by labwc autostart) |
| `elvonos-waydroid config` | Show `~/.config/elvonos/waydroid.conf` |
| `elvonos-waydroid graphics auto\|software\|gpu` | Rendering profile (`gpu`/Virgl by default, `software` for diagnosis) |
| `elvonos-waydroid storage [--json]` | Android data usage and free space |
| `elvonos-waydroid restart` | Restart session and container without losing the config |
| `elvonos-waydroid clear-data PACKAGE` | Clear one Android app's data |
| `elvonos-waydroid bridge start\|stop\|status` | Clipboard/notification bridge |
| `elvonos-waydroid freeze` / `unfreeze` | Freeze/resume the Android container (power saving) |
| `elvonos-waydroid open FILE` | Copy a host file to Android and open it with the matching app |
| `elvonos-waydroid share TEXT` | Share text to Android apps |
| `elvonos-waydroid backup [FILE]` | Back up the Android data directory (freezes Android for consistency) |
| `elvonos-waydroid restore FILE` | Stop Waydroid, restore a data backup and start again |

## Native parts

- **Native session service:** `elvonos-waydroid session` owns `id.waydro.Session`
  on the session bus and calls `id.waydro.ContainerManager.Start` directly via
  D-Bus.  `waydroid status`, `waydroid app list` and the app launcher see a
  normal session; no Python `waydroid session start` process is involved.
- Container control through `systemctl` and `sudo -n lxc-attach`.
- Android boot detection through `getprop sys.boot_completed`.
- Session detection through `/proc` (no Python/D-Bus round-trip), with the
  upstream `waydroid status` only as fallback.
- APK installation through `pm install` inside the container (streamed into
  `/data/local/tmp`, no host path mounting).
- App discovery through `pm list packages -3`, labels through `dumpsys package`
  and a local label cache.
- Binary `AndroidManifest.xml` parser in pure Rust (package name directly from
  the APK, no Python and no session required).
- Start-menu entries with localized `GenericName`/`Comment` for all 15
  ElvonOS languages.  Real launcher icons are extracted from the APK
  (`dumpsys application-icon-*` + `pm path` + `unzip`) and cached under
  `~/.local/share/icons/elvonos/android/`; adaptive XML icons fall back to the
  generic Waydroid icon.
- Launcher activities are queried through `cmd package query-activities`, so
  system apps without a launcher icon do not appear in the Start menu.
- Settings → Apps exposes the Android app list with icons, *Open*/*Uninstall*,
  *Android settings* and *Install APK*.
- First-start repair for root-owned `~/.local`/`~/.config` directories in the
  live image, and a PID lock so concurrent launches do not start two sessions.
- Optional Rust supervisor (`daemon`) that keeps the session alive, installs
  missing bundled apps, refreshes entries and honours `stop` via a pause file.
- 30-minute first-boot timeout for slow virtual machines (TCG); real hardware
  returns as soon as Android reports `sys.boot_completed=1`.
- State file `~/.local/state/elvonos/waydroid.json` and rotating log
  `~/.local/state/elvonos/waydroid.log`.
- Desktop notifications through `notify-send` when available.

## Compatibility

`elvonos-waydroid-sync`, `elvonos-waydroid-install-apk`,
`elvonos-waydroid-apk-entry` and `elvonos-waydroid-apps.sh` are thin wrappers
around the Rust binary.  Existing `.desktop` files and Settings/Control Center
keep working.

## Test environment limitation

Older QEMU/TCG runs could leave `system_server` restarting, after which
`pm install` failed with a null `PackageManagerInternal`.  The real causes were
found and fixed:

- `install` no longer installs the bundled Aurora/Play/microG set as a side
  effect; only the APKs that were passed are installed (`apps` does the bundle).
- Virgl is required.  Without it SurfaceFlinger aborts with
  `output buffer not gpu writeable` and `system_server` dies.  A software
  profile (`gralloc=default`, `egl=angle`, Mesa llvmpipe) does **not** fix that;
  it only survives until the first app window.  Use
  `elvonos-waydroid graphics auto` (default) on a real GPU.
- QEMU on Windows with WHPX and `virtio-gpu-gl-pci` + `egl-headless`
  (`build/phase1/run-desktop-qemu-whpx.ps1`) boots Android in ~40–60 s and installs
  Aurora in ~4 s.  TCG inside WSL needs several minutes for the same work.

## Icons

`sync` extracts the real launcher icon from the installed APK.  It first asks
`dumpsys package` for `application-icon-*`; modern APKs (for example Aurora
Store) use obfuscated resource names, so the fallback scans `unzip -l` for the
largest square PNG under `res/` and stores it in
`~/.local/share/icons/elvonos/android/<package>.png`.  The Android data
directory is read directly from `~/.local/share/waydroid/data`, no
`lxc-attach` copy is needed.

## App launch

`launch` first tries the native path: it sets `waydroid.active_apps`, resolves the
launcher activity with `cmd package resolve-activity`, starts it with
`am start --user 0` and verifies the task through a short `dumpsys activity`
probe.  If the task does not appear (or the probe is unavailable during boot),
it falls back to the upstream `waydroid app launch` multi-window launcher.

## System integration

- **Supervisor unit:** `elvonos-waydroid autostart on` enables the systemd user
  unit `elvonos-waydroid.service` (installed to `/usr/lib/systemd/user/`) when
  it is available.  The unit runs `elvonos-waydroid daemon` with
  `Restart=on-failure`; the labwc autostart hook stays as a fallback and skips
  itself when the unit is active.
- **Clipboard/notifications:** `elvonos-waydroid-bridge` (Python helper) starts
  the upstream gbinder services `waydroidclipboard` and
  `waydroidnotifications` standalone.  The native Rust session replaces the
  Python session manager, so these services would otherwise not run.  Clipboard
  uses `wl-paste`/`wl-copy` instead of `pyclip`.  The bridge is started once
  Android is reachable, logs to
  `~/.local/state/elvonos/waydroid-bridge.log` and can be toggled in
  Einstellungen → Apps or with `config set bridge false`.
- **Desktop:** the Android desktop icon opens the Explorer's Android app list
  (`elvonos-explorer --android-apps`); the Explorer mounts
  `~/.local/share/waydroid/data/media/0` at login and on demand.  Android apps
  appear in Win8Start because their `.desktop` entries are written to
  `~/.local/share/applications` and Win8Start re-hashes the application
  directories on every show.
- **Power:** `elvonos-waydroid freeze`/`unfreeze` suspend the container through
  the container manager.  `elvonos-waydroid-lock` wraps `Win8Lock` and is used
  by the generated swayidle configuration, so Android is frozen while the
  desktop is locked and resumed on unlock.  `status` reports `Android: frozen`
  and `--json` adds a `frozen` field; a frozen container is never probed with
  `lxc-attach`.
- **Intents:** `elvonos-waydroid open FILE` copies the file into the Android
  `Download` folder, triggers a media scan and launches
  `ACTION_VIEW` with the MediaStore content URI (falling back to `file://`).
  The Explorer's context menu offers **Mit Android öffnen**.
  `elvonos-waydroid share TEXT` starts an Android `ACTION_SEND` intent.  The
  available handlers depend on the installed Android apps.
- **Backup:** `elvonos-waydroid backup [FILE]` freezes the container for a
  consistent snapshot, writes `data/` as a `tar.zst` (default
  `~/Backups/waydroid-<timestamp>.tar.zst`) and unfreezes it.
  `restore FILE` stops session and container, extracts the archive with root
  ownership and starts Waydroid again.
- **Bridge lifecycle:** the bridge holds an exclusive `flock`, so only one
  instance registers the gbinder services, and `stop` uses SIGKILL because the
  gbinder threads can keep SIGTERM from exiting.  Two `bridge start` calls
  leave exactly one process; `bridge stop` leaves none.
- **Notifications:** the `waydroidnotifications` binder service registers, but
  Android only forwards notifications through SystemUI's vendor hooks, which
  are not active in multi-window mode even when `com.android.systemui` runs.
  Clipboard sync works; notification forwarding remains an Android-side task.

## Remaining upstream delegation

`waydroid init` still uses the vendored upstream Python implementation.  The
session service, container lifecycle, app discovery, install/remove, native
activity launch (with fallback), desktop sync and Start-menu integration are
ElvonOS-owned Rust.  The next step is a fully native window launcher built on
Waydroid's Android `IPlatform` service.
