# Full uninstall

Follow the steps in order. Each one can be done with a script or by hand.

## 1. Daemon (if the Firefox method is installed)

### With the script

```bash
./scripts/uninstall-daemon.sh            # keeps ~/.config/jabra-busylight
./scripts/uninstall-daemon.sh --purge    # also removes the configuration
```

### By hand

```bash
systemctl --user disable --now jabra-busylight.service
rm -f ~/.config/systemd/user/jabra-busylight.service ~/.local/bin/jabra-busylight
rm -rf ~/.config/jabra-busylight          # optional: configuration
systemctl --user daemon-reload
systemctl --user reset-failed jabra-busylight.service 2>/dev/null
```

Stopping the service turns the busylight off. If the daemon had muted the microphone, it unmutes it.

## 2. System settings

### With the script

```bash
./scripts/uninstall-system.sh
```

### By hand

```bash
sudo rm -f /etc/udev/rules.d/70-jabra.rules
sudo rm -f /etc/udev/hwdb.d/70-jabra-micmute.hwdb
sudo systemd-hwdb update
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw --subsystem-match=input
```

**Unplug and replug the dongle** to restore the original behavior: the dongle is accessible to root only again, and raising the boom arm mutes the system microphone again.

## 3. Chrome / Chromium permissions

1. On `meet.google.com`, click the icon left of the address bar.
2. On the "Jabra Link 390 – HID device" line, click the cross.

You can also remove the permission from `chrome://settings/content/hidDevices`.

If you changed a Snap or Flatpak package:

```bash
sudo snap disconnect chromium:raw-usb
flatpak override --user --reset org.chromium.Chromium
```

## 4. Final checks

```bash
pactl set-source-mute @DEFAULT_SOURCE@ 0     # in case the microphone was left muted
ls /etc/udev/rules.d/ | grep -i jabra         # must print nothing
ls /etc/udev/hwdb.d/ | grep -i jabra          # must print nothing
systemctl --user status jabra-busylight 2>&1 | head -1   # "could not be found"
```

If the busylight stayed on, unplug the dongle or switch the headset off and on again.
