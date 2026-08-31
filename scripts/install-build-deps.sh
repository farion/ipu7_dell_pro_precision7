#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "error: run this script as root" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
	build-essential \
	ca-certificates \
	curl \
	debhelper \
	dh-python \
	dpkg-dev \
	fakeroot \
	libdrm-dev \
	libdw-dev \
	libevent-dev \
	libgnutls28-dev \
	libgstreamer-plugins-base1.0-dev \
	libgstreamer1.0-dev \
	libgtest-dev \
	libjpeg-dev \
	liblttng-ust-dev \
	libpython3-dev \
	libsdl2-dev \
	libtiff-dev \
	libudev-dev \
	libyaml-dev \
	libyuv-dev \
	meson \
	openssl \
	patch \
	pkgconf \
	python3-jinja2 \
	python3-ply \
	python3-pybind11 \
	python3-yaml \
	qt6-base-dev
