#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ $EUID -eq 0 ]]; then
	echo "Run this installer as your desktop user, not as root." >&2
	exit 1
fi

if ! command -v pkexec >/dev/null 2>&1; then
	echo "pkexec is required to install packages and system configuration." >&2
	exit 1
fi

pkexec "$repo_dir/scripts/install-system.sh"
pkexec "$repo_dir/scripts/install-build-deps.sh"
"$repo_dir/scripts/build-libcamera.sh"
pkexec "$repo_dir/scripts/install-libcamera.sh" "$repo_dir/build"
"$repo_dir/scripts/configure-user.sh"

cat <<'EOF'

Installation completed. Reboot before testing the camera.

Chrome/Chromium users must also enable:
  chrome://flags/#enable-webrtc-pipewire-camera
EOF
