# Licensing decision (ElvonOS 1.0)

**Decision:** the original ElvonOS code is released under
**GPL-3.0-or-later**. Bundled third-party components keep their own licenses.
The machine-readable summary is in [`../LICENSES.md`](../LICENSES.md), the
license text in [`../LICENSE`](../LICENSE).

## Options considered

| License | Pros | Cons | Verdict |
|---|---|---|---|
| MIT / BSD-2-Clause | Maximum reuse, simple | No copyleft; improvements can become closed; weak patent language | Rejected for an OS project |
| Apache-2.0 | Patent grant, business-friendly | Incompatible with GPLv2-only components in one combined work; no copyleft | Rejected |
| GPL-2.0-only | Matches the kernel and Win8DE | No patent grant, no anti-tivoization; cannot combine with GPLv3 libraries | Rejected as project-wide license |
| **GPL-3.0-or-later** | Strong copyleft, patent grant, anti-tivoization, compatible with Qt/GRUB/Waydroid | Slightly stricter distribution rules | **Chosen** |
| MPL-2.0 | File-level copyleft | Not designed for whole operating systems | Rejected |

## Why GPLv3 fits ElvonOS

1. **Desktop stack:** Settings, Terminal, Store and the splash screen use Qt 6.
   Qt is available under LGPL-3.0/GPL-3.0; GPL-3.0-or-later is a clean fit and
   keeps the option to use GPL-only Qt modules.
2. **Boot chain:** GRUB and Waydroid are GPL-3.0-or-later. Shipping them with
   an OS whose own code is GPLv3 keeps the licensing story uniform.
3. **User freedom:** the anti-tivoization rules matter for an OS that ships
   bootloaders, kernels and signed updates.
4. **Patents:** the explicit patent grant protects users and contributors.

## Compatibility with GPLv2-only components

The Linux kernel (GPL-2.0-only) and Win8DE (GPL-2.0) are **separate programs**
in the distribution. They are not linked with GPLv3 code:

- the kernel runs as the kernel; userspace talks to it through the syscall
  interface, which is not a derivative work in the GPL sense;
- Win8DE binaries are unmodified or modified under GPL-2.0; ElvonOS's
  `build/win8de/` changes stay under GPL-2.0 and are published in this
  repository.

This is the same aggregation model used by Debian, Fedora and other
distributions that mix GPLv2-only and GPLv3 software.

## Obligations for redistributors

- Publish the complete corresponding source of the GPL components you ship.
- Keep copyright notices and license texts intact.
- Provide the GPLv3 text and a way to obtain the source (this repository plus
  the upstream projects).
- Do not add technical restrictions that prevent users from replacing the
  software (GPLv3 §6 / anti-tivoization).

## Third-party license inventory

The full table lives in `LICENSES.md`. Highlights:

- Kernel: GPL-2.0-only
- GRUB: GPL-3.0-or-later
- Win8DE: GPL-2.0
- Waydroid: GPL-3.0-or-later
- labwc: GPL-2.0-or-later
- Qt 6: LGPL-3.0 / GPL-3.0
- systemd/glibc/GTK/Flatpak/Wine/Zenity: LGPL-2.1-or-later
- wlroots/Wayland/PipeWire/NetworkManager parts: MIT
- Android images: Apache-2.0 (AOSP) and component licenses
- Inter font: SIL OFL 1.1
- minisign: BSD-2-Clause; libsodium: ISC

## Verification

On an installed system the authoritative per-package texts are in
`/usr/share/doc/<package>/copyright`. The ElvonOS ISO ships `LICENSE`,
`LICENSES.md` and this document under `/usr/share/doc/elvonos/` (added in the
next image build).

## Future changes

License changes require a decision record in this file, a new release note,
and compatibility review with Qt, GRUB, Waydroid and the kernel.
