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
install -Dm0755 "$repo_dir/scripts/ipu7-camera-colour" \
	"$HOME/.local/bin/ipu7-camera-colour"
install -Dm0644 "$repo_dir/config/systemd/user/ipu7-camera-colour.service" \
	"$HOME/.config/systemd/user/ipu7-camera-colour.service"

teams_config="$HOME/.config/teams-for-linux/config.json"
teams_template="$repo_dir/config/teams-for-linux/config.json"
if [[ -f $teams_config ]]; then
	temporary_config=$(mktemp)
	trap 'rm -f "$temporary_config"' EXIT
	jq -s '.[0] as $existing | .[1] as $required | $existing * $required | .electronCLIFlags = (($existing.electronCLIFlags // []) + ($required.electronCLIFlags // []) | unique)' \
		"$teams_config" "$teams_template" > "$temporary_config"
	install -Dm0644 "$temporary_config" "$teams_config"
	trap - EXIT
	rm -f "$temporary_config"
else
	install -Dm0644 "$teams_template" "$teams_config"
fi

systemctl --user daemon-reload
systemctl --user enable ipu7-camera-colour.service
systemctl --user restart pipewire.service
systemctl --user restart ipu7-camera-colour.service

echo "Configured PipeWire, Teams for Linux, and OV08X40 colour correction."
