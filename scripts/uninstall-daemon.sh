#!/usr/bin/env bash
# Uninstall the jabra-busylight daemon for the current user.
# Usage: ./scripts/uninstall-daemon.sh [--purge]   (--purge also removes the config)
set -euo pipefail

BIN="$HOME/.local/bin/jabra-busylight"
UNIT="$HOME/.config/systemd/user/jabra-busylight.service"
CONF_DIR="$HOME/.config/jabra-busylight"
PURGE=0

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

[ "$(id -u)" -ne 0 ] || { echo "Run as a regular user, without sudo." >&2; exit 1; }

# Stopping the service turns the busylight off and unmutes the microphone if
# the daemon had muted it.
echo "→ Stopping and disabling the service"
systemctl --user disable --now jabra-busylight.service 2>/dev/null || true

for f in "$UNIT" "$BIN"; do
  if [ -e "$f" ]; then echo "→ Removing: $f"; rm -f "$f"; fi
done

if [ "$PURGE" -eq 1 ] && [ -d "$CONF_DIR" ]; then
  echo "→ Removing: $CONF_DIR"
  rm -rf "$CONF_DIR"
elif [ -d "$CONF_DIR" ]; then
  echo "→ Config kept: $CONF_DIR (use --purge to remove it)"
fi

systemctl --user daemon-reload
systemctl --user reset-failed jabra-busylight.service 2>/dev/null || true

echo
echo "✔ Daemon uninstalled."
echo "  System settings are still in place: run ./scripts/uninstall-system.sh to remove them."
