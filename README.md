# ElvonOS

ElvonOS is a free, ad-free desktop operating system for PCs and laptops. It
combines **Debian 13 (Trixie)** with a Windows-8-style shell, a curated set of
ElvonOS applications, a custom kernel build and deep **Waydroid** integration
for Android apps.

**Primary source (downloads, files, screenshots):**
<https://sourceforge.net/projects/elvonos/>

- Downloads: <https://sourceforge.net/projects/elvonos/files/>
- Screenshots: <https://sourceforge.net/projects/elvonos/files/screenshots/>
- Update feed: <https://downloads.sourceforge.net/project/elvonos/feeds/stable.json>
- Feed mirror: <https://github.com/ElvonOS/elvonos-updates>
- Feed mirror: <https://codeberg.org/ElvonOS/elvonos-updates>
- License: **GPL-3.0-or-later** — see [LICENSE](LICENSE) and
  [LICENSES.md](LICENSES.md)

## Screenshots

| Start screen (Restart / Shut down) | Installer (English) |
|---|---|
| ![Start screen](https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/screenshots/start-menu.png) | ![Installer language selection](https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/screenshots/installer-language.png) |

| Settings | ElvonOS updates (signed feed) |
|---|---|
| ![Settings](https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/screenshots/settings.png) | ![Updates](https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/screenshots/settings-updates.png) |

Screenshots are also hosted on SourceForge:
<https://sourceforge.net/projects/elvonos/files/screenshots/>

## Based on

| Item | Base |
|---|---|
| Distribution | **Debian 13 "Trixie"** (stable + security only, no unstable) |
| Kernel | Debian `linux-source-6.12` → **6.12.116-elvonos** (config delta only) |
| Init | systemd 257 |
| Compositor | **labwc 0.8.3** (Debian, configuration only) |
| Desktop shell | **Win8DE 0.9.0-beta2** fork, upstream commit `cc5594526cf6fd2e5957f44afaf4268e425acd45` |
| Android runtime | **Waydroid 1.6.3** + Android 13 / LineageOS 20 VANILLA images |
| Toolkits | Qt 6.8, GTK 3 |
| Bootloader | GRUB 2.12 (UEFI + BIOS) |
| Installer | ElvonOS `elvonos-installer` (Bash + Zenity) |

Full details: **[Upstream base, forks and changes](documentation/16-upstream-forks-and-changes.md)**.

## Forks, patches and changes

ElvonOS is a distribution. Only the following parts are forked or rebuilt;
everything else is used as shipped by Debian.

- **Win8DE shell** — forked at a pinned upstream commit and patched with
  **18 patches** (modern taskbar, Start widgets, Aero/frosted glass, live tiles,
  Flatpak icons, window-switcher sync, **always-visible Restart/Shut down
  buttons**, stale-lock handling). Patches: `build/win8de/patches/`.
- **Waydroid** — upstream 1.6.3 source vendored; service unit patched (Binder
  preload, restart policy, timeouts), ElvonOS properties (multi-window, GBM +
  Mesa EGL, hidden decorations) and a Rust client `elvonos-waydroid`
  (`open`, `share`, `backup`, `restore`, `freeze`, `multiwindow`).
- **Kernel** — Debian 6.12 source rebuilt with `-elvonos` and debug info
  removed; all drivers and firmware kept (`MODULES=most`).
- **New ElvonOS software** — Settings, Terminal, Files/Explorer, Store, Control
  Center, Calculator, Notepad, Archiver, PDF viewer, Screenshot, Paint, Gallery,
  Media, Event Viewer, Task Manager, Cleaner, Defrag, Print/Scan, desktop
  extras, health daemon, installer, first-boot setup, update client.
- **Desktop integration** — Metro/desktop mode switch, hot corners, Start tile
  defaults, Plymouth `elvonos` theme, ElvonOS splash, icons, wallpapers and
  system sounds.
- **Installer** — language, keyboard, time zone, user/password, hostname,
  optional software on first boot, UEFI/BIOS GRUB incl. standalone EFI fallback.
- **Free updates** — signed static feed (minisign), verified ISO/package
  updates, Settings card **ElvonOS Updates**. Updates cover Debian packages,
  ElvonOS software payloads and setup components, are **prepared in the
  background and installed on shutdown/reboot** (ChromeOS-style), or started
  manually. **Personal files are never touched**: payloads are allowlisted to
  `usr/` and `etc/elvonos`, and user homes are excluded by design.
- **English by default** — live session and new installs use `en_US.UTF-8`;
  the installer applies the chosen language and keyboard.

## Development and AI disclaimer

ElvonOS is developed with **AI assistance**. The **DeepSeek** coding assistant
(model *DeepSeek V4.1 Flash*) is actively involved in the project: writing and
reviewing code, building and debugging the ISO, QEMU testing, documentation,
translations and release automation. All changes are reviewed and approved by
the human maintainer, who owns the technical and licensing decisions.

**ElvonOS itself contains no AI.** The operating system does not ship a
language model, an inference runtime, an AI assistant, or any "AI feature".
Nothing in the desktop, the installer or the update client calls an AI service,
and there is no AI-related telemetry. Network access is limited to the
functions the user configures (APT repositories, Flathub/Waydroid app sources,
the signed update feed and optional gaming setup downloads).

If an AI feature is ever added, it will be **opt-in**, clearly labelled and
documented here first.

## Features

- Live ISO with graphical installer; installs to GPT (BIOS + UEFI), ext4.
- Custom kernel `6.12.116-elvonos` with BinderFS, Virgl, NTFS3 and all Debian
  drivers/firmware.
- Win8DE Start screen, taskbar, hot corners, live tiles, restart/shutdown.
- Metro mode (maximized windows) switchable in Settings.
- Waydroid multi-window integration and Android app icons in the Start menu.
- Built-in terminal with Android shell support.
- Health layer (`elvonos-healthd`) and Settings **Condition** card.
- Free, signed update feed (GitHub + Codeberg) with SourceForge downloads.

## Install

1. Download `ElvonOS-1.0.3-amd64.iso` from
   <https://sourceforge.net/projects/elvonos/files/releases/1.0.3/>.
2. Verify:

   ```sh
   sha256sum -c SHA256SUMS
   minisign -Vm ElvonOS-1.0.3-amd64.iso -p elvonos.pub
   ```

3. Write the ISO to a USB stick (`dd` or balenaEtcher) and boot it.
4. Start **Install Elvon OS**, choose disk, language, keyboard, time zone,
   user, password, hostname and optional software, confirm with `ERASE`.
5. Reboot and log in with your account.

All drivers and firmware are included. Optional software is installed on the
first boot when online. Details: [Live installer](documentation/13-live-installer.md).

## Updates

```sh
elvonos-update check      # signed feed status (ISO, OS packages, components)
elvonos-update download   # download + verify the next ISO
elvonos-update apply      # OS packages + signed ElvonOS payloads/components
```

`apply` upgrades Debian packages, installs signed ElvonOS software payloads and
runs setup components (for example Flathub for the Store). A new ISO is needed
only for kernel, bootloader or live-image changes. The public key is at
`/usr/share/elvonos/update/elvonos.pub`. Details:
[Free updates](documentation/15-free-updates.md).

## Repository layout

```
ElvonOS/
├── Android/                Waydroid source and Android images
├── base/
│   ├── packages/           Debian package manifests
│   └── configuration/      ElvonOS apps, scripts, installer, desktop config
├── build/
│   ├── phase*/             rootfs and ISO build phases
│   ├── kernel/             kernel build script and saved config
│   ├── win8de/             Win8DE fork: patches, build script, work tree
│   └── update/             feed, release and mirror scripts
├── documentation/          design, status, licensing, how-to documents
├── tests/                  validation scripts
├── LICENSE
├── LICENSES.md
└── README.md
```

## Build from source

Build host: Debian 13 (or WSL2 with Debian 13).

```sh
sudo bash build/phase1/build-rootfs.sh     # Debian rootfs
sudo bash build/kernel/build-kernel.sh     # 6.12.116-elvonos
sudo bash build/win8de/build-win8de.sh --install-rootfs
sudo bash build/phase7/build-iso.sh        # build/out/ElvonOS-1.0.0-amd64.iso
```

## Documentation

English documents:

- [Upstream base, forks and changes](documentation/16-upstream-forks-and-changes.md)
- [Live installer](documentation/13-live-installer.md)
- [Licensing](documentation/14-licensing.md)
- [Free updates](documentation/15-free-updates.md)
- [Release plan](documentation/17-release-plan.md)
- [Documentation index](documentation/README.md)

Older design documents are still in German and are being translated.

## License

ElvonOS original code is **GPL-3.0-or-later**. Bundled components keep their
own licenses (Linux kernel GPL-2.0, Win8DE GPL-2.0, Waydroid GPL-3.0, Qt
LGPL-3.0/GPL-3.0, Inter OFL-1.1, …). See [LICENSES.md](LICENSES.md).
The software is provided without warranty.
