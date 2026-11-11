# Waydroid integration screenshots

Captured from the ElvonOS live ISO in QEMU (Windows QEMU 11 with WHPX and a
Virgl GPU) and kept here so the integration can be inspected later.

| Image | What it shows |
|---|---|
| `aurora-store-window.png` | Aurora Store opened by the native Rust launcher as a real multi-window Wayland window (`com.aurora.store/.ComposeActivity`, `mCurrentFocus` verified). |
| `settings-apps-waydroid.png` | Einstellungen → Apps: Waydroid status, storage usage, start/restart/sync/Android-settings/APK, autostart, clipboard/notification bridge, Android app search and the app list with real APK icon, open, clear data and uninstall. |
| `explorer-android-apps.png` | Explorer in `--android-apps` mode: Android apps with icons, sidebar with Android apps and Android storage (mounted automatically). |
| `start-menu-android.png` | Win8Start with the new **Android** tile (metro icon, opens the Android app list) and the live clock/system/calendar tiles. |
| `system-health.png` | Einstellungen → System with the **Zustand** card: memory, disk, load, failed services, Waydroid, clipboard bridge and warnings from the health layer. |
| `terminal.png` | The ElvonOS terminal with ANSI colours and the Android shell profile. |
| `metro-window.png` | Metro app windows: the app fills the surface (Einstellungen → Design → App-Fenster → Metro). |
| `desktop-window.png` | The same app in desktop mode as a normal movable window. |
| `sound-settings.png` | Einstellungen → Design: system sounds per event with test/choose/reset. |
| `android-settings-native-window.png` | Android Settings started by the native launcher (`am start` + task check) as a multi-window window. |
| `settings-waydroid-card.png` | Older capture of the Waydroid card before the icon and app-list work. |

Measured on the final ISO (`d2ea760f…`) in Windows QEMU with WHPX:

| Step | Time |
|---|---|
| Android `sys.boot_completed=1` | ~40–60 s (61 s on the final ISO) |
| `elvonos-waydroid install AuroraStore-4.8.4.apk` | ~4 s |
| `elvonos-waydroid sync` + icon extraction | ~1 s |
| `elvonos-waydroid com.aurora.store` until the window has focus | ~3 s |

Reproduce:

```powershell
# Windows QEMU with WHPX acceleration and Virgl (fast path)
powershell -ExecutionPolicy Bypass -File build\phase1\run-desktop-qemu-whpx.ps1
```

```sh
# From WSL, SSH through the Windows host gateway
GW=$(ip route show default | awk '{print $3}')
ssh -p 2222 elvon@$GW
elvonos-waydroid session &
elvonos-waydroid install /usr/share/elvonos/waydroid/apps/AuroraStore-4.8.4.apk
elvonos-waydroid sync
elvonos-waydroid com.aurora.store
```

The slower alternative inside WSL/TCG is
`build/phase1/run-desktop-qemu-waydroid.sh`; it needs access to
`/dev/dri/renderD128` (render group or ACL). Without Virgl SurfaceFlinger aborts
with `output buffer not gpu writeable` and no app window can appear.
