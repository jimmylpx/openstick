#!/bin/bash
# ==============================================================================
# OpenStick Complete Flasher & Modem Installer
# Target: Qualcomm MSM8916 (Snapdragon 410)
# ==============================================================================
set -e

# Tentukan BASE_DIR secara dinamis berdasarkan lokasi script ini berada
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBIAN_DIR="$BASE_DIR/debian"
OSBUILD_DIR="$BASE_DIR/osbuild"
STOCK_EXTRACT_DIR="$BASE_DIR/stock_extracted"
HM_BIN="$BASE_DIR/HM.bin"

echo "================================================================="
echo "        OPENSTICK AUTOMATED INSTALLER & MODEM RESTORER           "
echo "================================================================="
echo "[*] Direktori Kerja (BASE_DIR): $BASE_DIR"

# --- 1. EDL Backup & Reset ---
echo ""
echo "[Step 1] Memeriksa mode EDL dan melakukan full dump firmware asli..."
if [ ! -f "$HM_BIN" ]; then
    echo "[*] Menjalankan: edl rf $HM_BIN"
    edl rf "$HM_BIN"
    echo "[✓] Full dump HM.bin berhasil!"
else
    echo "[✓] File $HM_BIN sudah ada, melanjutkan..."
fi

echo "[*] Menjalankan: edl reset"
edl reset || echo "[!] Lanjut menunggu device..."

# Ekstraksi partisi baseband dari HM.bin
echo "[*] Mengekstrak partisi baseband dari HM.bin ke stock_extracted..."
python3 "$BASE_DIR/extract_hm_partitions.py" "$HM_BIN" "$STOCK_EXTRACT_DIR"

# --- 2. ADB Root & Masuk ke Bootloader ---
echo ""
echo "[Step 2] Menunggu perangkat booting ke mode normal (ADB)..."
adb wait-for-device
echo "[*] Mengaktifkan root pada ADB..."
adb shell "setprop service.adb.root 1; busybox killall adbd" || true
sleep 3
adb wait-for-device
echo "[*] Reboot ke bootloader (Fastboot)..."
adb reboot bootloader || true
sleep 5

# --- 3. Menjalankan Base flash.sh ---
echo ""
echo "[Step 3] Menjalankan base flash.sh..."
cd "$BASE_DIR"
bash flash.sh

# --- 4. Menjalankan debian/flash.sh (Download on-demand jika belum ada) ---
echo ""
echo "[Step 4] Memeriksa file base Debian..."
mkdir -p "$DEBIAN_DIR"
if [ ! -f "$DEBIAN_DIR/rootfs.img" ] || [ ! -f "$DEBIAN_DIR/boot.img" ]; then
    echo "[*] Mengunduh debian.zip dari OpenStick release..."
    wget -q --show-progress -O "$BASE_DIR/debian.zip" \
        "https://github.com/OpenStick/OpenStick/releases/download/v1/debian.zip"
    echo "[*] Mengekstrak debian.zip ke $BASE_DIR..."
    unzip -o "$BASE_DIR/debian.zip" -d "$BASE_DIR"
    rm -f "$BASE_DIR/debian.zip" "$DEBIAN_DIR"/*.exe "$DEBIAN_DIR"/*.dll "$DEBIAN_DIR"/*.bat "$DEBIAN_DIR"/edl_config.json
    rm -rf "$DEBIAN_DIR/debian"
fi

echo "[*] Menjalankan debian/flash.sh..."
cd "$DEBIAN_DIR"
bash flash.sh

# --- 5. Transisi dari Debian ke Bootloader ---
echo ""
echo "[Step 5] Menunggu booting Debian untuk reboot ke bootloader..."
adb wait-for-device
echo "[*] Reboot ke bootloader untuk LongQT-sea firmware..."
adb reboot bootloader || true
sleep 5

# --- 6. Flash LongQT-sea OpenStick-Builder Firmware (Download on-demand jika belum ada) ---
echo ""
echo "[Step 6] Memeriksa file OpenStick-Builder OS (Kernel 6.12 + Debian 12)..."
mkdir -p "$OSBUILD_DIR"
if [ ! -f "$OSBUILD_DIR/rootfs.bin" ] || [ ! -f "$OSBUILD_DIR/boot.bin" ]; then
    echo "[*] Mengunduh openstick-debian.zip..."
    wget -q --show-progress -O "$OSBUILD_DIR/openstick-debian.zip" \
        "https://github.com/LongQT-sea/OpenStick-Builder/releases/download/v1.2/openstick-debian.zip"
    echo "[*] Mengekstrak openstick-debian.zip..."
    unzip -o "$OSBUILD_DIR/openstick-debian.zip" -d "$OSBUILD_DIR"
    rm -f "$OSBUILD_DIR/openstick-debian.zip"
fi

cd "$OSBUILD_DIR"
fastboot flash partition gpt_both0.bin
fastboot flash aboot aboot.mbn
fastboot flash hyp hyp.mbn
fastboot flash rpm rpm.mbn
fastboot flash sbl1 sbl1.mbn
fastboot flash tz tz.mbn
fastboot flash boot boot.bin
fastboot flash rootfs rootfs.bin

# --- 7. Restore Original Partitions dari HM.bin ---
echo ""
echo "[Step 7] Flashing partisi modem, EFS, dan kalibrasi asli..."
cd "$STOCK_EXTRACT_DIR"

for n in fsc fsg modem modemst1 modemst2 persist sec; do
    echo " -> Flashing ${n} (${n}.bin)"
    fastboot flash "${n}" "${n}.bin"
done

# --- 8. Selesai & Reboot ---
echo ""
echo "================================================================="
echo "[✓] Seluruh proses instalasi selesai 100%!"
echo "[*] Mereboot OpenStick ke OS baru..."
echo "================================================================="
fastboot reboot
