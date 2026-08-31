#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_dir=${BUILD_DIR:-"$repo_dir/build"}
source_version=0.7.0-1ubuntu2
source_name=libcamera_0.7.0
archive_base=https://archive.ubuntu.com/ubuntu/pool/main/libc/libcamera

if [[ $EUID -eq 0 ]]; then
	echo "error: build libcamera as an unprivileged user" >&2
	exit 1
fi

for command in curl dpkg-buildpackage dpkg-source patch sha256sum; do
	command -v "$command" >/dev/null 2>&1 || {
		echo "error: missing command $command; run scripts/install-build-deps.sh" >&2
		exit 1
	}
done

if [[ -e $build_dir/source || -e $build_dir/VERSION ]]; then
	echo "error: $build_dir already contains a build; remove it before rebuilding" >&2
	exit 1
fi

mkdir -p "$build_dir/downloads"

download()
{
	local file=$1
	curl --fail --location --retry 3 \
		--output "$build_dir/downloads/$file" "$archive_base/$file"
}

download "${source_name}.orig.tar.gz"
download "${source_name}-${source_version#0.7.0-}.debian.tar.xz"
download "libcamera_${source_version}.dsc"

echo "ebd90a3aa2ca87a39323ffb7a4f5bbf72090b43a2431133759620b63e982db87  $build_dir/downloads/${source_name}.orig.tar.gz" | sha256sum --check
echo "0ee3195d74ad85b089c62eb7b2904023f8556544b2d9dbcc67aa834ddde5a09e  $build_dir/downloads/${source_name}-${source_version#0.7.0-}.debian.tar.xz" | sha256sum --check

dpkg-source -x "$build_dir/downloads/libcamera_${source_version}.dsc" \
	"$build_dir/source"
patch --directory="$build_dir/source" --strip=1 --forward --batch \
	< "$repo_dir/patches/libcamera/0001-simple-prefer-largest-ov08x40-mode.patch"

base_version=$(dpkg-parsechangelog -l"$build_dir/source/debian/changelog" -SVersion)
[[ $base_version == "$source_version" ]] || {
	echo "error: expected source version $source_version, got $base_version" >&2
	exit 1
}

local_version="${base_version}+ipu7dell1"
changelog="$build_dir/source/debian/changelog"
{
	printf 'libcamera (%s) resolute; urgency=medium\n\n' "$local_version"
	printf '  * Prefer the working full-resolution OV08X40 mode on IPU7 Panther Lake.\n\n'
	printf ' -- IPU7 Dell Pro Precision 7 contributors <noreply@example.invalid>  %s\n\n' \
		"$(date -R)"
	cat "$changelog"
} > "$changelog.new"
mv "$changelog.new" "$changelog"

(
	cd "$build_dir/source"
	DEB_BUILD_PROFILES=nodoc DEB_BUILD_OPTIONS="nocheck nodoc" \
		dpkg-buildpackage -b -uc -us
)

printf '%s\n' "$local_version" > "$build_dir/VERSION"
echo "Built libcamera $local_version in $build_dir"
