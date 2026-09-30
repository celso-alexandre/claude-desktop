#!/bin/sh
# Electron under zypak, which gives Chromium its sandbox inside Flatpak.
# X11 (XWayland on Wayland sessions) keeps the Quick Entry global hotkey working.
export TMPDIR="$XDG_RUNTIME_DIR/app/$FLATPAK_ID"
exec zypak-wrapper /app/lib/claude-desktop/claude-desktop --ozone-platform=x11 "$@"
