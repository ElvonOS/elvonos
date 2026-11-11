# Waydroid images and the ElvonOS image manager

ElvonOS ships Waydroid with an **Android 16** image pair and a small manager
that can download, install, inspect and build custom images.

The runtime itself is unchanged upstream Waydroid 1.6.3. ElvonOS only supplies
the images, the default properties and the command-line manager.

## Shipped images

| Item | Value |
|---|---|
| Android | 16 (LineageOS 23.2 QPR2) |
| SDK | 36 |
| Security patch | 2026-07-01 |
| Vendor type | MAINLINE |
| Build release | `20260717` |
| System image | VANILLA, EROFS + LZ4, 1,417,170,944 B raw (1,103,813,388 B zip) |
| Vendor image | MAINLINE, ext4, 721,117,184 B raw (210,854,104 B zip) |
| Source | <https://github.com/WayDroid-ATV/waydroid-builds> |

SHA256 (release zips):

```text
152e0f5c01cf10cc4c7ec93723c286308a06cb1334e6eeb4a4039cb345f97ae4  lineage-23.2-20260717-VANILLA-waydroid_x86_64-system.zip
28dfbd0e423dff6d5c7d2e34e15011fbaf4865da769d9923b84656d87e9f4d3c  lineage-23.2-20260717-MAINLINE-waydroid_x86_64-vendor.zip
```

The live ISO keeps the raw images on the read-only medium and links them into
`/usr/share/waydroid-extra/images`. The installer copies the real files to
`/etc/waydroid-extra/images` on the target system, so an installed ElvonOS
works without the ISO.

On first boot `elvonos-waydroid-init` runs `waydroid init -f` when no
configuration exists. Android user data lives in `/var/lib/waydroid/data` and
is never removed by image updates.

## Manager

```sh
elvonos-waydroid-image status            # installed images, version, session
elvonos-waydroid-image list              # catalog (Android 16 and 17)
elvonos-waydroid-image download android16
elvonos-waydroid-image install android16
elvonos-waydroid-image install --from-medium
elvonos-waydroid-image install --system system.img --vendor vendor.img
elvonos-waydroid-image create --name "My image" \
    --system system.img --vendor vendor.img \
    --overlay ./overlay --apk ./MyApp.apk --output ./my-image.zip
elvonos-waydroid-image repack --overlay ./overlay
elvonos-waydroid-image verify ./my-image.zip
```

`install` and `create` need root. The manager backs up the previous image pair
to `/var/lib/elvonos/waydroid/backups/<timestamp>/` before replacing it and
keeps `/var/lib/waydroid/data` untouched. `--reset-data` is available but asks
for explicit confirmation and is never enabled by default.

### Catalog

The catalog is `/usr/share/elvonos/waydroid/images.json`:

| ID | Android | LineageOS | Vendor |
|---|---|---|---|
| `android16` | 16 | 23.2 QPR2 | MAINLINE |
| `android17` | 17 | 24.0 QPR0 | MAINLINE |

Entries contain the release URL, the SHA256 of the zip and the expected size.
Downloads are verified before extraction. Use `--zip-dir` to install from
already downloaded archives (for example on a machine without Internet).

### Custom images

`create` accepts a raw, sparse, EROFS or ext4 system image and an ext4 or
EROFS vendor image. Sparse images are converted with `simg2img`. EROFS system
images are extracted with `fsck.erofs --xattrs --preserve` and rebuilt with
`mkfs.erofs -zlz4hc -C65536 -b4096`; ext4 images are loop-mounted read-write.
SELinux labels are preserved when the work directory supports `security.*`
xattrs (ext4 does; use `--workdir` if `/var/tmp` is a tmpfs).

The overlay directory mirrors Android paths:

```text
overlay/
├── system/etc/my-config.txt       -> /system/etc/my-config.txt
├── system/app/MyApp/MyApp.apk     -> /system/app/MyApp/MyApp.apk
├── product/...                    -> /product/...
└── vendor/etc/my-vendor.conf      -> /vendor/etc/my-vendor.conf
```

`--apk FILE` installs an APK into `/system/app/<name>/`. Every created image
also gets `/system/etc/elvonos-image.prop` with the image name, Android
version and build timestamp.

The result is a single zip with `system.img`, `vendor.img`, `SHA256SUMS` and
`elvonos-image.json`, plus the SHA256 of the zip. It can be installed with
`elvonos-waydroid-image install --system ... --vendor ...` or by extracting it
into `/etc/waydroid-extra/images`.

## Verification performed

Test environment: QEMU/KVM (WHPX), 8 GB RAM, `virtio-gpu-gl-pci`, ElvonOS
1.0.7 live ISO, Waydroid 1.6.3.

| Test | Result |
|---|---|
| Stock Android 16 images boot | `ro.build.version.release=16`, SDK 36, SurfaceFlinger running |
| CLI repack (EROFS + overlay + APK) | boots; overlay file, `elvonos-image.prop` and APK present |
| Custom EROFS keeps SELinux labels | `security.selinux` preserved on extracted files |
| Installed system uses A16 images | installer copy + first-boot `waydroid init -f` |
| Update path without new ISO | `install android16` downloads and verifies the release zips |

## Updates and existing installations

Android images are ISO content (about 2 GB) and are not part of the signed
`elvonos-apps` update payload, which is restricted to `usr/`,
`etc/elvonos/` and `elvonos-*` systemd units. Existing ElvonOS installations
receive the manager through the normal update feed and can then run:

```sh
sudo elvonos-waydroid-image install android16
```

This downloads around 1.3 GB, verifies both SHA256 values, replaces the image
pair, keeps Android user data and re-runs `waydroid init -f`.

## Licensing

Waydroid is GPL-3.0-or-later. The Android 16 images are built by the
WayDroid-ATV project from LineageOS sources and distributed under the licenses
of their components; see `LICENSES.md` and the upstream release notes. The
ElvonOS manager script is part of ElvonOS and licensed GPL-3.0-or-later.
