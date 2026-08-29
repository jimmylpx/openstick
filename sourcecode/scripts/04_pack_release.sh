#!/bin/bash
# 04_pack_release.sh - Build rootfs.bin image and package flashable release zip
set -e

DISTRO="$1"
BUILD_DIR="$2"
OUTPUT_DIR="$3"

if [ -z "$DISTRO" ] || [ -z "$BUILD_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <distro> <build_dir> <output_dir>"
    exit 1
fi

ROOTFS_IMG="${BUILD_DIR}/partitions/rootfs.bin"
MNT_DIR="${BUILD_DIR}/mnt_img"

echo "--> [4/4] Membuat rootfs.bin image (698MB ext4)..."
rm -f "${ROOTFS_IMG}"
dd if=/dev/zero of="${ROOTFS_IMG}" bs=1M count=698 status=none
mkfs.ext4 -F -L "rootfs" "${ROOTFS_IMG}"

mkdir -p "${MNT_DIR}"
mount -o loop "${ROOTFS_IMG}" "${MNT_DIR}"
cp -a "${BUILD_DIR}/rootfs/." "${MNT_DIR}/"
sync
umount "${MNT_DIR}"
e2fsck -fy "${ROOTFS_IMG}"

echo "--> [4/4] Mengemas file ${DISTRO}.zip..."
mkdir -p "${OUTPUT_DIR}"
ZIP_OUT="${OUTPUT_DIR}/${DISTRO}.zip"
rm -f "${ZIP_OUT}"

(cd "${BUILD_DIR}/partitions" && zip -r "${ZIP_OUT}" ./*)

echo "--> [4/4] Selesai: ${ZIP_OUT}"
