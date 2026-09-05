#!/bin/bash
# 03_build_kernel_boot.sh - Prepare boot.bin, partition tables, and firmware blobs strictly from firmware/
set -e

BUILD_DIR="$1"
IS_MODEM_DISABLED="${2:-0}"
SCRIPT_ROOT="${3:-$(dirname "$(dirname "$0")")}"
VARIANT="${4:-bookworm}"

if [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <build_dir> [is_modem_disabled] [script_root] [variant]"
    exit 1
fi

FW_DIR="${SCRIPT_ROOT}/firmware"
mkdir -p "${BUILD_DIR}/partitions" "${FW_DIR}"

echo "--> [3/4] Menyiapkan partisi firmware & bootloader dasar..."

PARTITIONS=(aboot.mbn boot.bin gpt_both0.bin hyp.mbn rpm.mbn sbl1.mbn tz.mbn)

# Salin partisi bootloader standar dari folder firmware lokal
for part in "${PARTITIONS[@]}"; do
    # Khusus boot.bin untuk varian modem-disabled
    if [ "$part" = "boot.bin" ] && [ "$IS_MODEM_DISABLED" -eq 1 ]; then
        if [ -f "${FW_DIR}/boot_modem_disabled.bin" ]; then
            echo "    [Modem-Disabled] Memasang boot.bin dari: firmware/boot_modem_disabled.bin"
            cp -a "${FW_DIR}/boot_modem_disabled.bin" "${BUILD_DIR}/partitions/boot.bin"
            continue
        fi
    fi

    # Khusus boot.bin untuk varian standar
    if [ "$part" = "boot.bin" ]; then
        if [ -f "${FW_DIR}/boot_standard.bin" ]; then
            echo "    [Standar] Memasang boot.bin dari: firmware/boot_standard.bin"
            cp -a "${FW_DIR}/boot_standard.bin" "${BUILD_DIR}/partitions/boot.bin"
            continue
        fi
    fi

    if [ -f "${FW_DIR}/${part}" ]; then
        cp -a "${FW_DIR}/${part}" "${BUILD_DIR}/partitions/${part}"
    else
        echo "[!] Peringatan: Partisi ${part} tidak ditemukan di ${FW_DIR}!"
    fi
done

echo "--> [3/4] Partisi firmware dasar siap di: ${BUILD_DIR}/partitions"
