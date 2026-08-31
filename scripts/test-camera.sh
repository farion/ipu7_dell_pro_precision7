#!/usr/bin/env bash
set -euo pipefail

for command in gst-launch-1.0 wpctl; do
	command -v "$command" >/dev/null 2>&1 || {
		echo "error: missing command $command" >&2
		exit 1
	}
done

if ! wpctl status 2>/dev/null | grep -q ov08x40; then
	echo "error: the OV08X40 PipeWire source is unavailable" >&2
	exit 1
fi

output_dir="/tmp/ipu7-camera-test-$$"
mkdir -p "$output_dir"

gst-launch-1.0 -e \
	pipewiresrc target-object=libcamera_input.__SB_.LNK1 num-buffers=12 \
	! 'video/x-raw,format=BGRx,width=1280,height=720' \
	! videoconvert \
	! pngenc \
	! multifilesink location="$output_dir/frame-%02d.png"

last_frame="$output_dir/frame-11.png"
[[ -s $last_frame ]] || {
	echo "error: expected output frame was not created" >&2
	exit 1
}

sleep 1
runtime_file=/sys/bus/i2c/devices/i2c-OVTI08F4:00/power/runtime_status
runtime=unknown
[[ -r $runtime_file ]] && runtime=$(< "$runtime_file")

echo "Capture succeeded: $last_frame"
echo "Sensor state after capture: $runtime"
