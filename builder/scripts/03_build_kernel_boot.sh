#!/bin/bash
# 03_build_kernel_boot.sh - Prepare bootloader and kernel boot.bin
set -e

BUILD_DIR="$1"
IS_MODEM_DISABLED="$2"
SCRIPT_ROOT="$3"
VARIANT="$4"

if [ -z "$BUILD_DIR" ] || [ -z "$SCRIPT_ROOT" ]; then
    echo "Usage: $0 BUILD_DIR IS_MODEM_DISABLED SCRIPT_ROOT VARIANT"
    exit 1
fi

PARTITIONS_DIR="${BUILD_DIR}/partitions"
FIRMWARE_DIR="${SCRIPT_ROOT}/firmware"

mkdir -p "${PARTITIONS_DIR}"

echo "--> [3/4] Menyalin partisi bootloader Qualcomm Snapdragon 410..."
for p in aboot.mbn gpt_both0.bin hyp.mbn rpm.mbn sbl1.mbn tz.mbn; do
    if [ -f "${FIRMWARE_DIR}/${p}" ]; then
        cp -v "${FIRMWARE_DIR}/${p}" "${PARTITIONS_DIR}/${p}"
    else
        echo "[!] Error: File partisi ${p} tidak ditemukan di ${FIRMWARE_DIR}!"
        exit 1
    fi
done

echo "--> [3/4] Menyiapkan partisi kernel boot.bin..."
if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
    echo "    Menggunakan boot_modem_disabled.bin (Device Tree High-RAM ~512MB)..."
    cp -v "${FIRMWARE_DIR}/boot_modem_disabled.bin" "${PARTITIONS_DIR}/boot.bin"
else
    echo "    Menggunakan boot.bin (Kernel Standar 4G Modem Aktif)..."
    cp -v "${FIRMWARE_DIR}/boot.bin" "${PARTITIONS_DIR}/boot.bin"
fi

echo "--> [3/4] Seluruh partisi bootloader & kernel berhasil disiapkan di ${PARTITIONS_DIR}."
