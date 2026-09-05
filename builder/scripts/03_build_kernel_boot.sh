#!/bin/bash
# 03_build_kernel_boot.sh - Prepare boot.bin, partition tables, and firmware blobs
set -e

BUILD_DIR="$1"
IS_MODEM_DISABLED="${2:-0}"
SCRIPT_ROOT="${3:-$(dirname "$(dirname "$0")")}"
VARIANT="${4:-bookworm}"

if [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <build_dir> [is_modem_disabled] [script_root] [variant]"
    exit 1
fi

CACHE_DIR="${SCRIPT_ROOT}/.cache"
mkdir -p "${BUILD_DIR}/partitions" "${CACHE_DIR}"

echo "--> [3/4] Menyiapkan partisi firmware & bootloader dasar..."

PARTITIONS=(aboot.mbn boot.bin gpt_both0.bin hyp.mbn rpm.mbn sbl1.mbn tz.mbn)

# Cari sumber file partisi
find_file() {
    local fname="$1"
    local candidates=(
        "${SCRIPT_ROOT}/../${VARIANT}/${fname}"
        "${SCRIPT_ROOT}/../bookworm/${fname}"
        "${SCRIPT_ROOT}/../base-generic/${fname}"
        "${CACHE_DIR}/${fname}"
    )

    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then
            echo "$c"
            return 0
        fi
    done

    # Cek di dalam zip lokal
    for z in "${SCRIPT_ROOT}/../${VARIANT}.zip" "${SCRIPT_ROOT}/../bookworm.zip" "${SCRIPT_ROOT}/../base-generic.zip" "${CACHE_DIR}/bookworm.zip"; do
        if [ -f "$z" ]; then
            if unzip -l "$z" "$fname" >/dev/null 2>&1; then
                unzip -q -o "$z" "$fname" -d "${CACHE_DIR}/"
                echo "${CACHE_DIR}/${fname}"
                return 0
            fi
        fi
    done

    # Unduh dari GitHub release jika belum ada
    echo "--> [3/4] Mengunduh komponen firmware (${fname}) dari GitHub Releases..." >&2
    if curl -fsSL -o "${CACHE_DIR}/bookworm.zip" "https://github.com/jimmylpx/openstick/releases/download/v1/bookworm.zip"; then
        unzip -q -o "${CACHE_DIR}/bookworm.zip" "$fname" -d "${CACHE_DIR}/" 2>/dev/null || true
        if [ -f "${CACHE_DIR}/${fname}" ]; then
            echo "${CACHE_DIR}/${fname}"
            return 0
        fi
    fi

    return 1
}

for part in "${PARTITIONS[@]}"; do
    # Khusus boot.bin pada varian modem-disabled
    if [ "$part" = "boot.bin" ] && [ "$IS_MODEM_DISABLED" -eq 1 ]; then
        SRC=""
        if [ -f "${SCRIPT_ROOT}/../bookworm-modem-disabled/boot.bin" ]; then
            SRC="${SCRIPT_ROOT}/../bookworm-modem-disabled/boot.bin"
        elif [ -f "${SCRIPT_ROOT}/../trixie-modem-disabled/boot.bin" ]; then
            SRC="${SCRIPT_ROOT}/../trixie-modem-disabled/boot.bin"
        else
            # Coba cari di zip modem-disabled lokal atau unduh
            for z in "${SCRIPT_ROOT}/../bookworm-modem-disabled.zip" "${CACHE_DIR}/bookworm-modem-disabled.zip"; do
                if [ -f "$z" ]; then
                    unzip -q -o "$z" "boot.bin" -d "${CACHE_DIR}/boot_md/"
                    SRC="${CACHE_DIR}/boot_md/boot.bin"
                    break
                fi
            done
            if [ -z "$SRC" ]; then
                curl -fsSL -o "${CACHE_DIR}/bookworm-modem-disabled.zip" "https://github.com/jimmylpx/openstick/releases/download/v1/bookworm-modem-disabled.zip" 2>/dev/null || true
                if [ -f "${CACHE_DIR}/bookworm-modem-disabled.zip" ]; then
                    unzip -q -o "${CACHE_DIR}/bookworm-modem-disabled.zip" "boot.bin" -d "${CACHE_DIR}/boot_md/" 2>/dev/null || true
                    SRC="${CACHE_DIR}/boot_md/boot.bin"
                fi
            fi
        fi

        if [ -n "$SRC" ] && [ -f "$SRC" ]; then
            echo "    [Modem-Disabled] Memasang boot.bin dari: ${SRC}"
            cp -a "$SRC" "${BUILD_DIR}/partitions/boot.bin"
            continue
        fi
    fi

    FILE_PATH=$(find_file "$part" || echo "")
    if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
        cp -a "$FILE_PATH" "${BUILD_DIR}/partitions/${part}"
    else
        echo "[!] Peringatan: Partisi ${part} tidak ditemukan!"
    fi
done

echo "--> [3/4] Partisi firmware dasar siap di: ${BUILD_DIR}/partitions"
