#!/usr/bin/env bash
# Check the installation: dongle detected, access rights, system rules,
# KEY_MICMUTE disabled, daemon state and system microphone state.
set -uo pipefail
ok=1

echo "== Jabra dongles (hidraw) =="
found=0
for d in /sys/class/hidraw/hidraw*; do
  [ -e "$d/device/uevent" ] || continue
  id=$(grep -m1 '^HID_ID=' "$d/device/uevent" | cut -d= -f2)
  vendor=$(echo "$id" | cut -d: -f2)
  [ "${vendor^^}" = "00000B0E" ] || continue
  found=1
  name=$(grep -m1 '^HID_NAME=' "$d/device/uevent" | cut -d= -f2- | sed 's/^ *//')
  dev="/dev/$(basename "$d")"
  if [ -r "$dev" ] && [ -w "$dev" ]; then acc="OK"; else acc="DENIED"; ok=0; fi
  printf '  %-14s %-26s access: %s\n' "$dev" "$name" "$acc"
done
[ "$found" -eq 1 ] || { echo "  no Jabra dongle detected"; ok=0; }

echo
echo "== System files =="
for f in /etc/udev/rules.d/70-jabra.rules /etc/udev/hwdb.d/70-jabra-micmute.hwdb; do
  if [ -e "$f" ]; then echo "  present: $f"; else echo "  missing: $f"; fi
done
[ -e /etc/udev/rules.d/70-jabra.rules ] || ok=0

echo
echo "== Jabra mic-mute key disabled (hwdb) =="
seen=0; neutral=0
for ev in /dev/input/event*; do
  props=$(udevadm info --query=property --name="$ev" 2>/dev/null) || continue
  echo "$props" | grep -qi '^ID_VENDOR_ID=0b0e' || continue
  seen=1
  echo "$props" | grep -q '^KEYBOARD_KEY_b002f=reserved' && neutral=1
done
if [ "$seen" -eq 0 ]; then echo "  no Jabra input device found"
elif [ "$neutral" -eq 1 ]; then echo "  yes"
else echo "  no (expected if the hwdb rule is not installed or the dongle was not replugged)"
fi

echo
echo "== Daemon (Firefox method) =="
if systemctl --user is-enabled jabra-busylight.service >/dev/null 2>&1; then
  echo "  service: $(systemctl --user is-active jabra-busylight.service)"
else
  echo "  not installed"
fi

echo
echo "== System microphone =="
if command -v pactl >/dev/null 2>&1; then
  echo "  $(LC_ALL=C pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null || echo 'unavailable')"
else
  echo "  pactl not installed"
fi

echo
if [ "$ok" -eq 1 ]; then echo "✔ Dongle access OK"; else echo "✘ Problem detected (see docs/troubleshooting.md)"; fi
[ "$ok" -eq 1 ]
