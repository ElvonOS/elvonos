# Phase 1 — Debian Foundation: Test Results

Status: **GATES 1–4 PASSED** (Build & Rootfs Verification Complete; Boot test pending VM/Hardware)  
Last updated: 2026-11-01  

---

## Environment

| Item | Value |
|---|---|
| Build host | WSL2 Debian GNU/Linux 13.5 (Trixie), x86_64 |
| Host OS | Windows 10 Home 22H2 / WSL2 |
| Kernel | `6.18.54.1-microsoft-standard-WSL2` (Build host only) |
| Root method | Passwordless sudo for `kirara` configured |
| Debian archive | 13.7 (main, contrib, non-free-firmware) |
| Target kernel | `linux-image-6.12.107+deb13-amd64` (Official Debian 13 kernel ABI) |
| Target hardware | Lenovo 82JU, Ryzen 5 5600H, AMD Cezanne iGPU + NVIDIA RTX 3070 Laptop |

---

## Gate 1 — Host readiness

Command:
```bash
./build/phase1/check-host.sh
```

Expected: all required checks PASS; WSL warnings acceptable for rootfs building.  
Result: **PASS**  
Evidence:
```
==> 1. Checking Architecture: [PASS] x86_64
==> 2. Checking Operating System: [PASS] Debian GNU/Linux 13 (trixie)
==> 3. Checking Kernel: [WARN] WSL2 environment
==> 4. Checking Memory and Storage: [PASS] RAM: 10 GB, Disk free: 951 GB
==> 5. Checking Root / Sudo: [PASS] Passwordless sudo is available
==> 6. Checking Network Access: [PASS] deb.debian.org reachable
==> 7. Checking Essential Tools: [PASS] bash, curl, git, tar, xz, jq
==> 8. Checking Rootfs Tools: [PASS] mmdebstrap, debootstrap, live-build, squashfs-tools, xorriso
```

---

## Gate 2 — Build dependencies

Command:
```bash
sudo ./build/phase1/install-build-deps.sh --yes
```

Expected: `build-host.list` installs cleanly.  
Result: **PASS**  
Evidence: 59 top-level build packages installed successfully (exit code 0).

---

## Gate 3 — Minimal rootfs

Command:
```bash
sudo ./build/phase1/build-rootfs.sh --profile phase1
```

Expected: Clean Debian 13 amd64 rootfs built at `build/out/rootfs` with `packages.lock`.  
Result: **PASS**  
Evidence:
```
Total unique packages requested: 57
mmdebstrap completed successfully in 2791.9s.
Applied ElvonOS binder configs, APT sources, preferences, hostname.
Package lock written to build/out/packages.lock (477 packages installed total).
```

---

## Gate 4 — Rootfs validation

Command:
```bash
./build/phase1/validate-rootfs.sh build/out/rootfs
```

Expected: All structure, kernel, service, and binder configuration checks pass.  
Result: **PASS**  
Evidence:
```
==> 1. Verifying Directory Structure: [PASS] /bin, /etc, /usr, /boot, /dev, /proc, /sys, /run
==> 2. Verifying Debian 13 Official Kernel: [PASS] vmlinuz-6.12.107+deb13-amd64
==> 3. Verifying Kernel Configuration:
  [PASS] config-6.12.107+deb13-amd64
  [PASS] CONFIG_ANDROID_BINDER_IPC=m
  [PASS] CONFIG_ANDROID_BINDERFS is not set (confirmed stock Debian kernel)
==> 4. Verifying ElvonOS Target Configuration:
  [PASS] modprobe.d/elvonos-binder.conf present (devices="anbox-binder,anbox-vndbinder,anbox-hwbinder")
  [PASS] modules-load.d/elvonos-binder.conf present
  [PASS] Hostname configured: elvonos
==> 5. Verifying Core Base Services:
  [PASS] systemd init system present
  [PASS] D-Bus daemon present
  [PASS] NetworkManager present
  [PASS] PipeWire present
==> 6. Verifying Graphics & Mesa:
  [PASS] Mesa DRI GPU drivers present
```

---

## Gate 5 — Boot on the official Debian kernel (QEMU UEFI Boot Test)

Command:
```bash
./build/phase1/test-qemu.sh
```

Result: **PASS**  
Evidence:
```text
BdsDxe: loading Boot0001 "UEFI QEMU DVD-ROM QM00003 "
GNU GRUB  version 2.12-9+deb13u2
Booting `ElvonOS V1 Live (Debian 13 + Sway/Hyprland + Waydroid)'
EFI stub: Loaded initrd from LINUX_EFI_INITRD_MEDIA_GUID device path
[    0.000000] Linux version 6.12.107+deb13-amd64 (debian-kernel@lists.debian.org)
[    0.000000] Command line: BOOT_IMAGE=/live/vmlinuz boot=live components console=tty0 console=ttyS0,115200n8
...
Starting systemd-udevd version 257.13-1~deb13u1
[   25.411080] systemd[1]: systemd 257.13-1~deb13u1 running in system mode
...
[  OK  ] Reached target sysinit.target - System Initialization.
[  OK  ] Finished live-config.service - live-config the boot process (late userspace)..
[  OK  ] Reached target basic.target - Basic System.
[  OK  ] Started dbus.service - D-Bus System Message Bus.
[  OK  ] Started lxcfs.service - FUSE filesystem for LXC.
[  OK  ] Reached target multi-user.target - Multi-User System.
[  OK  ] Reached target graphical.target - Graphical Interface.

Debian GNU/Linux 13 elvonos ttyS0
elvonos login:
```

---

## Gate 6 — Legacy binder devices on the Debian kernel

Pending execution on bare-metal hardware.  
Result: **PENDING (HARDWARE)**

---

## Gate 7 — Hardware smoke test

Target hardware (Lenovo 82JU).  
Result: **PENDING (HARDWARE)**

---

## Summary

| Gate | Result | Evidence Quality |
|---|---|---|
| 1 — Host readiness | **PASS** | Runtime command output |
| 2 — Build dependencies | **PASS** | Package manager execution |
| 3 — Rootfs | **PASS** | 477 installed packages, `packages.lock` |
| 4 — Rootfs validation | **PASS** | Verified stock kernel, binder config, Mesa, PipeWire |
| 5 — Boot on Debian kernel | **PASS** | Verified via QEMU UEFI boot to `graphical.target` |
| 6 — Legacy binder devices | PENDING | To be verified on bare-metal hardware |
| 7 — Hardware smoke test | PENDING | Target Lenovo Legion laptop |
