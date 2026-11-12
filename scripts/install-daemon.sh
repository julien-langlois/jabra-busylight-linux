#!/usr/bin/env bash
# Install the jabra-busylight daemon for the current user (Firefox method).
# Run WITHOUT sudo. Requires the system settings (install-system.sh).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$HOME/.local/bin/jabra-busylight"
UNIT="$HOME/.config/systemd/user/jabra-busylight.service"
CONF="$HOME/.config/jabra-busylight/config"

die()  { echo "✘ $*" >&2; exit 1; }
warn() { echo "⚠ $*" >&2; }

[ "$(id -u)" -ne 0 ] || die "Run as a regular user, without sudo."
command -v python3 >/dev/null || die "python3 not found."
python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' || die "Python 3.9 or newer is required."
command -v pactl >/dev/null || die "pactl not found: install pulseaudio-utils (or your distribution's equivalent)."
pactl --format=json info >/dev/null 2>&1 || die "pactl does not support --format=json (version 16 or newer required) or PipeWire/PulseAudio is not responding."
[ -e /etc/udev/rules.d/70-jabra.rules ] || warn "udev rule missing: run ./scripts/install-system.sh first"

echo "→ Program: $BIN"
install -D -m 0755 "$REPO_DIR/daemon/jabra-busylight" "$BIN"
echo "→ Service: $UNIT"
install -D -m 0644 "$REPO_DIR/daemon/jabra-busylight.service" "$UNIT"
if [ -e "$CONF" ]; then
  echo "→ Config:  $CONF (existing, kept)"
else
  echo "→ Config:  $CONF"
  install -D -m 0644 "$REPO_DIR/daemon/config.example" "$CONF"
fi

systemctl --user daemon-reload
systemctl --user enable --now jabra-busylight.service
systemctl --user restart jabra-busylight.service

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) warn "$HOME/.local/bin is not in your PATH: use the full path $BIN for manual commands." ;;
esac

echo
echo "✔ Daemon installed and started."
echo "  Diagnostics: jabra-busylight status"
echo "  Logs:        journalctl --user -u jabra-busylight -f"
