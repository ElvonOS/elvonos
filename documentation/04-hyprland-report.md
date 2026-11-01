# 04 — Hyprland Package and Dependency Report

Target compositor: **Hyprland**
Debian 13 Trixie package status: **not packaged**
Debian unstable package: **0.57.0+ds-1**
ElvonOS V1 candidate: **Hyprland 0.50.1** plus pinned Hypr libraries

---

## 1. Verdict

**Hyprland must be built and packaged by ElvonOS for Trixie.** There is no stable Debian package, and the unstable 0.57.0 package cannot be installed directly: it depends on an unstable-only stack (C++/libstdc++ 16, Lua 5.5, aquamarine 0.14, hyprutils 0.13, hyprwire, newer RE2/ABI packages).

Hyprland **0.50.1** is the selected candidate because:

- it is the newest pre-Lua release line that fits the Trixie era,
- it requires `wayland-protocols >= 1.43`, satisfied by Trixie's 1.44,
- it uses the same aquamarine/hyprutils/hyprlang/hyprcursor/hyprgraphics family that can be built from source,
- it avoids Lua 5.5, libstdc++ 16, hyprwire, and the newer unstable ABI.

**C++26 risk:** Hyprland 0.50.1 sets `CMAKE_CXX_STANDARD 26`. Trixie ships GCC 14.2, which accepts `-std=c++26` but does not implement every C++26 feature. A build test is mandatory. If 0.50.1 fails, fall back to 0.49.0 (same library family, lower minimums). Do not silently switch to an unstable binary.

---

## 2. Why not Debian unstable's 0.57.0

`hyprland 0.57.0+ds-1` depends on packages that do not exist in Trixie, including:

```
libaquamarine14 (>= 0.15.1)
libhyprcursor0 (>= 0.1.13)
libhyprgraphics4 (>= 0.5.1)
libhyprutils13 (>= 0.14.3)
libhyprwire3 (>= 0.3.1)
liblua5.5-0 (>= 5.5.0)
libre2-11-absl20260526
libstdc++6 (>= 16.2)
libsdbus-c++2 (>= 2.3.1)
```

Installing these from unstable into a stable base would mix ABIs and violate the stability goal. Rebuilding the entire stack (including a newer compiler/libstdc++) is disproportionate for V1.

---

## 3. Pinned source stack

| Component | Candidate version | Purpose |
|---|---|---|
| Hyprland | 0.50.1 | compositor |
| aquamarine | 0.9.3 | DRM/backend abstraction |
| hyprutils | 0.8.2 | shared utilities |
| hyprlang | 0.6.x (min 0.3.2) | config parser |
| hyprcursor | 0.1.13 (min 0.1.7) | cursor themes |
| hyprgraphics | 0.1.4 (min 0.1.3) | graphics helpers |
| hyprland-protocols | 0.6.4 (min 0.6.4) | Wayland protocol XML |
| hyprwayland-scanner | 0.3.10+ | protocol code generator |
| wayland-protocols | Trixie 1.44 | satisfies Hyprland >= 1.43 |

Exact tags must be resolved and SHA256-pinned in `build/phase2/sources.lock` before the build. Do not use floating branches.

Build order:

```
wayland-protocols (Trixie package, no rebuild)
hyprland-protocols
hyprwayland-scanner
hyprutils
hyprlang
hyprcursor
hyprgraphics
aquamarine
Hyprland
```

Each component should be installed into a staging directory and packaged as a `.deb` with a proper `control` file, or built with Debian packaging. The final repository must contain source and binary packages with checksums.

---

## 4. Trixie build dependencies

### Toolchain

| Package | Trixie version |
|---|---|
| `cmake` | 3.31.6-2 |
| `ninja-build` | 1.12.1-1 |
| `g++` | 4:14.2.0-1 (GCC 14.2) |
| `pkg-config` | 1.8.1-4 |
| `git` | 1:2.47.3-0+deb13u1 |
| `debhelper` | 13.24.2 |
| `devscripts` | 2.25.15+deb13u1 |

### Wayland / input / DRM

`libwayland-dev` 1.23.1-3, `wayland-protocols` 1.44-1, `libxkbcommon-dev` 1.7.0-2, `libinput-dev` 1.28.1-1+deb13u1, `libdrm-dev` 2.4.124-2, `libgbm-dev` 25.0.7-2+deb13u1, `libegl-dev` 1.7.0-1+b2, `libgles-dev` 1.7.0-1+b2, `libgl-dev`, `libudev-dev` 257.13-1~deb13u1, `libseat-dev` 0.9.1-1, `libdisplay-info-dev` 0.2.0-2, `hwdata` 0.394-1.

### XCB / XWayland

`libxcb1-dev`, `libxcb-composite0-dev` 1.17.0-2+b1, `libxcb-errors-dev` 1.0.1-4, `libxcb-icccm4-dev` 0.4.2-1, `libxcb-render0-dev` 1.17.0-2+b1, `libxcb-res0-dev` 1.17.0-2+b1, `libxcb-xfixes0-dev` 1.17.0-2+b1.

### Graphics / text / accessibility

`libpixman-1-dev` 0.44.0-3, `libcairo2-dev` 1.18.4-1+b1, `libpango1.0-dev` 1.56.3-1, `liblcms2-dev` 2.16-2+deb13u2, `libcanberra-dev` 0.30-18, `libglib2.0-dev` 2.84.4-3~deb13u5, `libxcursor-dev`.

### Hypr dependencies

`libtomlplusplus-dev` 3.4.0+ds-0.2+b1, `libmuparser-dev` 2.3.4-1+b1, `libudis86-dev` 0+20221013-1.1 (Hyprland falls back to its subproject if absent), `libre2-dev` 20240702-3+b1, `uuid-dev`, `libzip-dev` 1.11.3-2, `libmagic-dev` 1:5.46-5, `libjpeg-dev` 1:2.1.5-4, `libwebp-dev` 1.5.0-0.1.

### Not required for 0.50.1

- `liblua5.5-dev` — the Lua config system is not in 0.50.1.
- `libglaze-dev` — not referenced by the 0.50.1 build.
- `libsdbus-c++-dev` — not required by the 0.50.1 core build.
- `hyprwire` — not part of 0.50.1.

If a later component needs one of these, it must be added deliberately with a version pin.

---

## 5. Runtime packages

Hyprland needs at runtime:

- Mesa (`libgl1-mesa-dri`, `mesa-vulkan-drivers`),
- `libegl1`, `libgles2`, `libgbm1`,
- `libinput`, `libxkbcommon`, `libwayland-server`,
- `libseat` (logind backend),
- `xwayland` (optional; needed for X11 clients only),
- `xdg-desktop-portal` and a desktop portal,
- `polkitd` for privileged requests,
- `pipewire`/`wireplumber` for screen sharing/audio,
- fonts and cursor themes.

`xdg-desktop-portal-hyprland` is **not in Trixie**. It is optional for V1; build it later only if screen sharing or portal-dependent features are required. Do not make the core desktop depend on it.

---

## 6. Session and configuration policy

- Hyprland is infrastructure, not the user-facing desktop.
- ElvonOS must generate its own Hyprland configuration and control it through `hyprctl`/IPC and supported protocols.
- Do not expose raw Hyprland config files as the user settings UI.
- The session file should launch Hyprland and then the ElvonOS shell:

```
/usr/share/wayland-sessions/elvonos.desktop
Exec=/usr/bin/elvonos-session
```

`elvonos-session` starts Hyprland (or is launched by the display manager), waits for the Wayland socket, starts the ElvonOS shell and services, and starts the Waydroid session.

- Display manager: `sddm` 0.21.0 is available and Qt 6-based; `greetd` 0.10.3 + `tuigreet` 0.9.1 is a minimal fallback. A branded ElvonOS greeter is Phase 7 work. Do not make SDDM the product identity.
- Multi-monitor, workspaces, tiling, and floating windows are Hyprland features; the ElvonOS taskbar and window list consume them through IPC.

### Hyprland IPC used by ElvonOS

- `hyprctl -j monitors` — display topology
- `hyprctl -j clients` — window list
- `hyprctl -j workspaces` — workspace state
- `hyprctl -j activeworkspace` — current workspace
- `hyprctl dispatch ...` — focus, move, resize, workspace actions
- Hyprland event socket — subscribe to workspace/window/monitor events

The desktop service must degrade gracefully if Hyprland is not running.

---

## 7. Build and runtime risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| GCC 14 cannot compile C++26 code in 0.50.1 | Medium | Build test early; fall back to 0.49.0; do not use unstable binaries |
| `wayland-protocols 1.44` missing a protocol required by 0.50.1 | Low | 0.50.1 requires >=1.43; verify configure output |
| `re2` pkg-config missing in Trixie | Low/Medium | Verify `re2.pc`; add a local `.pc` or use CMake config if needed |
| `hyprwayland-scanner` build mismatch | Medium | Pin 0.3.10+ and test protocol generation |
| Aquamarine DRM/backend issues on hybrid AMD/NVIDIA | Medium | Test on AMD iGPU first; NVIDIA separately |
| Hyprland config API changes | Medium | Pin compositor version for V1; do not auto-update |
| Portal/screen sharing absent | Low for V1 | Optional; build `xdg-desktop-portal-hyprland` later |

---

## 8. Acceptance criteria (Phase 2)

- [ ] Hyprland 0.50.1 builds from pinned sources on Debian 13.7 with GCC 14.2.
- [ ] All hypr libraries build and package cleanly.
- [ ] Hyprland starts on the target AMD iGPU under Wayland.
- [ ] Keyboard, mouse, touchpad, and display hotplug work.
- [ ] Multi-monitor works.
- [ ] `hyprctl` JSON and event socket work.
- [ ] A Qt 6 LayerShellQt panel can reserve space and stay above windows.
- [ ] Audio works through PipeWire/WirePlumber.
- [ ] Session starts from SDDM (or greetd) and logs out cleanly.
- [ ] No Hyprland configuration file is exposed as the user settings UI.

Until these pass, Hyprland is **not** declared integrated.
