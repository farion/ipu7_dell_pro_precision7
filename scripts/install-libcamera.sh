#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "error: run this script as root" >&2
	exit 1
fi

build_dir=${1:-}
[[ -n $build_dir && -f $build_dir/VERSION ]] || {
	echo "usage: $0 BUILD_DIRECTORY" >&2
	exit 1
}

version=$(< "$build_dir/VERSION")
arch=$(dpkg --print-architecture)
packages=(
	libcamera0.7
	libcamera-ipa
	libcamera-tools
	libcamera-v4l2
	gstreamer1.0-libcamera
)
debs=()

for package in "${packages[@]}"; do
	deb="$build_dir/${package}_${version}_${arch}.deb"
	[[ -f $deb ]] || {
		echo "error: expected package not found: $deb" >&2
		exit 1
	}
	debs+=("$deb")
done

apt-get install -y "${debs[@]}"
apt-mark hold "${packages[@]}"

echo "Installed and held libcamera $version."
