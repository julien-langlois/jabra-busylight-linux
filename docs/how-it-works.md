# How it works, and history

This document explains **why** each setting exists and how the values were found, so that everything can be redone, or adapted to another headset.

## The busylight as seen by the computer

The dongle (Jabra Link 390) shows up on Linux as a **HID** device, exposed as `/dev/hidrawN`. The busylight has no command of its own: it follows the call state that the computer reports to the headset. When the computer sets the **Off-Hook** LED, the headset considers itself in a call and lights its red rings.

That is what Teams, Zoom or Meet (through WebHID) do. Sending the same report is all it takes.

## Reading the HID descriptor

The descriptor describes every report the device accepts and sends:

```bash
grep -H HID_NAME /sys/class/hidraw/hidraw*/device/uevent      # find the dongle
pip install --user hid-tools                                  # or: pipx install hid-tools
hid-decode /sys/class/hidraw/hidrawN/device/report_descriptor
```

The Link 390 descriptor is archived in `reference/`: binary, hexadecimal and decoded. To read it again: `hid-decode reference/jabra-link-390.report_descriptor.bin`.

### The three reading rules

1. **Only keep the lines of the right type and Report ID.** Inputs (`Input`), outputs (`Output`) and configuration reports (`Feature`) are numbered separately, and each Report ID has its own numbering.
2. **Usages are assigned to fields in the order they are listed.** `Report Size (1)` and `Report Count (6)` followed by `Output` create 6 one-bit fields: the first declared usage gets the first bit, and so on.
3. **Bits fill from the least significant one.** The first bit is bit 0 of the first data byte, i.e. the value `0x01`.

Since the descriptor declares several Report IDs, every report written starts with the Report ID byte.

### Relevant excerpt (Telephony collection, Report ID 2)

```text
0x05, 0x08,   // Usage Page (LEDs)
0x09, 0x17,   // Usage (Off-Hook)     → bit 0
0x09, 0x09,   // Usage (Mute)         → bit 1
0x09, 0x18,   // Usage (Ring)         → bit 2
0x09, 0x20,   // Usage (Hold)         → bit 3
0x09, 0x21,   // Usage (Microphone)   → bit 4
0x09, 0x2a,   // Usage (On-Line)      → bit 5
0x75, 0x01,   // Report Size (1)
0x95, 0x06,   // Report Count (6)
0x91, 0x22,   // Output
...           // Ringer (bit 6) + 9 padding bits = 16 bits
```

### Result (verified with the hid-tools library)

**Report ID 2, output (host → headset)**: 2 data bytes.

| Byte   | Bit    | Value  | Usage                           |
| ------ | ------ | ------ | ------------------------------- |
| 0      | 0      | `0x01` | **Off-Hook → busylight**        |
| 0      | 1      | `0x02` | Mute (mute LED)                 |
| 0      | 2 to 5 |        | Ring, Hold, Microphone, On-Line |
| 0      | 6      |        | Ringer                          |
| 0 to 1 |        |        | padding                         |

**Report ID 2, input (headset → host)**:

| Byte | Bit    | Value  | Usage                                                  |
| ---- | ------ | ------ | ------------------------------------------------------ |
| 0    | 3      | `0x08` | **Phone Mute** (boom arm, mute button), relative event |
| 0    | 4 to 6 |        | Flash, Redial, Speed Dial                              |

The matching reports:

| Action               | Bytes written |
| -------------------- | ------------- |
| busylight on         | `02 01 00`    |
| busylight + mute LED | `02 03 00`    |
| everything off       | `02 00 00`    |

Manual test:

```bash
python3 -c "import os; f=os.open('/dev/hidrawN', os.O_WRONLY); os.write(f, bytes([0x02, 0x01, 0x00]))"
```

**Report ID 4** is the Jabra proprietary equivalent (vendor page `0xff40`), with Off-Hook on bit 0 as well. It serves as a fallback for `on`/`off` (`--report-id 4`). Its input report, however, puts mute on a different bit, so the daemon's mute sync assumes Report ID 2.

### Adapting to another Jabra headset

Decode the descriptor and look for the `Usage Page (Telephony Devices)` collection. Note its `Report ID` and the position of `Usage (Off-Hook)` in the output LEDs page. If the Report ID is not 2, or if Off-Hook is not on bit 0, adjust `JABRA_BUSYLIGHT_REPORT_ID` or the daemon's `LED_*` and `INPUT_PHONE_MUTE` constants.

## Why the udev rule is named 70-jabra.rules

By default, `/dev/hidrawN` belongs to root (`crw-------`). The rule adds the **`uaccess`** tag: systemd-logind then gives the active session user a read/write ACL, visible with `getfacl`.

Security note: the rule covers every hidraw interface of every Jabra device (vendor ID `0b0e`), including the vendor-specific reports (configuration, and probably firmware updates). Any process running in your active session can therefore send raw HID reports to the headset. This is the same model as the udev rules for FIDO security keys, and access is limited to the user physically logged in at the seat, but keep it in mind.

This tag is only applied by `73-seat-late.rules`. **A rule that sets it later, such as `99-jabra.rules`, has no effect.** This point cost one attempt during setup: the rule was in place, but `getfacl` only showed root.

## Why the hwdb rule

The kernel turns the HID *Phone Mute* usage (page `0x0b`, usage `0x2f`) into a `KEY_MICMUTE` key press. The desktop environment (GNOME, KDE…) reacts to this key by muting the system microphone.

With Meet on WebHID, raising the boom arm therefore had **two** independent effects: Meet muted itself (through hidraw), and the system muted the PipeWire source (through the key). A single desync was enough for Meet to unmute on lowering the boom while the system stayed muted, hence the "Microphone muted by system" warning.

The hwdb rule remaps this code (`KEYBOARD_KEY_b002f`, i.e. page `0x000b`, usage `0x002f`) to `reserved`. The kernel then ignores the event on the keyboard side, but it stays readable through hidraw by Meet and by the daemon. The `evdev:input:b0003v0B0Ep*` modalias limits the rule to USB (`b0003`) Jabra (`v0B0E`) devices.

To check that it is active:

```bash
udevadm info --query=property --name=/dev/input/eventX | grep KEYBOARD_KEY_b002f
```

## Why a daemon for Firefox

Firefox does not implement WebHID, and Mozilla has decided not to. No web page can talk to the headset from Firefox. Two options were considered:

1. **Watching microphone usage in PipeWire** (chosen): simple, independent of Meet, and works with any video-call application. The trade-offs: the busylight also turns on in Meet's pre-join screen, and there is no sync with Meet's mute button.
2. **A Firefox extension coupled with *native messaging***: more accurate (actual call state, two-way mute sync), but it depends on Meet's interface, which changes often, and it must be signed by Mozilla. Kept as a possible future improvement.

## Setup log (November 2026)

1. **Observation**: on Linux, the busylight never turned on with Google Meet, used in Firefox.
2. Research: Meet supports call control through WebHID, but only in Chrome. There is also a third-party extension ("Google Meet - Jabra Call Control support"), also based on WebHID.
3. Dongle identification: `hidraw2` = "Jabra Link 390", the only Jabra HID interface.
4. Descriptor reading with `hid-decode`: Report ID 2, Off-Hook on bit 0.
5. Chrome test: the permission was granted in Meet, but nothing happened. `getfacl` showed that only root could access the dongle, because the rule was named `99-jabra.rules`. After renaming it to `70-jabra.rules` and replugging, `user:<login>:rw-` appeared.
6. The busylight and mute sync then worked in Meet on Chrome. But when lowering the boom arm, Meet showed "Microphone muted by system".
7. Diagnosis: `pactl get-source-mute` switched from `no` to `yes` on each boom-arm movement, so the system was muting the microphone too. The "change" events from `pactl subscribe` alone were not conclusive, because of Chrome's automatic gain control.
8. Fix with the hwdb rule `KEYBOARD_KEY_b002f=reserved`: the system no longer reacts, and only Meet handles mute.
9. Daemon written for Firefox, using the same HID reports.
