#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

die()
{
	echo "error: $*" >&2
	exit 1
}

[[ $EUID -eq 0 ]] || die "run this script as root"

# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 26.04 ]] || \
	die "this installer supports Ubuntu 26.04 only"
[[ $(dpkg --print-architecture) == amd64 ]] || die "amd64 is required"

product=$(< /sys/class/dmi/id/product_name)
[[ $product == "Dell Pro Precision 7 16 PW716260" ]] || \
	die "unsupported computer: $product"

[[ -r /sys/bus/pci/devices/0000:00:05.0/vendor ]] || \
	die "IPU7 PCI device 0000:00:05.0 was not found"
vendor=$(< /sys/bus/pci/devices/0000:00:05.0/vendor)
device=$(< /sys/bus/pci/devices/0000:00:05.0/device)
[[ $vendor == 0x8086 && $device == 0xb05d ]] || \
	die "unsupported IPU PCI ID: $vendor:$device"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get purge -y \
	ipu7-camera \
	v4l2-relayd \
	v4l2loopback-dkms
apt-get install -y \
	dracut \
	gstreamer1.0-libcamera \
	gstreamer1.0-pipewire \
	gstreamer1.0-plugins-base \
	gstreamer1.0-tools \
	libcamera-ipa \
	libcamera-tools \
	libcamera-v4l2 \
	libcamera0.7 \
	libspa-0.2-libcamera \
	jq \
	linux-firmware-intel-graphics \
	linux-modules-vision-generic \
	pipewire \
	wireplumber \
	zstd

firmware_zst=/usr/lib/firmware/intel/ipu/ipu7ptl_fw.bin.zst
firmware=/usr/lib/firmware/intel/ipu/ipu7ptl_fw.bin
[[ -f $firmware_zst ]] || die "$firmware_zst is missing"
zstd -d -f "$firmware_zst" -o "$firmware"
chmod 0644 "$firmware"

install -Dm0644 "$repo_dir/config/dracut/ipu7-firmware.conf" \
	/etc/dracut.conf.d/ipu7-firmware.conf
install -Dm0644 "$repo_dir/config/libcamera/ov08x40.yaml" \
	/usr/share/libcamera/ipa/simple/ov08x40.yaml
install -Dm0644 "$repo_dir/config/wireplumber/51-ipu7-camera.conf" \
	/etc/wireplumber/wireplumber.conf.d/51-ipu7-camera.conf
install -Dm0755 "$repo_dir/scripts/ipu7-camera-suspend" \
	/usr/local/libexec/ipu7-camera-suspend
install -Dm0644 \
	"$repo_dir/config/systemd/system/ipu7-camera-suspend.service" \
	/etc/systemd/system/ipu7-camera-suspend.service
systemctl daemon-reload
systemctl enable ipu7-camera-suspend.service

kernel=$(uname -r)
modinfo -k "$kernel" intel_cvs >/dev/null 2>&1 || \
	die "intel_cvs is unavailable for running kernel $kernel; reboot into the latest generic kernel and rerun"

dracut --force "/boot/initrd.img-$kernel" "$kernel"

echo "System camera drivers, suspend handling, and configuration installed for $kernel."
