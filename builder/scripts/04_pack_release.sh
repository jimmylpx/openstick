#!/bin/bash
# 04_pack_release.sh - Verify partitions and package flashable release zip
set -e

VARIANT="$1"
BUILD_DIR="$2"
OUTPUT_DIR="$3"

if [ -z "$VARIANT" ] || [ -z "$BUILD_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 VARIANT BUILD_DIR OUTPUT_DIR"
    exit 1
fi

PARTITIONS_DIR="${BUILD_DIR}/partitions"
mkdir -p "${OUTPUT_DIR}"
ZIP_OUT="${OUTPUT_DIR}/${VARIANT}.zip"
rm -f "${ZIP_OUT}"

echo "--> [4/4] Memeriksa kelengkapan 8 file partisi wajib OpenStick..."
REQUIRED_PARTS=(aboot.mbn boot.bin gpt_both0.bin hyp.mbn rootfs.bin rpm.mbn sbl1.mbn tz.mbn)
for part in "${REQUIRED_PARTS[@]}"; do
    if [ ! -f "${PARTITIONS_DIR}/${part}" ]; then
        echo "[!] Error: Partisi wajib ${part} tidak ditemukan di ${PARTITIONS_DIR}!"
        exit 1
    fi
    echo "    [OK] ${part} ($(stat -c%s "${PARTITIONS_DIR}/${part}") bytes)"
done

echo "--> [4/4] Mengompres seluruh partisi ke dalam rilis siap flash: ${ZIP_OUT}..."
(cd "${PARTITIONS_DIR}" && zip -r -9 "${ZIP_OUT}" ./*)

echo "--> [4/4] Paket rilis berhasil dibuat:"
ls -lh "${ZIP_OUT}"
md5sum "${ZIP_OUT}"
