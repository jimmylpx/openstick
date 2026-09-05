#!/bin/bash
# ==============================================================================
# OpenStick (Snapdragon 410 / MSM8916) Master Build System
# GitHub: https://github.com/jimmylpx/openstick
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="bookworm"

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
    mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

    # 1. Bootstrap RootFS
    echo ">>> [1/4] Membuat Base RootFS (${BASE_DISTRO})..."
    bash "${SCRIPT_DIR}/scripts/01_bootstrap_rootfs.sh" "${BASE_DISTRO}" "${BUILD_DIR}/rootfs"

    # 2. Apply Custom Overlay, Services, Modem Masking & User Config
    echo ">>> [2/4] Menerapkan OpenStick Overlay, Services, & User Config..."
    bash "${SCRIPT_DIR}/scripts/02_apply_overlay.sh" "${BUILD_DIR}/rootfs" "${SCRIPT_DIR}/overlay" "${BASE_DISTRO}" "${IS_MODEM_DISABLED}"

    # 3. Prepare Boot Image & Firmware Partitions
    echo ">>> [3/4] Menyiapkan partisi Boot.bin & Firmware dasar..."
    bash "${SCRIPT_DIR}/scripts/03_build_kernel_boot.sh" "${BUILD_DIR}" "${IS_MODEM_DISABLED}" "${SCRIPT_DIR}"

    # 4. Pack Release Zip
    echo ">>> [4/4] Mengemas paket rilis siap flash (${VARIANT}.zip)..."
    bash "${SCRIPT_DIR}/scripts/04_pack_release.sh" "${VARIANT}" "${BUILD_DIR}" "${OUTPUT_DIR}"

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
