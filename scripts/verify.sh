#!/usr/bin/env bash
set -u

errors=0

pass()
{
	printf 'PASS: %s\n' "$*"
}

fail()
{
	printf 'FAIL: %s\n' "$*" >&2
	errors=$((errors + 1))
}

product=$(< /sys/class/dmi/id/product_name)
[[ $product == "Dell Pro Precision 7 16 PW716260" ]] && \
	pass "supported Dell model" || fail "unsupported model: $product"

if [[ -r /sys/bus/pci/devices/0000:00:05.0/vendor && \
      -r /sys/bus/pci/devices/0000:00:05.0/device && \
      $(< /sys/bus/pci/devices/0000:00:05.0/vendor) == 0x8086 && \
      $(< /sys/bus/pci/devices/0000:00:05.0/device) == 0xb05d ]]; then
	pass "Intel Panther Lake IPU7 8086:b05d"
else
	fail "Intel Panther Lake IPU7 8086:b05d not found at 0000:00:05.0"
fi

modinfo intel_cvs >/dev/null 2>&1 && pass "intel_cvs module available" || \
	fail "intel_cvs module missing; install linux-modules-vision-generic"

[[ -e /sys/bus/i2c/drivers/ov08x40/i2c-OVTI08F4:00 ]] && \
	pass "OV08X40 sensor bound" || fail "OV08X40 sensor is not bound"

version=$(dpkg-query -W -f='${Version}' libcamera0.7 2>/dev/null || true)
[[ $version == 0.7.0-1ubuntu2+* ]] && pass "locally patched libcamera $version" || \
	fail "patched libcamera is not installed (found: ${version:-none})"

pipewire_env=$(systemctl --user show pipewire.service -p Environment 2>/dev/null || true)
[[ $pipewire_env == *LIBCAMERA_SOFTISP_MODE=cpu* ]] && \
	pass "PipeWire CPU ISP environment" || fail "PipeWire CPU ISP environment missing"

wireplumber_env=$(systemctl --user show wireplumber.service -p Environment 2>/dev/null || true)
[[ $wireplumber_env == *LIBCAMERA_SOFTISP_MODE=cpu* ]] && \
	pass "WirePlumber CPU ISP environment" || fail "WirePlumber CPU ISP environment missing"

if [[ -x /usr/local/libexec/ipu7-camera-suspend ]] && \
   systemctl is-enabled --quiet ipu7-camera-suspend.service 2>/dev/null; then
	pass "IPU7 suspend handler installed and enabled"
else
	fail "IPU7 suspend handler is not installed and enabled"
fi

legacy_packages=()
for package in ipu7-camera v4l2-relayd v4l2loopback-dkms; do
	status=$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null || true)
	[[ $status == ii* ]] && legacy_packages+=("$package")
done
if (( ${#legacy_packages[@]} == 0 )); then
	pass "legacy V4L2 relay stack absent"
else
	fail "legacy V4L2 relay packages installed: ${legacy_packages[*]}"
fi

if wpctl status 2>/dev/null | grep -q ov08x40; then
	pass "OV08X40 exposed through PipeWire/libcamera"
else
	fail "OV08X40 PipeWire source missing"
fi

runtime_file=/sys/bus/i2c/devices/i2c-OVTI08F4:00/power/runtime_status
if [[ -r $runtime_file ]]; then
	pass "sensor runtime state: $(< "$runtime_file")"
else
	fail "sensor runtime power state unavailable"
fi

if (( errors > 0 )); then
	printf '\n%d check(s) failed. See docs/TROUBLESHOOTING.md.\n' "$errors" >&2
	exit 1
fi

printf '\nAll camera checks passed.\n'
