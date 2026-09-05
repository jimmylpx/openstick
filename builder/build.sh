#!/bin/bash
# ==============================================================================
# OpenStick (Snapdragon 410 / MSM8916) Master Build System
# GitHub: https://github.com/jimmylpx/openstick
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="bookworm-modem-disabled"

# Parsing argumen
while [[ $# -gt 0 ]]; do
    case $1 in
        --target|-t|--distro|-d)
            TARGET="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: sudo $0 [--target <target>]"
            echo ""
            echo "Target yang tersedia:"
            echo "  - bookworm                (Debian 12 Bookworm Standar - 4G Modem Aktif)"
            echo "  - bookworm-modem-disabled (Debian 12 Bookworm Modem-Disabled - Max RAM)"
            echo "  - trixie                  (Debian 13 Trixie Standar - 4G Modem Aktif)"
            echo "  - trixie-modem-disabled   (Debian 13 Trixie Modem-Disabled - Max RAM)"
            echo "  - all                     (Build seluruh 4 varian sekaligus)"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Gunakan: sudo $0 --help untuk melihat bantuan."
            exit 1
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

# 1. Pengecekan dan instalasi otomatis dependensi host
check_host_dependencies() {
    echo "--> [Host Check] Memeriksa dependensi sistem host..."
    local missing_pkgs=()

    if ! command -v zip >/dev/null 2>&1; then
        missing_pkgs+=("zip")
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        missing_pkgs+=("unzip")
    fi
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_pkgs+=("curl")
    fi
    if ! command -v tune2fs >/dev/null 2>&1 && ! [ -x /sbin/tune2fs ]; then
        missing_pkgs+=("e2fsprogs")
    fi

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo "[!] Dependensi host berikut belum terpasang: ${missing_pkgs[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            echo "--> Menginstal dependensi otomatis via apt-get..."
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y --no-install-recommends "${missing_pkgs[@]}"
            echo "--> Dependensi host berhasil dipasang."
        else
            echo "[!] Peringatan: apt-get tidak ditemukan. Harap pasang manual: ${missing_pkgs[*]}"
        fi
    else
        echo "--> [Host Check] Seluruh dependensi host terpenuhi."
    fi
}

check_host_dependencies

build_variant() {
    local VARIANT="$1"
    local BASE_DISTRO=""
    local IS_MODEM_DISABLED="0"

    case "$VARIANT" in
        bookworm)
            BASE_DISTRO="bookworm"
            IS_MODEM_DISABLED="0"
            ;;
        bookworm-modem-disabled)
            BASE_DISTRO="bookworm"
            IS_MODEM_DISABLED="1"
            ;;
        trixie)
            BASE_DISTRO="trixie"
            IS_MODEM_DISABLED="0"
            ;;
        trixie-modem-disabled)
            BASE_DISTRO="trixie"
            IS_MODEM_DISABLED="1"
            ;;
        *)
            echo "[!] Error: Varian tidak dikenal: $VARIANT"
            echo "Pilihan valid: bookworm, bookworm-modem-disabled, trixie, trixie-modem-disabled, all"
            exit 1
            ;;
    esac

    echo ""
    echo "=========================================================="
    echo "    OPENSTICK BUILD SYSTEM (MSM8916)                      "
    echo "=========================================================="
    echo "Varian Target : ${VARIANT}"
    echo "Base Distro   : ${BASE_DISTRO^^}"
    echo "Modem Status  : $([ "$IS_MODEM_DISABLED" -eq 1 ] && echo "DISABLED" || echo "ENABLED")"
    echo "Direktori     : ${SCRIPT_DIR}"
    echo "=========================================================="
    echo ""

    local BUILD_DIR="${SCRIPT_DIR}/build_${VARIANT}"
    local OUTPUT_DIR="${SCRIPT_DIR}/output"

    # Bersihkan sisa mountpoint jika ada
    umount -l "${BUILD_DIR}/mnt_rootfs" 2>/dev/null || true

    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

    cleanup() {
        umount -l "${BUILD_DIR}/mnt_rootfs" 2>/dev/null || true
    }
    trap cleanup EXIT

    # 1. Siapkan Base RootFS (Verified Image)
    echo ">>> [1/4] Menyiapkan Base RootFS (${BASE_DISTRO})..."
    bash "${SCRIPT_DIR}/scripts/01_prepare_base.sh" "${VARIANT}" "${BUILD_DIR}" "${SCRIPT_DIR}"

    # 2. Terapkan Overlay, Services, & User Config secara in-place
    echo ">>> [2/4] Menerapkan OpenStick Overlay, Services, & User Config..."
    bash "${SCRIPT_DIR}/scripts/02_apply_overlay.sh" "${BUILD_DIR}/mnt_rootfs" "${SCRIPT_DIR}/overlay" "${BASE_DISTRO}" "${IS_MODEM_DISABLED}" "${BUILD_DIR}" "${VARIANT}"

    # 3. Siapkan Partisi Bootloader & Boot.bin
    echo ">>> [3/4] Menyiapkan partisi Boot.bin & Firmware Snapdragon 410..."
    bash "${SCRIPT_DIR}/scripts/03_build_kernel_boot.sh" "${BUILD_DIR}" "${IS_MODEM_DISABLED}" "${SCRIPT_DIR}" "${VARIANT}"

    # 4. Verifikasi dan kemas zip rilis siap flash
    echo ">>> [4/4] Mengemas paket rilis siap flash (${VARIANT}.zip)..."
    bash "${SCRIPT_DIR}/scripts/04_pack_release.sh" "${VARIANT}" "${BUILD_DIR}" "${OUTPUT_DIR}"

    trap - EXIT
    cleanup

    echo ""
    echo "=========================================================="
    echo " [OK] BUILD SUKSES! File rilis tersimpan di:"
    echo "      ${OUTPUT_DIR}/${VARIANT}.zip"
    echo "=========================================================="
}

if [ "$TARGET" = "all" ]; then
    echo ">>> MEMULAI BUILD SELURUH 4 VARIAN OPENSTICK..."
    for v in bookworm bookworm-modem-disabled trixie trixie-modem-disabled; do
        build_variant "$v"
    done
    echo ""
    echo ">>> [SELURUH 4 VARIAN BERHASIL DIBUILD]"
else
    build_variant "$TARGET"
fi
