# Free updates (English guide)

ElvonOS uses a **static, signed update feed**. No paid service is involved:
the feed is a JSON file in a public Git repository and the artifacts are served
by SourceForge, GitHub or Codeberg.

The updater covers **all components of the system**:

| Layer | Mechanism |
|---|---|
| Debian base OS (packages, libraries, drivers, security fixes) | `apt-get update && apt-get upgrade` |
| ElvonOS software (Settings, Store, Terminal, installer, scripts, desktop integration) | signed **payload** (`.tar.zst`) extracted over `/` after sha256 + minisign verification |
| Setup actions (e.g. **Flathub for the Store**) | signed **script** component |
| Flatpak applications | Flatpak metadata refresh after component updates |
| ISO (kernel, bootloader, live image) | `elvonos-update download` + verified ISO |

## Components

| Piece | Location |
|---|---|
| Client | `/usr/bin/elvonos-update` |
| Config | `/etc/elvonos/update.conf` |
| Public key | `/usr/share/elvonos/update/elvonos.pub` |
| Feed (primary) | `https://downloads.sourceforge.net/project/elvonos/feeds/stable.json` |
| Mirror 1 | `https://raw.githubusercontent.com/ElvonOS/elvonos-updates/main/feeds/stable.json` |
| Mirror 2 | `https://codeberg.org/ElvonOS/elvonos-updates/raw/branch/main/feeds/stable.json` |
| Cache | `~/.cache/elvonos/update` |
| Component versions | `/var/lib/elvonos/components/<id>.version` |
| Release version | `/etc/elvonos-release` |

## Client usage

```sh
elvonos-update status     # current version and feed URL
elvonos-update check      # JSON status
elvonos-update download   # download ISO, verify sha256 + minisign
elvonos-update apply      # apt upgrade + signed components (root)
```

`check` output:

```json
{
  "current": "1.0.2",
  "latest": "1.0.2",
  "update": true,
  "iso": false,
  "os_updates": 4,
  "components": [
    { "id": "elvonos-apps", "version": "1.0.2-2", "installed": "1.0.2" }
  ]
}
```

`update` is `true` when a newer ISO exists, Debian packages are upgradable, or
a component version is missing/outdated. `apply` needs root (`sudo` or
`pkexec`); the Settings app launches it through `pkexec`.

## Automatic updates (ChromeOS-style)

When enabled (default), ElvonOS **prepares updates in the background and
installs them on shutdown/reboot** — the user can keep working and the next
start is already updated:

1. `elvonos-update-check.timer` runs daily (randomised delay) and calls
   `elvonos-update auto`, which downloads Debian packages and signed ElvonOS
   components into the system cache and writes a signed feed snapshot.
2. On shutdown/reboot, `elvonos-update-shutdown.service` applies the staged
   set before power-off (`apply --staged`, offline-capable).
3. If shutdown was interrupted, `elvonos-update-boot.service` applies the
   remaining staged set before the graphical target starts.
4. Manual updates remain available at any time via Settings or
   `sudo elvonos-update apply`.

Control:

```sh
elvonos-update-policy on|off|status
```

Settings → Updates shows the switch **“Install updates on shutdown”**. The
policy is stored as `AUTO_APPLY=shutdown|off` in `/etc/elvonos/update.conf`
and as the flag `/etc/elvonos/auto-apply.enabled`.

Staged updates never touch `/home`; see the safety section below.

## Safety: user data is never touched

Updates are designed so that **personal files cannot be deleted or modified**:

- The signed software payload is restricted to an allowlist:
  `usr/`, `etc/elvonos/` and `etc/systemd/system/elvonos-*` (including the
  `*.target.wants/elvonos-*` links). Anything else — especially `home/`,
  `root/`, `var/`, `boot/`, `/etc/passwd`, `/etc/shadow`, `/etc/ssh` — is
  rejected before extraction.
- Absolute paths, `..` components and symlink targets that escape the tree are
  rejected.
- APT runs `upgrade` with `Dpkg::Options::=--force-confold`, so existing
  configuration files are kept. No `autoremove`, no `purge`.
- The daily/timer staging step only downloads files into the system cache.
- Component scripts are signed and reviewed; they only configure system
  components (e.g. the Flathub remote).
- Before applying updates, `/etc` is backed up to
  `/var/backups/elvonos/etc-<timestamp>.tar.gz` (last 3 kept). Home
  directories are not part of any backup or payload.

Validate a payload before use:

```sh
elvonos-update verify-payload ElvonOS-...tar.zst
```

Tested with canary files: a payload containing `home/<user>/...` is rejected,
and normal updates leave `/home` byte-for-byte unchanged.

## Logging and Settings

```sh
elvonos-update log        # last 100 lines (root and user log)
```

- User actions: `~/.local/state/elvonos-update.log`
- Root actions (`apply`): `/var/log/elvonos-update.log` (0644)
- Logs rotate automatically at 512 KB (last 2000 lines kept).

The Settings → **Updates** card runs a check when opened and shows:

- installed/available version, last check time,
- OS package updates and pending component names,
- a **live log** of check/download/apply,
- “A new ISO is available” when the feed advertises a newer image.

Buttons are disabled while an action runs; apply automatically re-checks when
it finishes.

## Feed format

```json
{
  "channel": "stable",
  "version": "1.0.2",
  "released": "2026-11-10T20:11:22Z",
  "min_supported": "1.0.0",
  "iso": {
    "url": "https://downloads.sourceforge.net/project/elvonos/releases/1.0.2/ElvonOS-1.0.2-amd64.iso",
    "size": 6222618624,
    "sha256": "…",
    "signature": "…iso.minisig"
  },
  "components": {
    "elvonos-apps": {
      "version": "1.0.2-2",
      "type": "payload",
      "url": "https://downloads.sourceforge.net/project/elvonos/components/elvonos-apps-1.0.2-2.tar.zst",
      "sha256": "…",
      "signature": "…tar.zst.minisig"
    },
    "flatpak-store": {
      "version": "1",
      "type": "script",
      "url": "https://downloads.sourceforge.net/project/elvonos/components/flatpak-store-1.sh",
      "sha256": "…",
      "signature": "…sh.minisig"
    },
    "waydroid-image": {
      "version": "1",
      "type": "script",
      "url": "https://downloads.sourceforge.net/project/elvonos/components/waydroid-image-1.sh",
      "sha256": "…",
      "signature": "…sh.minisig"
    }
  }
}
```

`stable.json` and `stable.json.minisig` are published together; every component
is signed individually. The client verifies the feed first and then every
payload/script (minisign + sha256) before executing or extracting it.

Payloads are extracted as root only after a path-safety check (no absolute
paths, no `..`). They contain the ElvonOS software tree (`usr/bin/elvonos-*`,
`usr/lib/elvonos`, `usr/share/elvonos`, desktop entries, services, docs) and
never touch user homes. Android APKs are excluded (they are managed by
Waydroid), so a typical software payload is ~2.5 MB.

## First update: Flathub for the Store

The Store ships with Flathub support and a **“Set up Flathub”** action. The
signed component `flatpak-store` performs the official setup
(<https://flatpak.org/setup/>):

1. install `flatpak` if it is missing,
2. add the system-wide Flathub remote
   (`flatpak remote-add --system --if-not-exists flathub …`),
3. refresh AppStream data.

The Store shows a banner while Flathub is not configured and can run the same
script via `pkexec elvonos-flatpak-setup`.

## Waydroid image tooling

The signed component `waydroid-image` installs the packages that
`elvonos-waydroid-image` needs on existing installations (`erofs-utils`,
`android-sdk-libsparse-utils`, `attr`, `zip`, `unzip`, `jq`, `rsync`,
`e2fsprogs`). It is idempotent. The Android images themselves are ISO content
and are not part of the payload (2 GB); after the component is applied, users
can run:

```sh
sudo elvonos-waydroid-image install android16
```

This downloads the verified Android 16 release, keeps Android user data and
re-runs `waydroid init -f`. See
[18-waydroid-images.md](18-waydroid-images.md).

## Publishing a release

```sh
# 1. build the ISO
ELVONOS_VERSION=1.0.1 REBUILD_SQUASHFS=1 bash build/phase7/build-iso.sh

# 2. sign, upload ISO + payload + components, update the feed
bash build/update/publish-update.sh 1.0.1

# 3. mirror the feed (publish-update does this when CB_USER is set)
CB_USER=ElvonOS bash build/update/mirror-codeberg.sh /tmp/elvonos-updates
```

`publish-update.sh` builds the `elvonos-apps` payload from the fresh rootfs,
signs everything, uploads to SourceForge and writes the feed.

## Signing keys

- Public key: `RWS/qURuN49P6KiggSTz8FJLVushtqbyI/32lPvZgJzPklLsEu7oEgPk`
- Location: `~/.config/elvonos/keys/{elvonos.pub,elvonos.key}`
- The current key has no passphrase so builds can sign unattended. Rotate it
  for a production setup and ship the new public key in an update.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `missing: curl` | `sudo apt-get install curl` |
| `Feed-Signatur ungültig` | check the clock; re-download the feed |
| `another update is already running` | wait for the running update |
| `root privileges required` | run `sudo elvonos-update apply` or use Settings (pkexec) |
| `update:false` but a new ISO exists | the feed `version` was not bumped |
