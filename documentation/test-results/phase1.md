# Phase 1 — Debian Foundation: Test Results

Status: **NOT RUN**
Last updated: 2026-11-01

No Phase 1 build or boot test has been executed. This file is a checklist and evidence template, not a result.

---

## Environment

| Item | Value |
|---|---|
| Build host | NOT SET |
| Host OS | NOT SET |
| Kernel | NOT SET |
| Root method | NOT SET (no passwordless sudo in the current WSL environment) |
| Debian archive | 13.7 at inspection time |
| Target kernel | `linux-image-amd64` 6.12.107-1 (expected; must be verified on the built system) |
| Target hardware | Lenovo 82JU, Ryzen 5 5600H, AMD Cezanne iGPU + NVIDIA RTX 3070 Laptop |

---

## Gate 1 — Host readiness

Command:

```bash
./build/phase1/check-host.sh
```

Expected: all required checks PASS; WSL warnings are acceptable only for packaging, not boot validation.

Result: **NOT RUN**

Evidence: none.

---

## Gate 2 — Build dependencies

Command:

```bash
sudo ./build/phase1/install-build-deps.sh --yes
```

Expected: `build-host.list` installs cleanly on Debian 13.7; no target kernel or bootloader changes.

Result: **NOT RUN**

Evidence: none.

---

## Gate 3 — Minimal rootfs

Command:

```bash
sudo ./build/phase1/build-rootfs.sh --profile phase1
```

Expected:

- `build/out/rootfs` contains Debian 13 amd64,
- official `linux-image-amd64` and `linux-headers-amd64`,
- firmware, Mesa, PipeWire, NetworkManager,
- the ElvonOS configuration files from `base/configuration/`,
- a package lock in `build/out/packages.lock`.

Result: **NOT RUN**

Evidence: none.

---

## Gate 4 — Rootfs validation

Command:

```bash
./build/phase1/validate-rootfs.sh build/out/rootfs
```

Expected: all checks PASS; no WSL/Microsoft kernel artifacts.

Result: **NOT RUN**

Evidence: none.

---

## Gate 5 — Boot on the official Debian kernel

This cannot be done in the current WSL environment. Use a Debian 13.7 VM with UEFI or the target laptop.

Checklist:

- [ ] UEFI boot reaches GRUB.
- [ ] The selected entry boots the official Debian kernel.
- [ ] `uname -r` reports `6.12.107+deb13-amd64` (or a later official Debian ABI), not `microsoft-standard-WSL2`.
- [ ] `systemctl --failed` is clean.
- [ ] NetworkManager manages Ethernet/Wi-Fi.
- [ ] PipeWire/WirePlumber start; audio devices are visible.
- [ ] At least one DRM render node exists.
- [ ] The previous kernel is retained in the GRUB menu.

Result: **NOT RUN**

Evidence: none.

---

## Gate 6 — Legacy binder devices on the Debian kernel

Commands:

```bash
uname -r
grep -E 'CONFIG_ANDROID_BINDER' /boot/config-$(uname -r)
sudo modprobe -r binder_linux 2>/dev/null || true
sudo modprobe binder_linux devices="anbox-binder,anbox-vndbinder,anbox-hwbinder"
ls -l /dev/anbox-binder /dev/anbox-vndbinder /dev/anbox-hwbinder
cat /sys/module/binder_linux/parameters/devices
cat /proc/filesystems | grep binder || echo "binderfs absent (expected)"
```

Expected:

- all three `/dev/anbox-*` devices exist,
- the module parameter lists all three names,
- `binderfs` is absent,
- no kernel taint or module-load error.

Result: **NOT RUN**

Evidence: none.

This is the gate that decides whether the stock-kernel policy is viable. If it fails, stop and revisit `09-decisions-required.md` D2.

---

## Gate 7 — Hardware smoke test

On the target laptop or a comparable machine:

- [ ] AMD iGPU: `amdgpu` loaded, render node present, `vulkaninfo --summary` shows RADV.
- [ ] Wi-Fi: MT7921 scans and connects.
- [ ] Bluetooth: adapter visible.
- [ ] Audio: speakers, headphones, microphone.
- [ ] NVMe and USB storage.
- [ ] Suspend/resume.
- [ ] External monitor.

Result: **NOT RUN**

Evidence: none.

---

## Summary

| Gate | Result |
|---|---|
| 1 — Host readiness | NOT RUN |
| 2 — Build dependencies | NOT RUN |
| 3 — Rootfs | NOT RUN |
| 4 — Rootfs validation | NOT RUN |
| 5 — Boot on Debian kernel | NOT RUN |
| 6 — Legacy binder devices | NOT RUN |
| 7 — Hardware smoke test | NOT RUN |

Phase 1 is **not complete**. No compatibility claim beyond static inspection is made.
