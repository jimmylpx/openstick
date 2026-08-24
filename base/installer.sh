#!/usr/bin/env bash
# ==============================================================================
# OpenStick Universal Flasher & Installer
# Supported Boards: HMUF02-V05, UZ801, UFI103S-V05 (Snapdragon 410 / MSM8916)
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=================================================================${NC}"
echo -e "${GREEN}       OpenStick Universal Installer (Debian 12 & 13)            ${NC}"
echo -e "${CYAN}=================================================================${NC}"

# 1. Pre-flight dependency check
echo -e "\n${BLUE}[*] Memeriksa dependensi sistem...${NC}"
DEPS=("adb" "fastboot" "python3" "unzip" "wget")
MISSING=()

for d in "${DEPS[@]}"; do
    if ! command -v "$d" >/dev/null 2>&1; then
        MISSING+=("$d")
    fi
done

if ! command -v edl >/dev/null 2>&1 && ! python3 -m edl --help >/dev/null 2>&1; then
    MISSING+=("edl (pip3 install edl)")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${RED}[!] Dependensi berikut belum terpasang: ${MISSING[*]}${NC}"
    echo -e "${YELLOW}Silakan pasang terlebih dahulu via apt: sudo apt install -y adb fastboot python3 python3-pip unzip wget && pip3 install edl${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Semua dependensi terpenuhi.${NC}"

# 2. OS Selection Menu
echo -e "\n${CYAN}Pilih Edisi Sistem Operasi yang Ingin Di-flash:${NC}"
echo -e "  ${GREEN}1)${NC} Debian 12 (Bookworm) - Ultra Ringan & Stabil [~114 MB]"
echo -e "  ${GREEN}2)${NC} Debian 13 (Trixie)   - Versi Terbaru (Glibc 2.41) [~125 MB]"
read -rp "Masukkan pilihan [1 atau 2, default 1]: " OS_CHOICE
OS_CHOICE=${OS_CHOICE:-1}

RELEASE_BASE="https://github.com/jimmylpx/openstick/releases/download/v1"

if [ "$OS_CHOICE" = "2" ]; then
    OS_NAME="Debian 13 (Trixie)"
    OS_ZIP="openstick-trixie.zip"
    OS_DIR="os_trixie"
else
    OS_NAME="Debian 12 (Bookworm)"
    OS_ZIP="openstick-bookworm.zip"
    OS_DIR="os_bookworm"
fi

echo -e "\n${GREEN}[*] Target OS: ${OS_NAME}${NC}"

# 3. Download OS Firmware Package if not present
if [ ! -f "$OS_ZIP" ]; then
    echo -e "${BLUE}[*] Mengunduh paket firmware ${OS_ZIP}...${NC}"
    wget -c "${RELEASE_BASE}/${OS_ZIP}"
fi

echo -e "${BLUE}[*] Mengekstrak paket firmware...${NC}"
rm -rf "$OS_DIR"
mkdir -p "$OS_DIR"
unzip -q -o "$OS_ZIP" -d "$OS_DIR"

# 4. Check for device in EDL mode
echo -e "\n${BLUE}[*] Memeriksa koneksi perangkat EDL (05c6:9008)...${NC}"
if ! lsusb | grep -q "05c6:9008"; then
    echo -e "${YELLOW}[!] Perangkat belum terdeteksi dalam mode EDL 9008.${NC}"
    echo -e "Petunjuk:"
    echo -e "  - HMUF02 / UFI103S : Tahan tombol kecil pada board, colok USB, tahan 5 detik."
    echo -e "  - UZ801            : Short 2 test point pada board atau via http://192.168.100.1/usbdebug.html"
    echo -e "\nMenunggu perangkat dalam mode EDL..."
    while ! lsusb | grep -q "05c6:9008"; do
        sleep 2
    done
fi
echo -e "${GREEN}[✓] Perangkat terdeteksi dalam mode EDL!${NC}"

# 5. Backup stock firmware if not already dumped
if [ ! -f "HM.bin" ]; then
    echo -e "\n${BLUE}[*] Membuat full backup firmware asli (HM.bin)...${NC}"
    if command -v edl >/dev/null 2>&1; then
        edl rf HM.bin
    else
        python3 -m edl rf HM.bin
    fi
    echo -e "${GREEN}[✓] Backup firmware asli selesai: HM.bin${NC}"
else
    echo -e "${GREEN}[✓] Menggunakan file backup firmware asli yang sudah ada (HM.bin).${NC}"
fi

# 6. Extract baseband partitions from HM.bin
echo -e "\n${BLUE}[*] Mengekstrak partisi baseband modem & EFS dari HM.bin...${NC}"
mkdir -p stock_extracted
python3 extract_hm_partitions.py HM.bin stock_extracted

# 7. Flash bootloaders & partition table
echo -e "\n${BLUE}[*] Menyiapkan flashing partisi & bootloader...${NC}"
if command -v edl >/dev/null 2>&1; then
    edl reset || true
else
    python3 -m edl reset || true
fi

echo -e "${BLUE}[*] Menunggu perangkat masuk ke mode Fastboot...${NC}"
fastboot wait-for-device

echo -e "${BLUE}[*] Mem-flash tabel partisi GPT...${NC}"
fastboot flash partition gpt_both0.bin
fastboot flash hyp hyp.mbn
fastboot flash rpm rpm.mbn
fastboot flash sbl1 sbl1.mbn
fastboot flash tz tz.mbn
fastboot flash aboot aboot.bin
fastboot flash cdt sbc_1.0_8016.bin

# 8. Flash OS RootFS & Kernel Boot
echo -e "\n${BLUE}[*] Mem-flash OS ${OS_NAME}...${NC}"
if [ -f "$OS_DIR/rootfs.bin" ]; then
    fastboot -S 200M flash rootfs "$OS_DIR/rootfs.bin"
elif [ -f "$OS_DIR/rootfs.img" ]; then
    fastboot -S 200M flash rootfs "$OS_DIR/rootfs.img"
fi

if [ -f "$OS_DIR/boot.bin" ]; then
    fastboot flash boot "$OS_DIR/boot.bin"
elif [ -f "$OS_DIR/boot.img" ]; then
    fastboot flash boot "$OS_DIR/boot.img"
fi

# 9. Restore Baseband & Modem Partitions
echo -e "\n${BLUE}[*] Memulihkan partisi baseband modem & IMEI...${NC}"
for part in fsc fsg modem modemst1 modemst2 persist sec; do
    if [ -f "stock_extracted/${part}.bin" ]; then
        echo -e "  -> Flashing ${part}..."
        fastboot flash "$part" "stock_extracted/${part}.bin"
    fi
done

echo -e "\n${GREEN}=================================================================${NC}"
echo -e "${GREEN}             PROSES FLASHING SELESAI DENGAN SUKSES!             ${NC}"
echo -e "${GREEN}=================================================================${NC}"
echo -e "\n${YELLOW}⚠️  LANGKAH PENTING BERIKUTNYA:${NC}"
echo -e "1. ${CYAN}Cabut modem dari port USB komputer.${NC}"
echo -e "2. ${CYAN}Colokkan kembali modem secara normal${NC} (tanpa menekan tombol / short pin)."
echo -e "3. Tunggu ~40 detik hingga modem selesai booting ke Debian Linux."
echo -e "4. Hubungkan via SSH:"
echo -e "   - ${GREEN}ssh user@192.168.100.1${NC} (Password: ${GREEN}1${NC})"
echo -e "   - ${GREEN}ssh root@192.168.100.1${NC} (Password: ${GREEN}1${NC})"
echo -e "5. Jalankan ${GREEN}sbrmenu${NC} untuk mengelola hotspot Wi-Fi, 4G LTE, dan fitur lainnya."
echo -e "${GREEN}=================================================================${NC}\n"
