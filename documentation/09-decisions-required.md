# 09 — Decisions Required

Date: **2026-11-01**
Status: **Phase 1 scaffold complete; execution blocked on authorization and a Debian 13 build/test host.**

This document separates decisions that block Phase 1 from decisions that can wait until later phases. Nothing here is approved just because it is recommended.

---

## 0. Blockers (not decisions)

| ID | Blocker | Evidence | What is needed |
|---|---|---|---|
| B1 | No non-interactive root access | `sudo -n true` fails with “a password is required” | The user must run the build steps or provide a root-capable Debian 13.7 host |
| B2 | The development environment is WSL2, not the target | Microsoft kernel `6.18.54.1-microsoft-standard-WSL2`; no `/dev/binder*`; no `/dev/kvm`; `faux_driver` DRM; no real audio/USB | A Debian 13.7 VM or bare-metal install with the official Debian kernel |
| B3 | BinderFS is disabled in the official Debian kernel | `# CONFIG_ANDROID_BINDERFS is not set` in `config-6.12.107+deb13-amd64` | Runtime test of the legacy binder-device path on the Debian kernel |
| B4 | Hyprland 0.50.1 has not been built | Only CMake metadata was inspected | Build test on Debian 13.7 with GCC 14.2 |
| B5 | The Waydroid backport has not been built | Only Debian package metadata was inspected | Build `libglibutil1`, `libgbinder1`, `python3-gbinder`, `waydroid` against Trixie |
| B6 | Secure Boot state is unknown | Windows query was denied without elevation | Check firmware setup on the target laptop |
| B7 | No Git repository exists | `git status` fails; `git` is not installed in WSL | Approve repository initialization and commit policy |
| B8 | Android images are not version-controlled | 2.3 GB of `.img` files; excluded by `.gitignore` | Approve artifact storage/checksum policy |

No destructive action, package installation, kernel change, service change, or disk operation has been performed.

---

## D1 — Build and test host

**Question:** Where will Phase 1 actually run?

| Option | Advantages | Disadvantages |
|---|---|---|
| **A. Debian 13.7 VM with UEFI (recommended)** | Reproducible, disposable, root available, can test the real Debian kernel and GRUB | No real GPU/audio/USB passthrough by default; slower |
| B. Bare-metal Debian 13.7 on a spare disk | Real hardware evidence | Risk to existing data; requires disk authorization |
| C. WSL2 only | Already available | Cannot test boot, the Debian kernel, BinderFS/legacy binder, Hyprland, Waydroid, GPU, audio, or suspend |

**Recommendation:** A Debian 13.7 VM for build/package work, plus the target laptop for hardware validation. WSL is acceptable only as an editor and static-test runner.

**Approval needed:** confirm option A, B, or C, and provide root access or run the scripts manually.

---

## D2 — Kernel and binder policy

**Question:** How should ElvonOS satisfy Waydroid's binder requirement while keeping the original Debian kernel?

| Option | V1 compliant? | Assessment |
|---|---|---|
| **A. Stock `linux-image-amd64` + legacy binder devices (recommended)** | Yes | Debian's `binder_linux` module supports `devices="anbox-binder,anbox-vndbinder,anbox-hwbinder"`. Waydroid 1.6.3 probes those names and bind-mounts them to `/dev/binder`, `/dev/vndbinder`, `/dev/hwbinder` inside LXC. No kernel patch, no DKMS, Secure Boot preserved. Runtime test still required. |
| B. Build a Debian kernel with `CONFIG_ANDROID_BINDERFS=y` | No | Violates “original Debian kernel” and “do not patch or replace the Debian kernel”. |
| C. Out-of-tree binder DKMS module | No | Replaces a kernel subsystem, requires module signing, breaks the V1 kernel rule. |
| D. Wait for Debian to enable BinderFS | N/A | Not available in 13.7; would block V1 indefinitely. |

**Recommendation:** A. Treat BinderFS as unavailable in V1 and document the deviation explicitly.

**Approval needed:** approve the legacy-device policy, and authorize the runtime test on a real Debian kernel.

---

## D3 — Hyprland version

**Question:** Which Hyprland line should V1 pin?

| Option | Assessment |
|---|---|
| **A. Hyprland 0.50.1 (recommended)** | Newest pre-Lua line that fits Trixie's Wayland stack (`wayland-protocols` 1.44). Requires aquamarine 0.9.3, hyprutils 0.8.2, hyprlang 0.6.x, hyprcursor 0.1.13, hyprgraphics 0.1.4, hyprwayland-scanner 0.4.x. Uses C++26; GCC 14.2 build risk. |
| B. Hyprland 0.49.0 (fallback) | Lower library minimums, but still C++26. Use only if 0.50.1 fails to build. |
| C. Hyprland 0.57.0 from Debian unstable | Requires an unstable-only stack: libstdc++ 16, Lua 5.5, aquamarine 0.15, hyprutils 0.14, hyprwire, newer RE2 ABI. Rejected for V1. |
| D. Different compositor | Out of scope; the master prompt requires Hyprland. |

**Recommendation:** A, with B as the documented fallback. Do not mix unstable binaries into Trixie.

**Approval needed:** approve 0.50.1 as the V1 candidate; the build test decides whether B is needed.

---

## D4 — Desktop UI stack

**Question:** What should the original ElvonOS desktop be built with?

| Option | Advantages | Disadvantages |
|---|---|---|
| **A. Qt 6 / QML + LayerShellQt (recommended)** | Qt 6.8.2 and LayerShellQt 6.3.4 are in Trixie; strong Wayland support; QML suits animated, Android-like UI; one consistent stack | Qt is also a native Linux toolkit; must be restricted to ElvonOS infrastructure/UI, not exposed as a user app platform |
| B. GTK 4 + gtk4-layer-shell | Also in Trixie; good Wayland support | GNOME-oriented idioms; mixing GTK and Qt later is likely; less suitable for a custom shell |
| C. Quickshell (Qt/QML) | Purpose-built for Wayland shells | Not packaged in Trixie; adds another upstream stack to vendor |

**Recommendation:** A. The desktop is an ElvonOS component, not a general Qt application platform. Users install Android APKs, not Qt apps.

**Approval needed:** approve Qt 6/QML + LayerShellQt.

---

## D5 — Installer

**Question:** How should the ISO install ElvonOS?

| Option | Assessment |
|---|---|
| **A. live-build + Calamares (recommended)** | Both are in Trixie. Calamares provides partitioning, LUKS, user creation, locale, and bootloader installation. ElvonOS adds branding and post-install hooks. |
| B. Custom installer | Large scope; delays V1; duplicates well-tested disk logic. |
| C. Debian Installer preseed | Robust but not a friendly live-install flow; harder to integrate first-boot Android setup. |

**Recommendation:** A. Calamares is infrastructure, not the ElvonOS identity.

**Approval needed:** approve Calamares for V1.

---

## D6 — Display manager

| Option | Assessment |
|---|---|
| **A. SDDM (recommended)** | Qt 6-based, in Trixie, works with Wayland sessions. Branding can be replaced later. |
| B. greetd + tuigreet | Minimal, text-based, easy to debug; less polished for end users. |
| C. No display manager / autologin | Convenient for a single-user appliance, but weak for multi-user and lock-screen expectations. |

**Recommendation:** A for V1; a fully branded ElvonOS greeter is later work.

**Approval needed:** confirm A or B. This does not block Phase 1.

---

## D7 — Root filesystem

| Option | Assessment |
|---|---|
| **A. ext4 (recommended)** | Simple, mature, well supported by Calamares and Debian tooling. |
| B. btrfs | Snapshots and rollback are attractive, but add complexity and a recovery design that V1 does not need yet. |

**Recommendation:** A for V1. Keep btrfs as a future option; do not promise snapshots.

**Approval needed:** confirm A or B. Does not block Phase 1.

---

## D8 — NVIDIA policy

**Question:** What does V1 promise for the RTX 3070 Laptop GPU?

| Option | Assessment |
|---|---|
| **A. AMD iGPU is the default; NVIDIA is tested separately (recommended)** | The Cezanne iGPU has the best-supported open stack (`amdgpu` + Mesa RADV). NVIDIA hybrid graphics add render-node selection and Wayland/Waydroid variables. |
| B. Nouveau only | Open and in-tree, but performance and power management may be limited. |
| C. Proprietary NVIDIA driver as the default | Better performance, but DKMS, Secure Boot signing, and Wayland/Waydroid compatibility must be proven. |

**Recommendation:** A. Document NVIDIA as “supported where tested”, not as a guaranteed V1 acceleration path. Never report software rendering as GPU acceleration.

**Approval needed:** confirm the policy; NVIDIA testing is Phase 6.

---

## D9 — Waydroid image delivery

| Option | Assessment |
|---|---|
| **A. Bundle `system.img` and `vendor.img` in the ISO (recommended)** | Offline first boot; no unverified download; ISO grows to roughly 3–4 GiB. |
| B. Download at first boot | Smaller ISO, but requires network and checksum verification; worse first-boot experience. |
| C. Both: bundle by default, allow a verified download | Most flexible; more code and testing. |

**Recommendation:** A for V1. The images are already available locally and their SHA256 values are recorded.

**Approval needed:** confirm A. Does not block Phase 1.

---

## D10 — Android application distribution

**Recommendation:**

- Do not bundle Google Play Services.
- Do not bundle Aurora Store or F-Droid by default; provide optional, user-initiated installation.
- Keep microG optional and separately configurable.
- Support direct APK installation from the ElvonOS file manager.
- Do not claim Play Store compatibility.

**Approval needed:** confirm this policy. It affects Phase 4/5 UI and legal review, not Phase 1.

---

## D11 — Service implementation language

| Option | Assessment |
|---|---|
| **A. Rust for new system services, D-Bus interfaces, systemd units (recommended)** | Memory safety, good D-Bus crates, fits the master prompt. |
| B. C++ for everything | Consistent with Hyprland, but slower to develop and more error-prone. |
| C. Python for everything | Fast to prototype, but weaker for long-running privileged services. |

**Recommendation:** A for `elvonos-hardware`, `elvonos-android-manager`, `elvonos-app-manager`, `elvonos-settings-service`, `elvonos-update`, `elvonos-recovery`, `elvonos-desktop-service`. Use Python only for thin Waydroid integration glue where upstream is Python, and C only where a native interface requires it. The UI remains one Qt/QML stack.

**Approval needed:** confirm A. Does not block Phase 1.

---

## D12 — ElvonOS package repository and signing

**Question:** How will custom `.deb` packages be distributed and verified?

**Recommendation:**

- A signed APT repository with `Origin: ElvonOS`, `Suite: elvonos`, `Codename: v1`.
- A dedicated archive key stored outside the repository; the public key ships at `/usr/share/keyrings/elvonos-archive-keyring.gpg`.
- Reproducible builds record source checksums and resolved package versions.
- The ISO may carry a local `file:` repository for offline installation.

**Approval needed:** decide who holds the signing key and where it is stored. Do not commit a private key.

---

## D13 — Git and artifact policy

**Recommendation:**

- Initialize a Git repository at the project root.
- Commit source, documentation, package manifests, configuration, build scripts, and tests.
- Do not commit the 2.3 GB Android images; commit their SHA256 values and a fetch/verify script instead.
- Do not commit build outputs, logs, `.deb` files, or signing keys.
- Use signed commits/tags for releases if the user has a signing key.

**Approval needed:** authorize `git init` and the first commit. This is non-destructive but changes repository state.

---

## D14 — Telemetry and privacy

**Recommendation:** no telemetry by default; no analytics; no automatic upload of logs. Any future diagnostic upload must be explicit, opt-in, and documented.

**Approval needed:** confirm. Does not block Phase 1.

---

## D15 — Branding and assets

**Needed later:** ElvonOS logo, wordmark, color palette, icon style, wallpaper, Calamares branding, greeter theme, and font licensing.

**Recommendation:** use original assets or properly licensed ones; do not copy Windows, Android, KDE, or GNOME trademarks. This is Phase 4/7 work.

---

## D16 — Android image update policy

**Recommendation:**

- Pin the current Android 13 / LineageOS 20 VANILLA image for V1.
- Disable Waydroid's automatic OTA updater for the bundled image and document how to update manually with checksum verification.
- Do not claim Android 17 support; treat a future image as a separate compatibility project.

**Approval needed:** confirm. Does not block Phase 1.

---

## D17 — Recovery model

**Recommendation:**

- Retain the previous Debian kernel in GRUB.
- Provide `elvonos-recovery` for package reinstall, Waydroid reset (with confirmation and backup), and log collection.
- Do not promise btrfs snapshots or A/B system images in V1.
- Never overwrite user data during updates.

**Approval needed:** confirm. Does not block Phase 1.

---

## Minimum approvals to start Phase 1

1. **D1:** a Debian 13.7 build/test host with root (VM or bare metal).
2. **D2:** approve the stock-kernel legacy binder-device policy and the runtime test.
3. **D13:** authorize Git initialization (optional but recommended before builds).
4. **Root authorization:** permission to install the packages in `base/packages/build-host.list` on that host.

Once these are approved, run:

```bash
./build/phase1/check-host.sh
sudo ./build/phase1/install-build-deps.sh --yes
sudo ./build/phase1/build-rootfs.sh --profile phase1
./build/phase1/validate-rootfs.sh build/out/rootfs
```

Then boot the result on the Debian kernel and record evidence in `documentation/test-results/phase1.md`.

**Do not start Phase 2 until Phase 1 boot and binder evidence exists on the real Debian kernel.**
