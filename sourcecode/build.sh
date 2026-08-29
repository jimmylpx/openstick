#!/bin/bash
# ==============================================================================
# OpenStick (Snapdragon 410 / MSM8916) Master Build System
# GitHub: https://github.com/jimmylpx/openstick
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRO="bookworm"

# Parsing argumen
while [[ $# -gt 0 ]]; do
    case $1 in
        --distro|-d)
            DISTRO="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: sudo $0 [--distro bookworm|trixie]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

echo "=========================================================="
echo "    OPENSTICK SOURCE CODE BUILD SYSTEM (MSM8916)          "
echo "=========================================================="
echo "Distro Target : ${DISTRO^^}"
echo "Direktori     : ${SCRIPT_DIR}"
echo "=========================================================="
echo ""

BUILD_DIR="${SCRIPT_DIR}/build_${DISTRO}"
OUTPUT_DIR="${SCRIPT_DIR}/output"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

# 1. Bootstrap RootFS
echo ">>> [1/4] Membuat Base RootFS (${DISTRO})..."
bash "${SCRIPT_DIR}/scripts/01_bootstrap_rootfs.sh" "${DISTRO}" "${BUILD_DIR}/rootfs"

# 2. Apply Custom Overlay & Services
echo ">>> [2/4] Menerapkan OpenStick Overlay, Services, & User Config..."
bash "${SCRIPT_DIR}/scripts/02_apply_overlay.sh" "${BUILD_DIR}/rootfs" "${SCRIPT_DIR}/overlay"

# 3. Build Kernel Boot Image
echo ">>> [3/4] Menyiapkan partisi Boot.bin & Firmware..."
bash "${SCRIPT_DIR}/scripts/03_build_kernel_boot.sh" "${BUILD_DIR}" "${SCRIPT_DIR}/../bookworm"

# 4. Pack Release Zip
echo ">>> [4/4] Mengemas paket rilis siap flash (${DISTRO}.zip)..."
bash "${SCRIPT_DIR}/scripts/04_pack_release.sh" "${DISTRO}" "${BUILD_DIR}" "${OUTPUT_DIR}"

echo ""
echo "=========================================================="
echo " [OK] BUILD SUKSES! File rilis tersimpan di:"
echo "      ${OUTPUT_DIR}/${DISTRO}.zip"
echo "=========================================================="
