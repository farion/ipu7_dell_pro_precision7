# IPU7 webcam support for Dell Pro Precision 7 16

This repository enables the internal OV08X40 webcam on the Dell Pro Precision
7 16 PW716260 running Ubuntu 26.04 LTS (Resolute).

## Tested hardware and software

- Dell Pro Precision 7 16 PW716260
- Intel Panther Lake IPU7, PCI ID `8086:b05d`
- OV08X40 camera sensor (`OVTI08F4`)
- Ubuntu 26.04.1 LTS
- Kernel `7.0.0-30-generic`
- Ubuntu libcamera `0.7.0-1ubuntu2`
- PipeWire `1.6.2`

Do not use this installer on a different model. The scripts reject an
unexpected DMI model, Ubuntu release, architecture, or IPU PCI ID.

## What this fixes

The stock installation has three independent problems on this machine:

1. The `INTC10E1` camera control device needs Canonical's `intel_cvs` vision
   module early in boot before the IPU7 and OV08X40 probes complete.
2. The OV08X40's binned 1928x1088 mode fails in IPU7 with firmware error group
   3, code 18 (`CAPTURE_HW_ERR_BAD_FRAME_DIM`). The full 3856x2176 sensor mode
   works.
3. The EGL software ISP path fails on the hybrid Intel/NVIDIA graphics setup.
   PipeWire and WirePlumber must select libcamera's CPU software ISP.
4. The IPU7 ISYS driver rejects system suspend with `-EBUSY` while a camera
   firmware stream is open. A sleep unit cleanly stops the user PipeWire stack
   before suspend and restores its previous state after resume.

The resulting camera is a native PipeWire/libcamera source. It does not use a
continuous GStreamer relay or `v4l2loopback`, and runtime power management
suspends the sensor when no application is using it.

## Install

The installer removes the legacy V4L2 relay packages, downloads Ubuntu's signed
source package, applies the small libcamera patch in this repository, builds
local Debian packages, and installs the system and per-user configuration.

```bash
git clone https://YOUR-REPOSITORY-URL/ipu7_dell_pro_precision7.git
cd ipu7_dell_pro_precision7
./install.sh
```

The build takes several minutes and requires about 2 GB of free space. Reboot
after the installer finishes.

The installer uses `pkexec` only for package installation and system files.
The libcamera source package is downloaded and built as the invoking user.

An application using the camera when sleep starts loses that stream. PipeWire
and the camera source return after resume, and the application can reopen it.

## Chrome and Chromium

Chromium currently builds PipeWire camera support but disables it by default
on Linux. Open this URL after reboot:

```text
chrome://flags/#enable-webrtc-pipewire-camera
```

Set **PipeWire Camera support** to **Enabled** and relaunch the browser. If a
site previously selected a removed V4L2 or loopback device, reset that site's
camera permission before trying again.

The equivalent command-line option is:

```text
--enable-features=WebRtcPipeWireCamera
```

## Teams for Linux

Teams for Linux is an Electron application, so enabling the browser flag does
not enable PipeWire camera support in Teams. Fully quit it from the tray, then
test with:

```bash
teams-for-linux --enable-features=WebRtcPipeWireCamera
```

To make this persistent, add the flag to its configuration file (preserving
any existing settings):

```json
{
  "electronCLIFlags": [
    [
      "enable-features",
      "WebRTCPipeWireCapturer,WebRtcPipeWireCamera"
    ]
  ]
}
```

For a native package, use `~/.config/teams-for-linux/config.json`. The Snap
path is `~/snap/teams-for-linux/current/.config/teams-for-linux/config.json`,
and the Flatpak path is
`~/.var/app/com.github.IsmaelMartinez.teams_for_linux/config/teams-for-linux/config.json`.
Restart Teams completely and select the OV08X40 camera in Teams settings.

`./install.sh` installs this configuration for the native Teams for Linux
package and preserves unrelated existing settings. Snap and Flatpak use
different configuration locations and are not changed by the installer.

If the camera is still absent, update Teams for Linux. An Electron build that
does not include the PipeWire camera feature cannot use this native PipeWire
source; this installer intentionally does not install a V4L2 loopback relay.

## Verify

Run the non-destructive checks:

```bash
./scripts/verify.sh
```

Capture a short 1280x720 PipeWire sequence:

```bash
./scripts/test-camera.sh
```

The first frame can be black while exposure starts. The test keeps twelve
frames and reports the final image path under `/tmp`.

After the test exits, this should report `suspended`:

```bash
cat /sys/bus/i2c/devices/i2c-OVTI08F4:00/power/runtime_status
```

## Package updates

The installer holds the five locally patched libcamera packages so an Ubuntu
update does not silently restore the broken sensor-mode selection. Review
Ubuntu updates for an upstream fix before removing the holds:

```bash
pkexec apt-mark unhold libcamera0.7 libcamera-ipa libcamera-tools \
  libcamera-v4l2 gstreamer1.0-libcamera
```

Rebuild this repository's package against a newer Ubuntu libcamera source
before upgrading if the upstream package still has the problem.

## Repository contents

- `config/`: dracut, libcamera tuning, WirePlumber, and systemd configuration
- `patches/`: minimal libcamera OV08X40 mode-selection patch
- `scripts/build-libcamera.sh`: reproducible Ubuntu source-package build
- `scripts/install-system.sh`: vision modules, firmware, initramfs, and system configuration
- `scripts/configure-user.sh`: CPU ISP environment for PipeWire and WirePlumber
- `scripts/verify.sh`: hardware and configuration checks
- `scripts/test-camera.sh`: native PipeWire capture test
- `scripts/ipu7-camera-suspend`: clean PipeWire teardown and restore around sleep
- `docs/TROUBLESHOOTING.md`: logs, known symptoms, and recovery steps

## Licensing and firmware

The scripts and documentation are MIT licensed. The OV08X40 tuning file is
CC0-1.0. The libcamera patch modifies LGPL-2.1-or-later source and is provided
under the same terms as that source file.

No firmware binary is redistributed. The installer uses
`linux-firmware-intel-graphics` from Ubuntu and decompresses the packaged
`ipu7ptl_fw.bin.zst` for the early firmware request.

## References

- https://gist.github.com/AlexeySalmin/d5f74fa9cb2fa02c1bb562eb912cae2c
- https://github.com/CachyOS/linux-cachyos/issues/804
- https://github.com/basecamp/omarchy/issues/6000
- https://libcamera.org/
