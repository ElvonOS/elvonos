# ElvonOS Live Installer

`elvonos-installer` installs the running live system to a disk. It is shipped
as `/usr/bin/elvonos-installer` and linked as **Install ElvonOS** in the Start
screen.

## What it does

1. Lets you pick the target disk (all data on it is erased).
2. Collects the installation settings:
   - **Language** — 15 languages; sets the system locale (default English).
   - **Keyboard layout** — 16 layouts; applied to X11, Wayland and the console.
   - **Time zone** — sets `/etc/localtime`, `/etc/timezone`.
   - **User account** — user name, full name, password (entered twice).
   - **Hostname** — computer name (default `elvonos`).
   - **Optional software** — multimedia codecs, development tools, gaming
     (Wine/GameMode/MangoHud), office, virtualization. Installed on first boot
     when the machine is online.
3. Shows a summary and asks you to type `ERASE`.
4. Stops `udisks2`/`gvfs` so they do not auto-mount the new partitions.
5. Creates a GPT layout:
   - 1 MiB BIOS boot (`ef02`)
   - 512 MiB EFI System (`ef00`, FAT32)
   - remaining space: ext4 `/` (label `ElvonOS`)
6. Copies the live system with `rsync -aHAXx` (without `/proc`, `/sys`,
   `/dev`, `/run`, `/tmp`, `/mnt`, `/media`, `/target`, `/var/lib/lxcfs`).
7. Copies kernel, initrd and kernel config from the live medium
   (`/run/live/medium/live`); the squashfs deliberately excludes `/boot`.
8. Configures the installed system:
   - `/etc/fstab` with UUIDs, hostname, `/etc/hosts`
   - locale (generated with `locale-gen`), keyboard, console keymap, time zone
   - the chosen user with groups `sudo,audio,video,render,plugdev,input,netdev,cdrom`
   - password-required `sudo`, autologin on tty1
   - fresh `machine-id` and SSH host keys
   - `/etc/elvonos/first-boot.json` for optional software
9. Installs the bootloader:
   - UEFI: `grub-install --target=x86_64-efi` with embedded `ext2` module
   - BIOS: `grub-install --target=i386-pc`
   - `update-initramfs -u -k all`, `grub-mkconfig`
   - fallback `EFI/BOOT/BOOTX64.EFI` as `grub-mkstandalone` image with an
     embedded search configuration (required by OVMF/QEMU without persistent
     NVRAM entries)
10. Unmounts everything and offers a restart.

## Interactive use

```sh
elvonos-installer
```

## Unattended use

```sh
sudo env \
  ELVONOS_INSTALLER_TARGET=/dev/vda \
  ELVONOS_INSTALLER_YES=1 \
  ELVONOS_INSTALLER_USER=alice \
  ELVONOS_INSTALLER_PASSWORD=secret \
  ELVONOS_INSTALLER_FULLNAME="Alice Example" \
  ELVONOS_INSTALLER_LANG=en \
  ELVONOS_INSTALLER_KEYMAP=us \
  ELVONOS_INSTALLER_TIMEZONE=Europe/Berlin \
  ELVONOS_INSTALLER_HOSTNAME=alice-pc \
  ELVONOS_INSTALLER_EXTRAS=multimedia,dev \
  elvonos-installer
```

| Variable | Meaning | Default |
|---|---|---|
| `ELVONOS_INSTALLER_TARGET` | Target disk, e.g. `/dev/vda`, `/dev/nvme0n1` | ask |
| `ELVONOS_INSTALLER_YES` | `1` = no dialogs, no confirmation | `0` |
| `ELVONOS_INSTALLER_USER` | User name | `elvon` |
| `ELVONOS_INSTALLER_PASSWORD` | Password for that user | `elvon` |
| `ELVONOS_INSTALLER_FULLNAME` | GECOS/full name | `ElvonOS User` |
| `ELVONOS_INSTALLER_LANG` | Language code (`en`, `de`, `es`, …) | `en` |
| `ELVONOS_INSTALLER_KEYMAP` | Keyboard layout (`us`, `de`, `fr`, …) | from language |
| `ELVONOS_INSTALLER_TIMEZONE` | IANA time zone | `UTC` |
| `ELVONOS_INSTALLER_HOSTNAME` | Hostname | `elvonos` |
| `ELVONOS_INSTALLER_EXTRAS` | Comma list: `multimedia,dev,gaming,office,virt` | none |
| `ELVONOS_INSTALLER_NO_PKEXEC` | `1` = do not re-exec through `pkexec` | `0` |

## Optional software (first boot)

Selections are written to `/etc/elvonos/first-boot.json` and handled by
`elvonos-firstboot.service`:

| Set | Packages |
|---|---|
| `multimedia` | `ffmpeg`, GStreamer libav/bad/ugly |
| `dev` | `build-essential`, `git`, `cmake`, `ninja-build`, `gdb` |
| `gaming` | `wine`, `wine64`, `winetricks`, `gamemode`, `mangohud` |
| `office` | `libreoffice` |
| `virt` | `qemu-system-x86`, `virt-manager` |

The service waits up to five minutes for DNS, runs `apt-get update` and
installs the sets. The log is `/var/log/elvonos-firstboot.log`; the service
disables itself afterwards.

## Requirements inside the live system

`sgdisk`, `partprobe`, `mkfs.vfat`, `mkfs.ext4`, `rsync`, `grub-install`,
`grub-mkstandalone`, `update-initramfs`, `grub-mkconfig`, `ssh-keygen`,
`locale-gen`, `jq`, `zenity` (GUI only), `grub-efi-amd64-bin` and
`grub-pc-bin`. These packages are listed in `base/packages/installer.list`.

## Current limitations

- No LUKS encryption.
- No dual-boot menu (the target disk is used completely).
- No separate `/home` partition.
- The `grub-mkstandalone` fallback image is unsigned; on Secure Boot systems
  either disable Secure Boot or enroll a MOK.
- Language and keyboard are applied to the installed system, not to the
  running live session.

## Tested state (2026-11-10)

- Installation from the live ISO to a 20 GB QEMU disk (`/dev/vda`), both
  interactive (disk selection) and unattended.
- Custom account, password, full name, locale, keyboard and time zone applied;
  autologin works and the desktop configuration of the live account is migrated
  (absolute `/home/elvon` paths are rewritten).
- GRUB UEFI + BIOS installed; EFI fallback boots in OVMF.
- Installed system boots: kernel `6.12.116-elvonos`, `/dev/vda3` ext4,
  `/dev/vda2` vfat, `systemctl is-system-running` = `running`, zero failed
  units, SSH/Healthd/Waydroid active, Win8DE shell starts automatically.
- Update client returns a signed feed response.
- License texts are installed under `/usr/share/doc/elvonos/`.

## Screenshots

English screenshots of the Start screen, installer and update settings:

- SourceForge: <https://sourceforge.net/projects/elvonos/files/screenshots/>
- Local gallery: [`screenshots/installer/index.html`](screenshots/installer/index.html)

## Testing in QEMU (Windows/WHPX)

```powershell
# fresh 20 GB disk in D:\opencode, boot ISO + disk
powershell -ExecutionPolicy Bypass -File $env:TEMP\opencode\run-elvonos-install.ps1
```

Inside the live session:

```sh
sudo env ELVONOS_INSTALLER_TARGET=/dev/vda ELVONOS_INSTALLER_YES=1 \
     ELVONOS_INSTALLER_USER=alice ELVONOS_INSTALLER_PASSWORD=secret \
     ELVONOS_INSTALLER_LANG=de ELVONOS_INSTALLER_KEYMAP=de \
     elvonos-installer
```

Then boot the disk:

```powershell
powershell -ExecutionPolicy Bypass -File $env:TEMP\opencode\run-elvonos-installed.ps1 `
  -Disk 'D:\opencode\elvonos-install2.qcow2'
```
