# 19 — UI and integration fixes in ElvonOS 1.0.9

This release fixes the issues found while testing 1.0.8. It is primarily a
desktop/UI and Waydroid integration update.

## Start and taskbar

- **Start no longer opens at login.** `Win8Start` created its layer surface
  with `showFullScreen()` on every start; it now stays hidden until the Start
  button, `Super`, or a tile requests it.
- **The taskbar no longer disappears.** The Start button called
  `WindowController.hide()` on the taskbar and nothing ever sent the reverse
  message. The taskbar stays mapped; the Start overlay covers it.
- **`Super` opens Start** (new labwc keybinding), and `Super+D` shows the
  desktop.
- The window counter is hidden when no window is open.
- Window icons and tray icons now resolve Papirus, Breeze (apps/devices/
  mimetypes/places), Adwaita, hicolor and ElvonOS Metro icons. Previously the
  taskbar and Start app list only searched hicolor/Breeze apps and showed
  letters or empty placeholders.
- Window chips keep their close button and count badge inside the chip.

## Start screen and Metro

- Fixed the **Apps screen Back button**: it contained a nested `onClicked`
  handler and did nothing.
- The Start app list shows real icons for ElvonOS applications again.
- New Metro artwork for Files, Terminal, Settings, Android, Store, Bulk Rename
  and the installer (`/usr/share/icons/elvonos/metro/`).
- The default tile layout is migrated in place: Files/Store/Settings/Bulk
  Rename get the new commands and icons without moving the user's tiles.
- The tile layout generator is versioned (`LAYOUT_VERSION`), so existing
  layouts are updated once.

## Store

- **The Android tab is no longer covered by the search field.** The toolbar
  used fixed pixel offsets (`tabs at 200`, `search at 332`) while the tabs end
  at 422. The search field is now anchored between the tabs and the window
  controls and shrinks with the window.
- Aurora Store: the button now falls back to the fullscreen Waydroid UI if no
  Aurora window appears (Waydroid 1.6.3 + Android 16 limitation).
- Flatpak/Android app rows keep their action buttons inside the row.

## Desktop

- **Normal files on the desktop are shown.** The desktop model only listed
  directories and `*.desktop` files; it now lists regular files with MIME
  icons and opens them with `xdg-open`.
- Files dropped or saved into `~/Desktop` appear immediately (the existing
  `QFileSystemWatcher` is reused).
- Rename/copy no longer appends `.desktop` to normal files; desktop entries
  keep their `.desktop` suffix.
- Group folders (`System`, `Utilities`, …) have a **search field**; the
  `System` folder focuses it automatically.
- The `System` desktop icon now starts `elvonos-menu`, a searchable Wofi
  system-app menu, instead of a missing `/usr/bin/elvonos-menu` target.
- Folder icons are derived from the folder name.
- The live desktop has an **Install ElvonOS** icon. The installer removes it
  from the target system.

## Media Player

- The seek bar is a real `Slider` with a 14 px handle, a 20 px hit area and a
  pressed-state highlight; dragging updates `player.position`. The volume
  slider uses the same component. The previous seek bar only handled clicks
  and a 10 px handle.

## Waydroid / Android

- **Installed user gets UID/GID 1000.** Waydroid maps the desktop UID into the
  container and rejects app launches from UID 1001 (`package=android does not
  belong to uid=1001`). The installer now gives the chosen account UID/GID
  1000 after removing the live `elvon` user.
- **Live Android user data is no longer copied to the target.** The live
  `~/.local/share/waydroid` (Android 13 data) made Android 16's JobScheduler
  fail on first boot. The installer excludes and removes it.
- **Passwordless sudo for the desktop account.** ElvonOS services call
  `sudo -n`; the installer previously created `ALL=(ALL) ALL`, so Waydroid,
  Settings, Control and Cleaner could not perform privileged actions. New
  installs get `NOPASSWD:ALL`, matching the live user. Existing installs get
  the `desktop-policy` update component.
- **`loop` module is loaded at boot.** The installed system lacked
  `/dev/loop-control`, so Waydroid's vendor image mount failed with
  "failed to setup loop device". Added `modules-load.d/elvonos-loop.conf` and
  `modprobe loop` in `elvonos-waydroid-init`.
- **Boot parameters** `security=selinux apparmor=0` are now written to GRUB,
  matching the live ISO.
- `ro.hw_timeout_multiplier=10` is appended to Waydroid props for slow disks.
- Waydroid notifications use one replaceable notification ID (`-r 1977`) and
  auto-hide after 5 s; the 1.0.8 daemon stacked up to six identical
  "starting/ready" bubbles.
- The 1.0.9 ISO still ships Android 16 (LineageOS 23.2 QPR2, SDK 36).

## Performance: Rust desktop search index

The desktop search used to walk Desktop/Documents/Downloads/Pictures/Music/
Videos synchronously on the UI thread for **every keystroke** (up to 4000
files). It now uses `elvonos-search-index`, a small Rust binary built from
`base/configuration/search-rs/`. The index is built once in the background
and C++ only filters the in-memory list. The UI and design are unchanged.

## Known limitations

- **Waydroid 1.6.3 + Android 16 multi-window:** the Android task can start
  (`am start`) without a Wayland window, and `waydroid app launch` cannot
  reach the platform binder service on this image. The Store Aurora button
  falls back to `waydroid show-full-ui`; other apps launched from Start use
  the native task path and may also need the fullscreen UI. A future release
  should update Waydroid to a version with native Android 16 support.
- Rootless Waydroid, Wayland screenshots in some VM GPUs and the Android
  first-boot time on USB HDDs remain environment-dependent.

## Verification

| Test | Result |
|---|---|
| Start hidden at login; `Super`/button opens it | passed |
| Taskbar remains after opening/closing Start | passed |
| Store toolbar: Linux + Android tabs + search | passed (Android tab visible) |
| Desktop file created in `~/Desktop` | shown with MIME icon and name |
| Media Player launch and new seek bar | passed |
| System desktop icon | opens searchable system menu |
| Installer icon on live desktop | shown; removed on install |
| Installed user UID/GID | 1000:1000 |
| Android 16 first boot after UID/data fixes | `sys.boot_completed=1` |
| Aurora Store package installed | `com.aurora.store`, `com.android.vending`, `com.google.android.gms` |
