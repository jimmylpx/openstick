#!/bin/bash
# 01_prepare_base.sh - Prepare verified base rootfs
set -e

VARIANT="$1"
BUILD_DIR="$2"
SCRIPT_ROOT="$3"

if [ -z "$VARIANT" ] || [ -z "$BUILD_DIR" ] || [ -z "$SCRIPT_ROOT" ]; then
    echo "Usage: $0 VARIANT BUILD_DIR SCRIPT_ROOT"
    exit 1
fi

BASE_DIR="${SCRIPT_ROOT}/base"
BASE_IMG="${BASE_DIR}/rootfs.bin"
PARTITIONS_DIR="${BUILD_DIR}/partitions"
MNT_DIR="${BUILD_DIR}/mnt_rootfs"

mkdir -p "${PARTITIONS_DIR}" "${MNT_DIR}"

# 1. Pastikan base rootfs terverifikasi tersedia di builder/base/
if [ ! -f "${BASE_IMG}" ]; then
    echo "--> [1/4] Base rootfs tidak ditemukan di ${BASE_IMG}."
    echo "--> [1/4] Mengunduh base rootfs terverifikasi OpenStick ke builder/base/..."
    mkdir -p "${BASE_DIR}"
    curl -fSL --progress-bar -o "${BASE_DIR}/base_download.zip" "https://github.com/jimmylpx/openstick/releases/download/v1/bookworm.zip"
    echo "--> [1/4] Mengekstrak rootfs.bin ke builder/base/..."
    unzip -p "${BASE_DIR}/base_download.zip" rootfs.bin > "${BASE_IMG}"
    rm -f "${BASE_DIR}/base_download.zip"
    echo "--> [1/4] Base rootfs berhasil disiapkan di ${BASE_IMG}."
fi

# 2. Salin base rootfs ke direktori build partisi
echo "--> [1/4] Menyiapkan rootfs.bin untuk varian ${VARIANT}..."
cp -v "${BASE_IMG}" "${PARTITIONS_DIR}/rootfs.bin"

# 3. Mount rootfs secara loopback untuk di-patch in-place
echo "--> [1/4] Melakukan mount loopback rootfs.bin..."
umount -l "${MNT_DIR}" 2>/dev/null || true
mount -o loop "${PARTITIONS_DIR}/rootfs.bin" "${MNT_DIR}"

echo "--> [1/4] Base rootfs siap dipatch di ${MNT_DIR}."
