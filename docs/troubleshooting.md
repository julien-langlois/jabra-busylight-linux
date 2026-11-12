# Troubleshooting

Always start with:

```bash
./scripts/check.sh
jabra-busylight status          # if the daemon is installed
```

## Meet lists the dongle as allowed, but nothing happens

Most common cause: Chrome is not allowed to open `/dev/hidrawN`.

```bash
getfacl /dev/hidrawN
```

If there is no `user:<your_login>:rw-` line:

- check that the rule is in `/etc/udev/rules.d/70-jabra.rules`. **The prefix matters**: with `99-`, the `uaccess` tag comes too late and is ignored;
- unplug and replug the dongle;
- check that the rule matches the dongle: `udevadm info -a /dev/hidrawN | grep -i idvendor` must show `0b0e`.

Then leave the call, reload Meet and join again.

Chrome's access errors are visible in `chrome://device-log`.

## "Microphone muted by system" in Meet

The microphone is muted at system level, in addition to or instead of Meet.

To unblock it right away:

```bash
pactl set-source-mute @DEFAULT_SOURCE@ 0
```

To check whether the boom arm acts on the system, run the command below and move the boom arm:

```bash
watch -n 0.5 'pactl get-source-mute @DEFAULT_SOURCE@'
```

If the output switches between `Mute: no` and `Mute: yes`, the hwdb rule is not active. Install it (`install-system.sh`) and replug the dongle.

Note: `pactl subscribe` also shows "change" events on the source when Chrome adjusts the gain automatically. These events do not mean that the mute state changes.

## The busylight stays on

```bash
jabra-busylight off
```

Without the daemon:

```bash
python3 -c "import os; f=os.open('/dev/hidrawN', os.O_WRONLY); os.write(f, bytes([0x02, 0x00, 0x00]))"
```

Unplugging the dongle or switching the headset off and on also resets everything.

## The hidraw number changed

This is normal: it depends on the order in which devices are detected. The daemon and `check.sh` find the dongle by its vendor ID. For manual commands, look up the number:

```bash
grep -H HID_NAME /sys/class/hidraw/hidraw*/device/uevent | grep -i jabra
```

## The daemon does not start

```bash
journalctl --user -u jabra-busylight -n 50
```

| Message                                | Fix                                              |
| -------------------------------------- | ------------------------------------------------ |
| `pactl does not support --format=json` | upgrade `pulseaudio-utils` (version 16 or newer) |
| `Permission denied on /dev/hidrawN`    | install the udev rule, then replug the dongle    |
| `No accessible Jabra dongle yet`       | dongle unplugged: the daemon retries on its own  |
| `PipeWire/pactl unavailable`           | check `systemctl --user status pipewire-pulse`   |

## The daemon does not turn the busylight on during a Firefox call

Run `jabra-busylight status` during the call:

- **"Microphone sources … none"**: the source name does not contain "jabra". Find it with `pactl list short sources`, then set `JABRA_BUSYLIGHT_SOURCE_MATCH`.
- **Firefox shows as "ignored" or "not listed"**: review `JABRA_BUSYLIGHT_APPS` and `JABRA_BUSYLIGHT_IGNORE`.
- **No application listed**: Meet may be using another microphone. Check the microphone selected in Meet under Settings → Audio.

If `jabra-busylight on` does nothing either, try the Jabra proprietary Report ID:

```bash
jabra-busylight on --report-id 4
```

## Snap or Flatpak Chromium does not see the dongle

See the "Special cases" section of [chrome.md](chrome.md).
