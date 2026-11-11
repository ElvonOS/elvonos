# Release plan — next update

Status: **1.0.3 released + software update 1.0.4-2** (U1–U5 done) ·
Remaining items U6–U11 planned for **1.0.4 / 1.1.0**

## 1. Where we are

- 1.0.2 ISO is published on SourceForge (signed, `SHA256SUMS` + minisign).
- The updater already handles:
  - Debian OS packages (`apt-get upgrade`, retries),
  - ElvonOS software as signed `.tar.zst` payloads,
  - signed script components (`flatpak-store`),
  - Flatpak metadata refresh,
  - ISO downloads with sha256 + minisign.
- Feed is served primarily by SourceForge with GitHub/Codeberg fallbacks.
- Known gap: the **1.0.2 ISO ships the pre-hardening client**. The fixes
  (SourceForge feed, retries, `version_gt`, APT resilience) arrive through the
  `elvonos-apps 1.0.2-2` component after the first update.
- `linux-image-amd64` / `linux-headers-amd64` (6.12.107-1 meta packages) stay
  "kept back" because only `6.12.116-elvonos` is installed (no Debian
  `linux-image-6.12.107` package).

## 2. Goal of 1.0.3 — "update hardening"

Deliver a release where a **fresh installation needs no follow-up fixes**, and
make updates observable and recoverable.

### Must have

| ID | Task | Acceptance |
|---|---|---|
| U1 | Ship the final updater in the ISO (SF feed, retries, `version_gt`, APT resilience, lock) | fresh 1.0.3 `check` works without payload fix |
| U2 | Rebuild ISO with version 1.0.3 and component marker `1.0.3`; publish payload `1.0.3` + feed | `check` after install shows only `flatpak-store` once, then `update:false` |
| U3 | Remove or hold the Debian kernel meta packages; document the custom-kernel policy | `apt upgrade` no longer shows held kernel packages |
| U4 | Update UI: component names, OS package count, progress/log, "restart required" for ISO | Settings card reflects `check`/`apply` state and errors |
| U5 | Update log + diagnostic command (`elvonos-update log`, `/var/log/elvonos-update.log`) | failures are reviewable without a terminal |
| U6 | Test matrix: QEMU BIOS + UEFI install → update → reboot; offline check; interrupted download resume | all pass, documented in `documentation/test-results/` |

### Should have

| ID | Task | Acceptance |
|---|---|---|
| U7 | Delta ISO updates: use the existing `zstd --patch-from` patch, feed field `delta`, client applies + verifies | update from 1.0.2 → 1.0.3 downloads < 10 % of the ISO |
| U8 | Update channels: `stable` and `beta` (`elvonos-update channel beta`) | beta feed readable, stable unaffected |
| U9 | Store: "Update all" for Flatpak apps + update count | one action updates installed Flatpak apps |
| U10 | Waydroid image update component | Android image version reported and updateable |
| U11 | Source/SBOM bundle per release (`ElvonOS-<version>-src.tar.zst`, `sbom.json`) | published next to the ISO |

### Could have (1.1.0)

- LUKS full-disk encryption option in the installer.
- Secure Boot: sign shim/GRUB and document MOK enrollment.
- ElvonOS APT repository for our software (replaces payloads for those who
  prefer packages).
- Kernel as `elvonos-kernel` Debian package with components/ISO update path.
- Complete English translation of the remaining German design documents.

## 3. Technical plan

### 3.1 Versioning and feed

```
ISO 1.0.3
components:
  elvonos-apps  1.0.3      (payload, ~2.5 MB)
  flatpak-store 1          (script)
  waydroid      <date>     (script, optional U10)
```

- ISO writes `/var/lib/elvonos/components/elvonos-apps.version = 1.0.3`.
- `min_supported` stays `1.0.0` until a breaking schema change.
- Feed stays backward compatible: unknown component types are skipped with a
  warning instead of aborting (add in U1).

### 3.2 Kernel meta packages (U3)

Options (choose in implementation):

1. Remove `linux-image-amd64` / `linux-headers-amd64` from the rootfs and keep
   only `6.12.116-elvonos` (simplest, recommended).
2. Keep them but `apt-mark hold` and document.
3. Build `elvonos-kernel` as a real package and depend on it.

Acceptance: `apt-get -s upgrade` reports 0 upgradable/held packages on a fresh
1.0.3 install.

### 3.3 Settings update UX (U4/U5)

- Show `os_updates`, component names and the last check time.
- Stream `apply` output into the card (QProcess instead of `startDetached`).
- After `apply`, automatically re-run `check` and show "Restart to finish" when
  the ISO was applied.
- Add `elvonos-update log` and write `/var/log/elvonos-update.log` (root) plus
  the user cache log.

### 3.4 Delta updates (U7)

- `release.sh` already produces `zstd --patch-from` patches; publish them as
  `components`-independent `delta` entry:
  ```json
  "delta": { "from": "1.0.2", "url": "...", "sha256": "...", "signature": "..." }
  ```
- Client: if `delta.from == current`, download patch, verify, apply to the old
  ISO in cache, verify the resulting sha256 against `iso.sha256`; fall back to
  the full ISO on any mismatch.

### 3.5 Channels (U8)

- `update.conf`: `CHANNEL=stable`; URL derived or explicit `feeds/beta.json`.
- Settings: channel selector (stable/beta), stored per user.
- Beta feed is published from a branch, never auto-selected.

## 4. Test plan

| Test | How | Pass criteria |
|---|---|---|
| Fresh UEFI install | QEMU/OVMF, 20 GB disk | boots, `systemctl running`, 0 failed |
| Fresh BIOS install | QEMU SeaBIOS | GRUB menu, boots |
| First update | `check` → `apply` | OS + payload + Flathub, `update:false` |
| Offline check | disconnect network | clear error, no partial state |
| Interrupted download | kill during ISO/payload | resume works, signature still verified |
| Bad signature | tamper feed/payload | client refuses, no files changed |
| Delta update | 1.0.2 → 1.0.3 | patch applied, final hash matches |
| Channel switch | stable ↔ beta | correct feed, rollback to stable |
| Upgrade from 1.0.2 | install 1.0.2, update to 1.0.3 | components migrated, no duplicates |

Document results in `documentation/test-results/2026-…-1.0.3.md` (English).

## 5. Release steps

1. Freeze `main`, update `documentation/00-project-status.md`.
2. Build rootfs + kernel + ISO:
   ```sh
   ELVONOS_VERSION=1.0.3 REBUILD_SQUASHFS=1 bash build/phase7/build-iso.sh
   ```
3. Run the test matrix above.
4. Publish:
   ```sh
   CB_USER=ElvonOS bash build/update/publish-update.sh 1.0.3
   ```
5. Verify feed signature and SourceForge content-length.
6. Update README/download links, screenshots, release notes.
7. Announce on SourceForge/GitHub/Codeberg (English).

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| GitHub raw cache delays | SourceForge is primary; fallbacks |
| Slow SourceForge mirrors | payload stays small; delta updates |
| APT mirror resets | `Acquire::Retries`, components independent of APT |
| Kernel meta packages reappear | U3 policy + test assertion |
| Signature key loss | offline backup; rotation documented in `11-…` |
| Secure Boot blocks fallback | documented; MOK plan in 1.1.0 |

## 7. Out of scope for 1.0.3

- LUKS, Secure Boot signing, APT repo for ElvonOS, kernel packaging (1.1.0).
- Real-hardware certification (tracked separately).
- AI features (none planned; see README disclaimer).

## 8. Rough schedule

| Milestone | Work |
|---|---|
| Day 1–2 | U1, U2, U3, U5 |
| Day 3–4 | U4, U6 (test matrix), U7 |
| Day 5 | U8, U9/U10 if time |
| Day 6 | release, docs, screenshots |

## 9. Definition of done

- Fresh 1.0.3 installation: `check` shows only the Flathub component; after
  `apply` it reports `"update": false`, `"os_updates": 0`, `"components": []`.
- No held/kept-back Debian kernel packages.
- Settings shows progress and errors; log available.
- ISO, payloads and feed are signed, mirrored and verified.
- README, status and test report updated in English.

## 10. Implementation log

| Date | Item | Result |
|---|---|---|
| 2026-11-10 | U3 — kernel meta packages | `linux-image-amd64` / `linux-headers-amd64` (6.12.107-1) purged from the rootfs; only `6.12.116-elvonos` remains; `apt-get -s upgrade` reports no kept-back packages |
| 2026-11-10 | U1 — final updater | `version_gt` (no downgrades), APT resilience, SF-primary feed with fallbacks, retries, unknown component types skipped |
| 2026-11-10 | U2 — ISO 1.0.3 | `228bd11a…` built, installed in QEMU (no kernel metas), published with payload `1.0.3`; fresh install → `check` (OS + Flathub) → `apply` → `update:false`, `os_updates:0`, `components:[]` |
| 2026-11-11 | U4 — Settings update UI | last check, OS/component counts, live log, ISO hint, buttons disabled while busy; auto-check on opening Updates; screenshot `settings-updates-log.png` |
| 2026-11-11 | U5 — update log | `elvonos-update log`, user log in `~/.local/state`, root log in `/var/log`, 512 KB rotation |
| 2026-11-11 | Automatic updates (requested) | daily staging timer, shutdown apply (`apply --staged`), boot fallback, policy toggle `elvonos-update-policy`, Settings switch |
| 2026-11-11 | Waydroid Android 16 (requested) | Android 16 / LineageOS 23.2 QPR2 stock images boot-tested (SDK 36, SurfaceFlinger); ISO now bundles A16; installer copies to `/etc/waydroid-extra/images`; `elvonos-waydroid-image` (status/list/download/install/create/repack/verify); custom EROFS repack boot-tested; `waydroid-image` update component installs tooling on existing systems |
| 2026-11-11 | UI/integration fixes (1.0.9) | Start hidden at login, taskbar persists, Super shortcut; responsive Store toolbar (Android tab/search); desktop files + MIME icons, rename/copy/group search; System search menu; live installer icon; Media Sliders; Papirus/Breeze icon resolution; UID 1000 + sudoers + live-data exclusion + loop module + LSM boot args for Waydroid; Rust `elvonos-search-index` |
| 2026-11-11 | User-data safety (requested) | payload allowlist (`usr/`, `etc/elvonos/`, `etc/systemd/system/elvonos-*`), rejection of absolute/`..`/escaping symlinks, `/etc` backup, canary test |
| open | U6/U7/U8–U11 | test matrix, delta updates, channels, Store update-all, Waydroid images, SBOM |
