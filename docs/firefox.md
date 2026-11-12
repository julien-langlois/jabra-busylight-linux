# Firefox method (local daemon)

> **Experimental.** The daemon has only been tested against a simulated dongle, not yet on real hardware. Feedback is welcome.

Firefox does not support WebHID, so Google Meet cannot talk to the headset. The `jabra-busylight` daemon fills the gap: it relies on microphone usage rather than on Meet itself.

## How it works

```text
Firefox (Meet) ──opens mic──▶ PipeWire ──event──▶ jabra-busylight
                                                        │
                                Off-Hook HID report ◀───┘
                                         │
                                         ▼
                                Jabra dongle ──▶ busylight on
```

1. The daemon listens to PipeWire events (`pactl subscribe`).
2. As soon as an application records from the **Jabra microphone source**, it sends the *Off-Hook* HID report and the busylight turns on.
3. When no application is recording any more, it waits a few seconds (5 by default), then turns the busylight off.
4. During a call, if mute sync is enabled, each boom-arm movement toggles the mute state of the PipeWire source and the headset *Mute* LED. When the call ends, if the daemon had muted the microphone, it unmutes it.

The dongle is located by its Jabra vendor ID, not by its `hidrawN` number, so unplugging or rebooting is not a problem.

## Requirements

- The **system settings** (udev and hwdb rules): see step 1
- Python 3.9 or newer (no external dependency)
- `pactl` version 16 or newer, for the `--format=json` option. It comes with `pulseaudio-utils` on Debian and Ubuntu, and works with PipeWire through `pipewire-pulse`.
- systemd (user service)

## 1. System settings

```bash
./scripts/install-system.sh
# unplug and replug the dongle
./scripts/check.sh
```

The hwdb rule matters here too. Without it, both the desktop and the daemon would toggle mute on each boom-arm movement, cancelling each other out.

## 2. Install the daemon

### With the script

```bash
./scripts/install-daemon.sh     # without sudo
```

### By hand (equivalent)

```bash
install -D -m 0755 daemon/jabra-busylight ~/.local/bin/jabra-busylight
install -D -m 0644 daemon/jabra-busylight.service ~/.config/systemd/user/jabra-busylight.service
install -D -m 0644 daemon/config.example ~/.config/jabra-busylight/config
systemctl --user daemon-reload
systemctl --user enable --now jabra-busylight.service
```

## 3. Test

```bash
jabra-busylight status        # dongle, permissions, microphone source, detected applications
jabra-busylight on            # turn the busylight on by hand
jabra-busylight off           # turn it off
journalctl --user -u jabra-busylight -f   # live logs
```

Example `status` output during a call:

```text
Jabra dongles (hidraw):
  /dev/hidraw2   Jabra Link 390             telephony: yes  access: OK

Microphone sources matching "jabra":
  #57 alsa_input.usb-GN_Netcom_A_S_Jabra_Link_390_....mono-fallback (muted: no)

Applications recording from this microphone:
  [triggers] Firefox / AudioCallbackDriver
```

Then open a Meet call in Firefox: the log should show "Microphone in use by: Firefox…" followed by "Busylight on".

## Configuration

File: `~/.config/jabra-busylight/config`. After editing: `systemctl --user restart jabra-busylight`.

| Variable                        | Default                                            | Purpose                                                 |
| ------------------------------- | -------------------------------------------------- | ------------------------------------------------------- |
| `JABRA_BUSYLIGHT_APPS`          | *(empty = all)*                                    | applications that trigger the busylight, e.g. `firefox` |
| `JABRA_BUSYLIGHT_IGNORE`        | `pavucontrol,gnome-control-center,chrome,chromium` | ignored applications                                    |
| `JABRA_BUSYLIGHT_OFF_DELAY`     | `5`                                                | seconds before turning off                              |
| `JABRA_BUSYLIGHT_MUTE_SYNC`     | `true`                                             | handle the boom arm and mute button during calls        |
| `JABRA_BUSYLIGHT_SOURCE_MATCH`  | `jabra`                                            | text identifying the PipeWire microphone source         |
| `JABRA_BUSYLIGHT_DEVICE_MATCH`  | *(empty)*                                          | filter on the dongle HID name                           |
| `JABRA_BUSYLIGHT_REPORT_ID`     | `2`                                                | Report ID of the Telephony report (see how-it-works.md) |
| `JABRA_BUSYLIGHT_POLL_INTERVAL` | `5`                                                | fallback periodic check                                 |
| `JABRA_BUSYLIGHT_VERBOSE`       | `false`                                            | verbose logging (HID reports sent)                      |

Each variable has an equivalent command-line option (`jabra-busylight daemon --help`).

## Known limitations

- **Pre-join screen**: Meet opens the microphone on the "Ready to join?" screen, so the busylight turns on before you actually join.
- **Any recording counts**: a voice memo or Audacity also turns the busylight on. To restrict it, use `JABRA_BUSYLIGHT_APPS=firefox`.
- **Mute**: the boom arm mutes the microphone at system level, not inside Meet. Meet may show that the microphone is muted by the system, which is expected here. Meet's own mute button does not light the headset *Mute* LED.
- **Coexisting with Chrome**: Chrome and Chromium are ignored by default so as not to interfere with the WebHID method. Keep `chrome` in the list if you also use Meet in Chrome with call control enabled.
- **Validation**: the daemon was written from the Link 390 HID descriptor and tested against a simulated dongle. The real boom-arm behavior in Off-Hook mode still has to be confirmed on hardware.

## Uninstall

See [uninstall.md](uninstall.md).
