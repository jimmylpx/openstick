#!/bin/bash
# 03_build_kernel_boot.sh - Prepare boot.bin, partition tables, and firmware blobs
set -e

BUILD_DIR="$1"
IS_MODEM_DISABLED="${2:-0}"
SCRIPT_ROOT="${3:-$(dirname "$(dirname "$0")")}"

if [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <build_dir> [is_modem_disabled] [script_root]"
    exit 1
fi

echo "--> [3/4] Menyiapkan partisi firmware & bootloader dasar..."
mkdir -p "${BUILD_DIR}/partitions"

# Pilih sumber template partisi
SRC_DIR="${SCRIPT_ROOT}/../bookworm"
if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
    SRC_DIR="${SCRIPT_ROOT}/../bookworm-modem-disabled"
fi

# Jika folder lokal di atas tidak ada, fallback ke base-generic/work
if [ ! -f "${SRC_DIR}/boot.bin" ]; then
    if [ -f "${SCRIPT_ROOT}/../base-generic/boot.bin" ]; then
        SRC_DIR="${SCRIPT_ROOT}/../base-generic"
    elif [ -f "${SCRIPT_ROOT}/../work/base_build/boot.bin" ]; then
        SRC_DIR="${SCRIPT_ROOT}/../work/base_build"
    fi
fi

echo "    Mengambil template biner dari: ${SRC_DIR}"
for part in aboot.mbn boot.bin gpt_both0.bin hyp.mbn rpm.mbn sbl1.mbn tz.mbn; do
    if [ -f "${SRC_DIR}/${part}" ]; then
        cp -v "${SRC_DIR}/${part}" "${BUILD_DIR}/partitions/"
    else
        echo "[!] Peringatan: ${part} tidak ditemukan di ${SRC_DIR}."
    fi
done

echo "--> [3/4] Partisi firmware dasar siap!"
