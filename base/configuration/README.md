# ElvonOS target configuration

These files are **templates for the target system**, not for the current WSL host. `build/phase1/build-rootfs.sh` copies them into the rootfs; the installer will install the same files into the final system.

| Path | Installed to | Phase |
|---|---|---|
| `apt/sources.list.d/debian.sources` | `/etc/apt/sources.list.d/debian.sources` | 1 |
| `apt/sources.list.d/elvonos.sources.in` | `/etc/apt/sources.list.d/elvonos.sources` (after substitution) | 1/7 |
| `apt/preferences.d/elvonos.pref` | `/etc/apt/preferences.d/elvonos.pref` | 1 |
| `modprobe.d/elvonos-binder.conf` | `/etc/modprobe.d/elvonos-binder.conf` | 1/3 |
| `modules-load.d/elvonos-binder.conf` | `/etc/modules-load.d/elvonos-binder.conf` | 1/3 |
| `wayland-sessions/elvonos.desktop` | `/usr/share/wayland-sessions/elvonos.desktop` | 2 |
| `environment.d/90-elvonos-qt.conf` | `/etc/environment.d/90-elvonos-qt.conf` | 4 |
| `waydroid/elvonos-waydroid.properties` | `/usr/share/elvonos/waydroid/elvonos-waydroid.properties` | 3 |

## Rules

- Do not enable Debian unstable or global backports.
- Do not hardcode a Waydroid GPU/EGL property. Waydroid generates `waydroid_base.prop` from the detected host GPU; ElvonOS only applies deliberate overrides.
- Do not expose these files as the user settings UI. The ElvonOS settings service owns the supported controls.
- The ElvonOS repository URI and signing key are not in this repository. `elvonos.sources.in` is a template; substitute `@ELVONOS_REPO_URI@` and `@ELVONOS_SUITE@` at build time.

## Binder note

The official Debian 13 kernel has `CONFIG_ANDROID_BINDERFS` disabled. The configuration here uses the stock `binder_linux` module with three legacy device names that Waydroid 1.6.3 probes. This is not a kernel patch. It must be runtime-tested on the real Debian kernel; see `documentation/02-kernel-compatibility.md`.
