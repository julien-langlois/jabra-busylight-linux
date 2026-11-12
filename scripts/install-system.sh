#!/usr/bin/env bash
# Install the system settings (shared by the Chrome and Firefox methods):
#   - /etc/udev/rules.d/70-jabra.rules          dongle access for the session user
#   - /etc/udev/hwdb.d/70-jabra-micmute.hwdb    disables the Jabra KEY_MICMUTE key
# Usage: ./scripts/install-system.sh [--no-micmute-fix]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_DST=/etc/udev/rules.d/70-jabra.rules
HWDB_DST=/etc/udev/hwdb.d/70-jabra-micmute.hwdb
WITH_HWDB=1

for arg in "$@"; do
  case "$arg" in
    --no-micmute-fix) WITH_HWDB=0 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

echo "→ udev rule: $RULES_DST"
$SUDO install -D -m 0644 "$REPO_DIR/system/70-jabra.rules" "$RULES_DST"

if [ "$WITH_HWDB" -eq 1 ]; then
  echo "→ hwdb rule: $HWDB_DST"
  $SUDO install -D -m 0644 "$REPO_DIR/system/70-jabra-micmute.hwdb" "$HWDB_DST"
  $SUDO systemd-hwdb update
fi

$SUDO udevadm control --reload-rules
$SUDO udevadm trigger --subsystem-match=hidraw --subsystem-match=input

echo
echo "✔ System settings installed."
echo "  1. Unplug and replug the Jabra dongle."
echo "  2. Check with: ./scripts/check.sh"
