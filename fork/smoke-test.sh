#!/usr/bin/env bash
# Prove the app really starts: launch it on a headless X server with a fresh profile and
# require, in order,
#   1. a window of class com.anthropic.Claude appears,
#   2. it is still running, window still up, $SMOKE_SETTLE seconds later,
#   3. the screen is not blank (the UI rendered).
# A screenshot is left at $SMOKE_SCREENSHOT either way.
# Usage: fork/smoke-test.sh <command...>
set -uo pipefail

CLASS=${SMOKE_CLASS:-com.anthropic.Claude}
WAIT=${SMOKE_WAIT:-120}
SETTLE=${SMOKE_SETTLE:-15}
SHOT=$(realpath -m "${SMOKE_SCREENSHOT:-smoke-test.png}")
MIN_COLORS=${SMOKE_MIN_COLORS:-16}
LOG=$(mktemp)

# Fresh profile, like a first launch; keep --user flatpak installs reachable
export FLATPAK_USER_DIR=${FLATPAK_USER_DIR:-$HOME/.local/share/flatpak}
export HOME=$(mktemp -d)
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.cache"

export DISPLAY=:$((100 + RANDOM % 100))
Xvfb "$DISPLAY" -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 &
XVFB=$!
setsid "$@" >"$LOG" 2>&1 &
APP=$!

finish() {
  import -window root "$SHOT" 2>/dev/null && echo "screenshot: $SHOT"
  kill -9 -- -"$APP" 2>/dev/null
  kill "$XVFB" 2>/dev/null
  echo "--- last lines of the app's output"
  tail -25 "$LOG"
  echo "--- $1"
  [[ $1 == PASS* ]]
  exit
}
alive() { kill -0 "$APP" 2>/dev/null; }
has_window() { xdotool search --onlyvisible --class "$CLASS" >/dev/null 2>&1; }

for ((t = 0; t < WAIT; t++)); do
  alive || finish "FAIL: app exited after ${t}s before showing a $CLASS window"
  has_window && break
  sleep 1
done
has_window || finish "FAIL: no $CLASS window after ${WAIT}s"
echo "$CLASS window up after ${t}s"

sleep "$SETTLE"
alive || finish "FAIL: app died within ${SETTLE}s of showing its window"
has_window || finish "FAIL: window vanished within ${SETTLE}s"

import -window root "$SHOT" || finish "FAIL: could not take screenshot"
COLORS=$(identify -format %k "$SHOT")
[ "$COLORS" -ge "$MIN_COLORS" ] || finish "FAIL: screen nearly blank ($COLORS colors) — UI did not render"

finish "PASS: window up after ${t}s, alive ${SETTLE}s later, $COLORS colors on screen"
