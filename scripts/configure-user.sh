#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -eq 0 ]]; then
	echo "error: run this script as the desktop user, not as root" >&2
	exit 1
fi

install -Dm0644 \
	"$repo_dir/config/systemd/user/pipewire.service.d/override.conf" \
	"$HOME/.config/systemd/user/pipewire.service.d/override.conf"
install -Dm0644 \
	"$repo_dir/config/systemd/user/wireplumber.service.d/override.conf" \
	"$HOME/.config/systemd/user/wireplumber.service.d/override.conf"

systemctl --user daemon-reload
systemctl --user restart pipewire.service

echo "Configured PipeWire and WirePlumber to use libcamera's CPU ISP."
