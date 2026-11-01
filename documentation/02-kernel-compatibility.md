# 02 — Original Debian Kernel Compatibility Report

Target kernel package: **`linux-image-amd64` 6.12.107-1**
Kernel ABI: **`6.12.107+deb13-amd64`**
Config inspected from the actual signed Debian package:
`linux-image-6.12.107+deb13-amd64_6.12.107-1_amd64.deb`
(not from kernel source defaults, not from the WSL kernel)

---

## 1. Verdict

**Conditionally compatible — no kernel patch is currently required.**

The official Debian kernel has `CONFIG_ANDROID_BINDERFS` **disabled**, so the BinderFS path cannot be used. However, Debian's binder driver is present as a module and supports creating multiple legacy binder devices through its `devices=` module parameter. Waydroid 1.6.3 explicitly probes for those legacy device names and uses them when BinderFS is absent.

This must be **runtime-tested on the real Debian kernel**. It is not proven by the WSL environment.

If the project insists on literal BinderFS support, the only options are:

1. build a Debian kernel with `CONFIG_ANDROID_BINDERFS=y` (a custom kernel, forbidden in V1), or
2. build an out-of-tree binder DKMS module (a kernel subsystem replacement, also outside the V1 "original Debian kernel" rule and a Secure Boot risk).

Neither is recommended for V1. The legacy-device path keeps the stock signed Debian kernel and its signed in-tree module.

---

## 2. Required option matrix

From `boot/config-6.12.107+deb13-amd64`:

| Option | Value | Assessment |
|---|---|---|
| `CONFIG_ANDROID_BINDER_IPC` | `m` | present as `binder_linux` module |
| `CONFIG_ANDROID_BINDERFS` | **not set** | BinderFS unavailable |
| `CONFIG_ANDROID_BINDER_DEVICES` | `"binder"` | default legacy device only |
| `CONFIG_ASHMEM` | absent | not required by Android 13 / modern Waydroid |
| `CONFIG_MEMFD_CREATE` | `y` | present |
| `CONFIG_NAMESPACES` | `y` | present |
| `CONFIG_USER_NS` | `y` | present |
| `CONFIG_PID_NS` | `y` | present |
| `CONFIG_NET_NS` | `y` | present |
| `CONFIG_UTS_NS` | `y` | present |
| `CONFIG_IPC_NS` | `y` | present |
| `CONFIG_CGROUPS` | `y` | present (cgroup v2) |
| `CONFIG_SECCOMP` | `y` | present |
| `CONFIG_SECCOMP_FILTER` | `y` | present |
| `CONFIG_OVERLAY_FS` | `m` | present |
| `CONFIG_VETH` | `m` | present |
| `CONFIG_BRIDGE` | `m` | present |
| `CONFIG_NETFILTER` | `y` | present |
| `CONFIG_NF_NAT` | `m` | present |
| `CONFIG_NF_TABLES` | `m` | present |
| `CONFIG_TMPFS` | `y` | present |
| `CONFIG_DEVTMPFS` | `y` | present |
| `CONFIG_DRM` | `m` | present |
| `CONFIG_DRM_AMDGPU` | `m` | present |
| `CONFIG_DRM_I915` | `m` | present |
| `CONFIG_DRM_XE` | `m` | present |
| `CONFIG_DRM_NOUVEAU` | `m` | present |
| `CONFIG_DRM_VIRTIO_GPU` | `m` | present |
| `CONFIG_SND` | `m` | present |
| `CONFIG_SND_HDA_INTEL` | `m` | present |
| `CONFIG_BT` | `m` | present |
| `CONFIG_CFG80211` / `CONFIG_MAC80211` | `m` | present |
| `CONFIG_EXT4_FS` / `CONFIG_BTRFS_FS` / `CONFIG_F2FS_FS` | `m` | present |
| `CONFIG_USB_STORAGE` / `CONFIG_NVME_CORE` | `m` | present |

---

## 3. Why the legacy binder path is expected to work

The Debian kernel source (`drivers/android/binder.c`, 6.12.107-1) declares:

```c
char *binder_devices_param = CONFIG_ANDROID_BINDER_DEVICES;
module_param_named(devices, binder_devices_param, charp, 0444);
```

and in `binder_init()`:

```c
if (!IS_ENABLED(CONFIG_ANDROID_BINDERFS) &&
    strcmp(binder_devices_param, "") != 0) {
        device_names = kstrdup(binder_devices_param, GFP_KERNEL);
        ...
        while ((device_name = strsep(&device_tmp, ","))) {
                ret = init_binder_device(device_name);
                ...
        }
}
```

`init_binder_device()` registers a misc device for each name. Therefore, when BinderFS is compiled out, loading the module with a comma-separated list creates one legacy device per name.

Waydroid 1.6.3 (`tools/helpers/drivers.py`) does exactly this:

```python
BINDER_DRIVERS = ["anbox-binder", "puddlejumper", "bonder", "binder"]
VNDBINDER_DRIVERS = ["anbox-vndbinder", "vndpuddlejumper", "vndbonder", "vndbinder"]
HWBINDER_DRIVERS = ["anbox-hwbinder", "hwpuddlejumper", "hwbonder", "hwbinder"]
...
command = ["modprobe", "binder_linux",
           "devices=\"{}\"".format(devices)]
```

It then checks `/dev/anbox-binder`, `/dev/anbox-vndbinder`, and `/dev/anbox-hwbinder` (in that order) and proceeds even when `isBinderfsLoaded()` is false.

### Required target configuration

`base/configuration/modprobe.d/elvonos-binder.conf`:

```
options binder_linux devices="anbox-binder,anbox-vndbinder,anbox-hwbinder"
```

`base/configuration/modules-load.d/elvonos-binder.conf`:

```
binder_linux
```

This ensures the module is loaded once, with all three names, before Waydroid starts. If another component loads `binder_linux` first with the default `binder` device, Waydroid's later `modprobe` cannot change the parameters. The modules-load configuration prevents that race.

### Ashmem

`CONFIG_ASHMEM` is absent. Waydroid's `probeAshmemDriver()` attempts `modprobe ashmem_linux` and tolerates failure. Android 13 uses `memfd_create`, which is present. This is not expected to block boot. It must be confirmed in the Waydroid boot test.

---

## 4. What cannot be concluded from this inspection

The following are **not** proven:

- that `modprobe binder_linux devices=...` succeeds on a real Debian 13 boot,
- that Waydroid starts LXC and boots Android on this kernel,
- that Android binder services (`servicemanager`, `vndservicemanager`, `hwservicemanager`) initialize correctly with legacy devices,
- that AppArmor/LXC/cgroup v2 policy permits the container,
- that GPU/audio/network passthrough works.

The WSL kernel has Binder completely disabled and cannot test any of this. A Debian 13 bare-metal or VM test is mandatory.

---

## 5. Runtime verification plan (Phase 1/3 gate)

On a real Debian 13 system with `linux-image-amd64` 6.12.107-1:

```bash
# 1. Confirm the running kernel and config
uname -r
grep -E 'CONFIG_ANDROID_BINDER|CONFIG_ASHMEM' /boot/config-$(uname -r)

# 2. Load the module with the three legacy devices
sudo modprobe -r binder_linux 2>/dev/null || true
sudo modprobe binder_linux devices="anbox-binder,anbox-vndbinder,anbox-hwbinder"

# 3. Verify devices
ls -l /dev/anbox-binder /dev/anbox-vndbinder /dev/anbox-hwbinder
cat /proc/filesystems | grep binder || echo "binderfs absent (expected)"

# 4. Confirm module parameters
cat /sys/module/binder_linux/parameters/devices
```

Expected:

- `/dev/anbox-binder`, `/dev/anbox-vndbinder`, `/dev/anbox-hwbinder` exist.
- `binderfs` is absent from `/proc/filesystems`.
- `/sys/module/binder_linux/parameters/devices` shows the three names.

Then run Waydroid initialization and capture:

```bash
sudo waydroid init -f
sudo systemctl start waydroid-container
waydroid session start
waydroid status
```

Success criteria:

- container starts,
- Android boot completes,
- `waydroid app list` returns packages,
- an APK installs and launches,
- network, audio, clipboard, and a second window work.

If any step fails because a separate vnd/hw binder context is required, the legacy path is insufficient and the project must revisit the kernel policy.

---

## 6. Secure Boot and updates

- The stock Debian kernel is signed and works with Shim/Secure Boot.
- `binder_linux` is an in-tree, signed Debian module. Using its module parameter does not break Secure Boot.
- A custom kernel or DKMS binder module would require signing and would break the "original Debian kernel" rule. It is not part of V1.
- Kernel updates must remain enabled. GRUB must retain the previous kernel for rollback. Do not hold `linux-image-amd64` at 6.12.107.

---

## 7. Conclusion

The stock Debian kernel is **not BinderFS-enabled**, but it appears to provide the legacy binder devices Waydroid needs. This is a documented deviation from the literal "BinderFS" requirement, not a silent kernel replacement. Phase 1 must test it on the real Debian kernel before Phase 3 is declared viable.
