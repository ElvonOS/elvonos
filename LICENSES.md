# ElvonOS Licensing

ElvonOS is free software. The original ElvonOS code is licensed under the
**GNU General Public License, version 3 or later** (`GPL-3.0-or-later`).
The full text is in [`LICENSE`](LICENSE).

ElvonOS is a distribution: it aggregates independent programs. Each bundled
component keeps its own license; this file lists the important ones and how
the combination is distributed.

## Why GPL-3.0-or-later

- **Strong copyleft** keeps the operating system and its improvements free for
  every user, which matches the project goal of a free, ad-free desktop OS.
- The desktop stack is built on **Qt 6** (LGPL-3.0 / GPL-3.0), **GRUB**
  (GPL-3.0-or-later), **Waydroid** (GPL-3.0-or-later) and other GPLv3
  components; GPL-3.0 is the natural common denominator for the original code.
- **Patent grant and anti-tivoization** clauses of GPLv3 are valuable for an
  operating system that ships bootloaders and kernel images.
- GPLv2-only components such as the Linux kernel and Win8DE remain separate
  programs in the distribution; they are **not relicensed** and no GPLv3 code
  is linked into them.

If you need a permissive license for a specific ElvonOS library, contact the
maintainers; small reusable pieces can be dual-licensed on request.

## Original ElvonOS code (GPL-3.0-or-later)

| Component | Path |
|---|---|
| Live installer, first-boot setup | `base/configuration/installer/` |
| Settings, terminal, calculator, notepad, archiver, PDF viewer, screenshot, Control Center, Store, desktop extras | `base/configuration/*/` |
| Session scripts (`elvonos-update`, `elvonos-appmode`, `elvonos-sound`, `elvonos-gaming-setup`, `elvonos-health`, `elvonos-waydroid`) | `base/configuration/scripts/`, `base/configuration/health/` |
| Update tooling and feed signing scripts | `build/update/` |
| ISO/rootfs build scripts | `build/` (except third-party sources) |

## Bundled components

| Component | Role | License |
|---|---|---|
| Linux kernel `6.12.116-elvonos` | Kernel (Debian config + ElvonOS options) | GPL-2.0-only |
| Debian 13 (Trixie) userland | Base system and packages | mixed free licenses (DFSG); see `/usr/share/doc/*/copyright` on an installed system |
| GNU GRUB 2.12 | Bootloader | GPL-3.0-or-later |
| systemd 257 | Init and services | LGPL-2.1-or-later |
| glibc | C library | LGPL-2.1-or-later |
| Qt 6.8 | Application toolkit (Settings, Terminal, Store, splash) | LGPL-3.0 / GPL-3.0 (ElvonOS uses the GPL/LGPL terms) |
| GTK 3 | Toolkit for the classic shell components | LGPL-2.1-or-later |
| labwc | Wayland compositor | GPL-2.0-or-later |
| wlroots / Wayland | Compositor libraries | MIT |
| Win8DE 0.9.0beta2 (incl. Win8Start, Win8Wall, Win8Running, Win8Corner, Win8Settings, Win8OSD, Win8Lock) | Windows-8-style shell | **GPL-2.0** (unchanged upstream license; ElvonOS modifications stay GPL-2.0) |
| Waydroid 1.6.3 | Android container runtime | GPL-3.0-or-later |
| Android 13 images (Waydroid system/vendor) | Android userspace | Apache-2.0 (AOSP) and component licenses; kernel GPL-2.0 |
| PipeWire / WirePlumber | Audio and session management | MIT |
| NetworkManager | Networking | GPL-2.0-or-later (parts LGPL-2.1-or-later) |
| udisks2 | Disk management | GPL-2.0-or-later |
| ntfs-3g | NTFS driver | GPL-2.0-or-later |
| exfatprogs | exFAT tools | GPL-2.0-or-later |
| Flatpak | App runtime | LGPL-2.1-or-later |
| Wine | Windows compatibility (optional) | LGPL-2.1-or-later |
| Zenity | Installer dialogs | LGPL-2.1-or-later |
| curl | Update downloads | curl license (MIT-style) |
| jq | JSON processing | MIT |
| minisign / libsodium | Update signatures | BSD-2-Clause / ISC |
| Python 3 | Health daemon and tooling | PSF-2.0 |
| Inter (font) | UI typeface | SIL Open Font License 1.1 |
| Plymouth | Boot splash | GPL-2.0-or-later |
| greetd | Login manager | GPL-3.0-or-later |
| swaybg, fnott, wlr-randr | Desktop helpers | MIT |
| Rust crates in `elvonos-waydroid` | Waydroid helper | MIT / Apache-2.0 (per crate) |

## What is not bundled

- **Steam** and other proprietary stores are not shipped. The optional gaming
  setup installs them from their official sources; their own licenses apply.
- **Codecs** with patent restrictions are not preinstalled. The optional
  "Multimedia codecs" set installs Debian's free codec packages.
- **Microsoft fonts** are not included.

## Distribution compliance

- Complete corresponding source for GPL components is available from Debian,
  upstream projects, and the ElvonOS source tree.
- The exact ElvonOS customizations are in this repository under
  `base/`, `build/`, and `documentation/`.
- Binaries on SourceForge/GitHub/Codeberg are accompanied by checksums and
  minisign signatures.
- No warranty: the software is provided "as is", without any warranty, as
  stated in the GPL.

## Reporting license issues

If a file is missing a license notice or a component is misattributed, open an
issue or contact the maintainers. We will correct it in the next release.
