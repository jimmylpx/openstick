#!/bin/bash
# 01_bootstrap_rootfs.sh - Generate Debian RootFS via debootstrap & QEMU
set -e

DISTRO="$1"
TARGET_ROOTFS="$2"

if [ -z "$DISTRO" ] || [ -z "$TARGET_ROOTFS" ]; then
    echo "Usage: $0 <bookworm|trixie> <target_rootfs_dir>"
    exit 1
fi

echo "--> [1/4] Bootstrapping Debian ${DISTRO} (ARM64)..."
rm -rf "${TARGET_ROOTFS}"
mkdir -p "${TARGET_ROOTFS}"

debootstrap --arch=arm64 --foreign "${DISTRO}" "${TARGET_ROOTFS}" http://deb.debian.org/debian/

echo "--> [1/4] Second stage debootstrap via QEMU aarch64..."
cp /usr/bin/qemu-aarch64-static "${TARGET_ROOTFS}/usr/bin/"
chroot "${TARGET_ROOTFS}" /debootstrap/debootstrap --second-stage

echo "--> [1/4] Base bootstrap selesai!"
