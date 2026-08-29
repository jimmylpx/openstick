#!/bin/bash
# 03_build_kernel_boot.sh - Prepare boot.bin, partition tables, and firmware blobs
set -e

BUILD_DIR="$1"
FIRMWARE_SOURCE="$2"

if [ -z "$BUILD_DIR" ] || [ -z "$FIRMWARE_SOURCE" ]; then
    echo "Usage: $0 <build_dir> <firmware_source_dir>"
    exit 1
fi

echo "--> [3/4] Menyiapkan partisi firmware & bootloader dasar..."
mkdir -p "${BUILD_DIR}/partitions"

for part in aboot.mbn boot.bin gpt_both0.bin hyp.mbn rpm.mbn sbl1.mbn tz.mbn; do
    if [ -f "${FIRMWARE_SOURCE}/${part}" ]; then
        cp -v "${FIRMWARE_SOURCE}/${part}" "${BUILD_DIR}/partitions/"
    else
        echo "[!] Peringatan: ${part} tidak ditemukan di ${FIRMWARE_SOURCE}."
    fi
done

echo "--> [3/4] Partisi firmware dasar siap!"
