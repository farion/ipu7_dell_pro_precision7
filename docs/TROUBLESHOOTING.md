# Troubleshooting

## Confirm the hardware

```bash
cat /sys/class/dmi/id/product_name
lspci -nn -s 00:05.0
```

Expected values include `Dell Pro Precision 7 16 PW716260` and `8086:b05d`.

## Sensor is not detected after boot

Check that the vision module exists and that CVS ownership transfer succeeded:

```bash
modinfo intel_cvs
journalctl -k -b | grep -E 'intel_cvs|Transfer of ownership|ov08x40|ipu7'
```

Expected kernel messages include:

```text
cvs_common_probe:Transfer of ownership success
ov08x40 3-0036
```

Confirm that the firmware and early module are present in the initramfs:

```bash
pkexec lsinitrd "/boot/initrd.img-$(uname -r)" \
  usr/lib/firmware/intel/ipu/ipu7ptl_fw.bin
pkexec lsinitrd "/boot/initrd.img-$(uname -r)" \
  "usr/lib/modules/$(uname -r)/ubuntu/dkms/vision/intel_cvs.ko.zst"
```

Rerun `pkexec ./scripts/install-system.sh` and reboot if either is missing.

## Camera exists but capture fails

Confirm the patched package version and the CPU ISP environment:

```bash
dpkg-query -W libcamera0.7
systemctl --user show pipewire.service -p Environment
systemctl --user show wireplumber.service -p Environment
```

The libcamera version should contain `+ipu7dell1`, and both services should
contain `LIBCAMERA_SOFTISP_MODE=cpu`.

Restart the user multimedia stack after changing configuration:

```bash
systemctl --user daemon-reload
systemctl --user restart pipewire.service
```

## IPU firmware reports error group 3, code 18

That code is `CAPTURE_HW_ERR_BAD_FRAME_DIM` and indicates that libcamera chose
the broken 1928x1088 OV08X40 mode. Rebuild and reinstall the local packages:

```bash
rm -rf build
./scripts/build-libcamera.sh
pkexec ./scripts/install-libcamera.sh build
systemctl --user restart pipewire.service
```

## EGL or debayer GPU errors

Messages such as `glFrameBufferTexture2D error 36054` or `debayerGPU failed`
mean the process did not inherit `LIBCAMERA_SOFTISP_MODE=cpu`. The variable is
required on both `pipewire.service` and `wireplumber.service`. Rerun:

```bash
./scripts/configure-user.sh
```

## Chrome reports NotFoundError

Enable `chrome://flags/#enable-webrtc-pipewire-camera`, fully relaunch Chrome,
and reset the site's camera permission. The flag is disabled by default even
when Chrome was built with PipeWire camera support.

Check `chrome://version` if launching with a command-line option. It should
show `--enable-features=WebRtcPipeWireCamera`.

## Teams for Linux does not list the camera

Teams for Linux is separate from the browser and needs the Chromium feature on
its own Electron process. Fully quit it from the tray, then launch:

```bash
teams-for-linux --enable-features=WebRtcPipeWireCamera
```

For a persistent setting, add this to its `config.json`, preserving any
existing keys:

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

Use `~/.config/teams-for-linux/config.json` for a native package,
`~/snap/teams-for-linux/current/.config/teams-for-linux/config.json` for Snap,
or
`~/.var/app/com.github.IsmaelMartinez.teams_for_linux/config/teams-for-linux/config.json`
for Flatpak. If the current Teams for Linux release still does not expose the
camera, upgrade it: an Electron version without PipeWire camera support cannot
consume this native PipeWire source. This repository deliberately removes the
legacy V4L2 loopback relay rather than keeping a permanent relay process.

## First frame is black

The sensor and automatic exposure need several frames to settle. This is why
`scripts/test-camera.sh` captures twelve images and checks the last one.

## Check idle power state

After every camera client has exited:

```bash
cat /sys/bus/i2c/devices/i2c-OVTI08F4:00/power/runtime_status
cat /sys/bus/i2c/devices/i2c-OVTI08F4:00/power/runtime_usage
```

Expected values are `suspended` and `0`. PipeWire and WirePlumber may keep the
media device open for enumeration without keeping the image sensor powered.

## Suspend immediately returns while the camera is active

The IPU7 ISYS driver returns `-EBUSY` if a firmware stream is open during
system suspend. The sleep handler stops PipeWire before sleep and restores it
after resume. Confirm that it is enabled:

```bash
systemctl is-enabled ipu7-camera-suspend.service
systemctl status ipu7-camera-suspend.service
```

After a suspend/resume cycle, verify that the handler ran and ISYS did not
reject suspend:

```bash
journalctl -b -u ipu7-camera-suspend.service
journalctl -k -b --grep='intel_ipu7_isys.*failed to suspend|PM: suspend'
```

## Useful logs

```bash
journalctl --user -u pipewire.service -b
journalctl --user -u wireplumber.service -b
journalctl -k -b
wpctl status
```
