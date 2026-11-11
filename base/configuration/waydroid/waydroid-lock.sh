#!/bin/sh
# Freeze the Android container while the desktop is locked and resume it after
# unlocking.  Used by swayidle through the ElvonOS power settings.
elvonos-waydroid freeze >/dev/null 2>&1
Win8Lock
elvonos-waydroid unfreeze >/dev/null 2>&1
