#!/usr/bin/env bash
# Remove the system settings installed by install-system.sh.
set -euo pipefail

RULES=/etc/udev/rules.d/70-jabra.rules
HWDB=/etc/udev/hwdb.d/70-jabra-micmute.hwdb

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

if [ -e "$RULES" ]; then
  echo "→ Removing: $RULES"
  $SUDO rm -f "$RULES"
fi

if [ -e "$HWDB" ]; then
  echo "→ Removing: $HWDB"
  $SUDO rm -f "$HWDB"
  $SUDO systemd-hwdb update
fi

$SUDO udevadm control --reload-rules
$SUDO udevadm trigger --subsystem-match=hidraw --subsystem-match=input

# If the microphone was left muted at system level, unmute it.
if command -v pactl >/dev/null 2>&1; then
  pactl set-source-mute @DEFAULT_SOURCE@ 0 2>/dev/null || true
fi

echo
echo "✔ System settings removed."
echo "  Unplug and replug the Jabra dongle to restore the original behavior."
