# 05 — GPU and Hardware Compatibility Report

Primary target: **Lenovo 82JU / Legion 5 15ACH6H class**
CPU: **AMD Ryzen 5 5600H**
GPU: **AMD Radeon Cezanne iGPU + NVIDIA GeForce RTX 3070 Laptop GPU**
Base: **Debian 13 Trixie**

---

## 1. Host inventory

| Component | Detected hardware | Linux driver / firmware | Status |
|---|---|---|---|
| CPU | AMD Ryzen 5 5600H, 6C/12T | `amd64-microcode`, `powernow-k8`/`amd-pstate` | Debian-supported; test scaling/thermal |
| iGPU | AMD Radeon Graphics (Cezanne, `0x1638`) | `amdgpu`, `firmware-amd-graphics`, Mesa RADV | Primary graphics target |
| dGPU | NVIDIA RTX 3070 Laptop (GA104) | `nouveau` or proprietary `nvidia-driver`; `firmware-nvidia-gsp` | Secondary; test separately |
| RAM | 21.3 GB | — | Sufficient |
| NVMe | SK Hynix HFS512GDE9X084N 512 GB | `nvme` | Debian-supported |
| External storage | USB 3.0 SCSI disk 500 GB; 2 TB USB disk | `usb-storage`, `uas` | Test hotplug/USB-C |
| Wi-Fi | MediaTek Wi-Fi 6 MT7921 | `mt7921e`, `firmware-mediatek` | Debian-supported; firmware required |
| Bluetooth | MediaTek MT7921 | `btusb`, `btmtk`, `firmware-mediatek`, BlueZ | Debian-supported; firmware required |
| Ethernet | Realtek PCIe GbE | `r8169`, `firmware-realtek` (if needed) | Debian-supported |
| Audio | Realtek HD Audio + NVIDIA HDMI audio | `snd_hda_intel`, `firmware-sof-signed`, PipeWire | Debian-supported; test codecs |
| USB | AMD xHCI 3.10 controllers, USB 2/3 hubs | `xhci_hcd`, `usbhid` | Debian-supported |
| Webcam | USB composite device(s) present | `uvcvideo` | Test |
| Input | Laptop keyboard/touchpad; USB/Bluetooth HID | `hid-generic`, `hid-multitouch`, `libinput` | Test |
| Secure Boot | Query denied without elevation | Shim + signed Debian kernel | Check firmware setup |
| Battery | Laptop platform; Windows returned AC/Surface ACPI entries | `battery`, `acpi` | Verify `upower -d` on Linux |

Windows reports the machine as Windows 10 Home 22H2 (build 19045). This does not affect the Linux target.

---

## 2. GPU compatibility

### AMD Cezanne iGPU — primary

- Driver: `amdgpu` (in-tree module, `CONFIG_DRM_AMDGPU=m`).
- Firmware: `firmware-amd-graphics` 20250410-2.
- Userspace: Mesa 25.0.7 (`libgl1-mesa-dri`, `mesa-vulkan-drivers`), RADV for Vulkan.
- Wayland: Hyprland/aquamarine uses DRM/KMS + GBM + EGL.
- Waydroid: use the AMD render node by default; verify `ro.hardware.egl` and a GPU-rendered app.
- This is the recommended default for V1.

### NVIDIA RTX 3070 Laptop — secondary

Two mutually exclusive options:

| Option | Packages | Trade-offs |
|---|---|---|
| Nouveau | in-tree `nouveau`, `firmware-nvidia-gsp` | Open, but performance/power management may be limited; test Wayland |
| Proprietary | Debian `nvidia-driver` (Trixie version) + `firmware-nvidia-gsp` | Better performance; Wayland/Waydroid compatibility must be tested; kernel module updates via DKMS |

V1 must not promise NVIDIA acceleration until tested. Hybrid graphics require explicit render-node selection or `DRI_PRIME`/`__NV_PRIME_RENDER_OFFLOAD` handling. Do not let Waydroid silently pick the wrong GPU.

### Intel (target architecture, not present on this host)

- `i915` and `xe` modules are present in the Debian kernel.
- Mesa ANV for Vulkan.
- `firmware-intel-graphics`, `firmware-intel-sound`, `intel-microcode`.
- Test on an Intel laptop/desktop before claiming support.

### Software rendering

`LIBGL_ALWAYS_SOFTWARE=1` / `llvmpipe` is a diagnostic fallback only. It must never be reported as GPU acceleration.

---

## 3. Audio compatibility

Target stack:

```
ALSA -> PipeWire 1.4.2 -> WirePlumber 0.5.8 -> speakers/headphones/mic/Bluetooth
```

Required packages:

- `pipewire`, `pipewire-pulse`, `wireplumber`
- `alsa-utils`
- `libspa-0.2-bluetooth` (Bluetooth audio)
- `bluez`, `bluez-firmware` (if needed)
- `firmware-sof-signed` (SOF DSP, if the platform uses it)
- `firmware-realtek` (if the codec requires it)

Tests:

- internal speakers and headphones,
- internal microphone and headset microphone,
- USB audio,
- Bluetooth A2DP/HFP,
- Android audio routing and volume synchronization,
- no duplicate PulseAudio server.

---

## 4. Networking compatibility

| Interface | Driver | Firmware | Test |
|---|---|---|---|
| Wi-Fi MT7921 | `mt7921e` | `firmware-mediatek` | scan, WPA2/WPA3, suspend/resume, 2.4/5/6 GHz |
| Bluetooth MT7921 | `btusb`/`btmtk` | `firmware-mediatek` | pair, audio, HID, suspend/resume |
| Ethernet RTL8168 | `r8169` | `firmware-realtek` if needed | DHCP, IPv6, link speed |
| USB Wi-Fi (optional) | `rtw88`/`rtl8xxxu` | `firmware-realtek` | hotplug |
| Android container | veth + NAT + nftables | — | HTTP, DNS, IPv6, isolation |

NetworkManager 1.52.1 manages host connections. Waydroid's network script manages the container; do not let both create conflicting NAT rules.

---

## 5. Storage and USB

- NVMe: `nvme`, ext4 root; optional btrfs for snapshots (decide in Phase 7).
- USB: `usb-storage`/`uas`, automount via udisks2 (add `udisks2` if the file manager uses it).
- External drives: exFAT/NTFS support requires `exfatprogs`/`ntfs-3g` if needed.
- Android shared storage is exposed through Waydroid's data directory; do not expose raw Linux internals in the file manager.

---

## 6. Power and thermal

- CPU frequency scaling: `amd-pstate`/`acpi-cpufreq`.
- Thermal: `k10temp`, `thermal_zone*`, `lm-sensors`.
- Battery: `upower`, `acpi`.
- Suspend/resume: test with `systemctl suspend`; Waydroid must survive or be restarted cleanly.
- NVIDIA hybrid power: test runtime PM; do not leave the dGPU powered unnecessarily.

Add `lm-sensors`, `upower`, `powertop` (optional diagnostic) to the hardware test image, not necessarily the default install.

---

## 7. What WSL cannot verify

The WSL guest exposes:

- a `faux_driver` DRM device, not AMD/NVIDIA,
- no `/dev/kvm`,
- no real `/dev/snd`,
- no PCI/USB passthrough,
- WSLg PulseAudio sockets, not the laptop's audio hardware.

Therefore all GPU, audio, Wi-Fi, Bluetooth, USB, suspend, and boot tests are **pending real hardware**. The host inventory above is from Windows, not from a Linux boot.

---

## 8. Hardware test matrix

### Required for V1 release

| Test | AMD iGPU | NVIDIA | Intel (if available) |
|---|---|---|---|
| UEFI boot + GRUB | required | required | required |
| Hyprland startup | required | required | required |
| DRM/KMS modeset | required | required | required |
| Vulkan (`vulkaninfo`) | required | required | required |
| Waydroid GPU rendering | required | required | required |
| Multi-monitor | required | required | required |
| Audio playback/mic | required | required | required |
| Wi-Fi + Bluetooth | required | required | required |
| Suspend/resume | required | required | required |
| External USB storage | required | required | required |
| Touchpad/keyboard | required | required | required |

### Evidence rules

- Record the exact kernel, Mesa, firmware, and GPU driver versions.
- Record `vulkaninfo --summary` and `glxinfo -B`/`eglinfo` output.
- Do not claim GPU acceleration without a renderer string and a rendered Android app.
- Do not claim suspend/resume without a full cycle and Waydroid/network/audio re-test.
- Virtual machines are supplementary, not a substitute for physical hardware.
