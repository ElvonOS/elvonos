# ElvonOS kernel

`build-kernel.sh` builds the kernel that ships in the live ISO from Debian's
`linux-source-6.12` package and installs it into the target rootfs.

## What is customised

The build starts from the Debian kernel configuration of the target rootfs
(`/boot/config-*`) and changes only:

| Option | Value | Why |
|---|---|---|
| `CONFIG_LOCALVERSION` | `-elvonos` | `uname -r` identifies the ElvonOS kernel |
| `CONFIG_DEBUG_INFO` | disabled | much faster build, smaller modules and initramfs |
| `CONFIG_DEBUG_INFO_BTF` | disabled | no `pahole`/BTF generation needed |
| `CONFIG_DEBUG_INFO_DWARF5` | disabled | part of the debug info removal |
| `CONFIG_GDB_SCRIPTS` | disabled | not needed on the live system |

Everything else stays at Debian's values on purpose: Android binder
(`CONFIG_ANDROID_BINDER_IPC=m`, used by Waydroid), `virtio-gpu`/virgl,
`zram`, `amdgpu`/`i915`, Wi-Fi, audio and the filesystems are unchanged, so
the desktop, the QEMU Virgl path and Waydroid keep working exactly as before.

## Usage

```sh
sudo apt-get install linux-source-6.12 build-essential bison flex bc \
    libssl-dev libelf-dev kmod cpio zstd
bash build/kernel/build-kernel.sh [ROOTFS] [CONFIG]
```

Defaults: rootfs `build/out/rootfs`, config taken from that rootfs.  The
script

1. extracts `/usr/src/linux-source-6.12.tar.xz` into `build/kernel/`,
2. applies the options above and runs `olddefconfig`,
3. builds `bzImage` and the modules (parallel, `JOBS=<n>` overrides the jobs),
4. installs `vmlinuz-<version>-elvonos`, `System.map`, `config` and
   `/lib/modules/<version>` into the rootfs,
5. generates the matching initramfs with the rootfs' `mkinitramfs`,
6. removes the previous kernel files and module tree from the rootfs.

`build/phase7/build-iso.sh` prefers a `vmlinuz-*elvonos*` image, so the ISO
picks up the custom kernel even if another kernel is present.

## initramfs

The initramfs is generated with Debian's `MODULES=most`, i.e. **all drivers
that may be needed on real hardware stay in the initramfs**.  With Debian's
initramfs-tools the already `.ko.xz`-compressed modules are stored in an
uncompressed cpio part (496 MB) followed by a zstd-compressed part (76 MB), so
the image is ~546 MB and the ISO grows to ~5.8 GB.  Trimming the initramfs
(GPU, media, sound, InfiniBand, wireless, …) was evaluated but deliberately
**not** enabled: those modules are not required to mount the live medium, but
keeping them preserves the "boots on any hardware" property and the modules
are anyways installed in `/lib/modules` for the running system.

If a smaller ISO is more important than universal boot support, an optional
trim hook can be added later; the kernel and the module tree itself always keep
every driver.

The build writes its log to `build/out/kernel-build.log` when started from the
project scripts and takes roughly 10–25 minutes on four cores depending on the
machine — in this environment (WSL, 4 vCPU) the first full build took about
1.5 hours.

