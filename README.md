# jabra-busylight-linux

Automatically turn on the **busylight** (red rings) of a **Jabra Evolve2** headset on Linux during video calls, especially **Google Meet**, in Chrome/Chromium, with mute-button and boom-arm sync. An **experimental** daemon covers Firefox and other applications.

> Personal project, not affiliated with Jabra / GN Audio.

## The problem

The busylight turns on when the video-call application sends the HID "in a call" (*Off-Hook*) signal to the headset. There is no Jabra application for Linux, and:

- **Chrome/Chromium** can send this signal from Google Meet (WebHID API), but by default it is not allowed to access the dongle;
- **Firefox** does not support WebHID: a small local daemon is needed.

On Linux, a second problem shows up: raising the boom arm mutes the microphone **twice** (in Meet and at system level), and Meet then shows "Microphone muted by system". An hwdb rule fixes this.

## Two methods

| | Chrome / Chromium | Firefox (or any other application) |
|---|---|---|
| How it works | Meet drives the headset through WebHID | Daemon watching microphone usage in PipeWire |
| Busylight | on when you join the meeting | on as soon as the microphone opens (including the pre-join screen) |
| Boom arm / mute button | synced with Meet both ways | mutes the microphone at system level (Meet sees it as "muted by system") |
| To install | system settings | system settings + user daemon |
| Status | tested and working | **experimental**: tested against a simulated dongle only, not yet on real hardware |

Both methods can coexist: by default the daemon ignores Chrome and Chromium.

## Quick start

```bash
git clone https://github.com/julien-langlois/jabra-busylight-linux.git
cd jabra-busylight-linux
./scripts/install-system.sh      # asks for your sudo password
# unplug and replug the Jabra dongle
./scripts/check.sh
```

Then:

- **Chrome/Chromium**: in a Meet call, open Settings → Audio → **Call control** → **Connect device** and pick the Jabra dongle. Details: [docs/chrome.md](docs/chrome.md).
- **Firefox** (experimental): `./scripts/install-daemon.sh`, then `jabra-busylight status`. Details: [docs/firefox.md](docs/firefox.md).

## Important: the boom arm no longer mutes other applications

By default, `install-system.sh` installs an hwdb rule that stops the kernel from turning the Jabra mute event into a system-wide `KEY_MICMUTE` key press (this is what fixes "Microphone muted by system" in Meet).

The side effect: **raising the boom arm or pressing the mute button no longer mutes the microphone at system level**. Only an application that talks to the headset over HID reacts to it: Google Meet in Chrome (WebHID), or the daemon during a call in Firefox. In any other application (Zoom or Teams desktop clients, Discord, Firefox without the daemon, a web app without call control…), **the microphone stays live even with the boom arm raised**. Mute from the application itself.

If you would rather keep the system-level mute everywhere (and live with the "Microphone muted by system" warning in Meet), install the udev rule only:

```bash
./scripts/install-system.sh --no-micmute-fix
```

## Uninstall

```bash
./scripts/uninstall-daemon.sh --purge   # if the daemon is installed
./scripts/uninstall-system.sh
# unplug and replug the dongle
```

Then remove the HID permission for meet.google.com in Chrome. Full procedure: [docs/uninstall.md](docs/uninstall.md).

## Repository layout

```
├── system/
│   ├── 70-jabra.rules             udev rule: dongle access for the session user
│   └── 70-jabra-micmute.hwdb      disables the Jabra mic-mute key
├── daemon/
│   ├── jabra-busylight            Python daemon (standard library only)
│   ├── jabra-busylight.service    systemd user service
│   └── config.example             commented configuration
├── scripts/
│   ├── install-system.sh   uninstall-system.sh
│   ├── install-daemon.sh   uninstall-daemon.sh
│   └── check.sh                   installation diagnostics
├── docs/
│   ├── chrome.md                  Chrome/Chromium method
│   ├── firefox.md                 Firefox method (daemon)
│   ├── uninstall.md               remove everything
│   ├── troubleshooting.md         common problems
│   └── how-it-works.md            HID protocol, design choices, history
└── reference/
    └── jabra-link-390.report_descriptor.*   captured HID descriptor
```

## Tested hardware and environment

- Jabra Evolve2 65 headset with a **Jabra Link 390** dongle
- Linux with systemd, PipeWire (pipewire-pulse) and GNOME
- Google Meet in Google Chrome (WebHID method)

Other Jabra headsets with a busylight should work, but the *Report ID* may differ: see [docs/how-it-works.md](docs/how-it-works.md) to check yours.

## License

MIT, see [LICENSE](LICENSE).
