# Chrome / Chromium method (WebHID)

Google Meet can drive compatible headsets through Chrome's **WebHID** API: it turns the busylight on when you join a call and syncs the mute button both ways. On Linux, only two system settings are missing.

## Requirements

- Google Chrome, Chromium or another Chromium-based browser (Edge, Brave…)
- Linux with systemd and udev
- Jabra dongle plugged in (tested with the Jabra Link 390)

## 1. Install the system settings

### With the script

```bash
./scripts/install-system.sh
```

### By hand (equivalent)

```bash
# Dongle access for the session user
sudo install -D -m 0644 system/70-jabra.rules /etc/udev/rules.d/70-jabra.rules

# Stop the desktop from also muting the microphone when the boom arm is raised
sudo install -D -m 0644 system/70-jabra-micmute.hwdb /etc/udev/hwdb.d/70-jabra-micmute.hwdb
sudo systemd-hwdb update

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw --subsystem-match=input
```

Either way, **unplug and replug the dongle** afterwards.

To install only the udev rule and keep the system-level boom-arm mute, use `./scripts/install-system.sh --no-micmute-fix`. Read the [warning in the README](../README.md#important-the-boom-arm-no-longer-mutes-other-applications) before choosing.

## 2. Check

```bash
./scripts/check.sh
```

Or by hand:

```bash
grep -H HID_NAME /sys/class/hidraw/hidraw*/device/uevent | grep -i jabra
getfacl /dev/hidrawN      # N = number found above
```

`getfacl` must show a `user:<your_login>:rw-` line.

## 3. Enable call control in Meet

1. Join a Google Meet call.
2. Open **Settings → Audio**.
3. At the bottom, under **Call control**, click **Connect device**.
4. In the browser dialog, pick **Jabra Link 390** (or your dongle), then **Connect**.

Chrome remembers the permission. It shows up in the site settings (icon left of the address bar) as "Jabra Link 390 – HID device", and later calls do not need this step again.

If you installed the system settings after connecting the device, **leave the call, reload the page and join again**: Meet only opens the device when you join.

## 4. Expected result

- The busylight turns on when you join the call and off when you leave.
- Raising the boom arm switches Meet to "Muted"; lowering it unmutes.
- The center button of the right ear cup hangs up.

## Special cases

### Chromium installed as a Snap (Ubuntu)

Snap confinement blocks access to HID devices. Try:

```bash
sudo snap connect chromium:raw-usb
```

Google Chrome installed from the official `.deb` package is not affected.

### Chromium as a Flatpak

```bash
flatpak override --user --device=all org.chromium.Chromium
```

You can also use Flatseal.

### Keeping Firefox as your main browser

Install Meet as an app in Chrome: ⋮ menu → **Cast, save, and share → Install page as app**. Meet then opens in its own window, with its own launcher.

## Uninstall

See [uninstall.md](uninstall.md).
