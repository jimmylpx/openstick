#!/bin/bash
# ==============================================================================
# OpenStick Snapdragon 410 (MSM8916) - Direct One-Click Master Installer
# GitHub: https://github.com/jimmylpx/openstick
# ==============================================================================
set -e

GITHUB_REPO="jimmylpx/openstick"
RELEASE_TAG="v1"

# Warna Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# 0. PENGECEKAN DEPENDENSI TOOL (ADB, FASTBOOT, EDL, PYTHON3, UNZIP)
# ------------------------------------------------------------------------------
MISSING_TOOLS=()
for tool in adb fastboot edl python3 unzip; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${RED}======================================================================${NC}"
    echo -e "${RED}${BOLD}[ERROR] TOOL PENDUKUNG BELUM TERPASANG PADA SISTEM ANDA!${NC}"
    echo -e "${RED}======================================================================${NC}"
    echo -e "Tool yang belum ditemukan: ${YELLOW}${BOLD}${MISSING_TOOLS[*]}${NC}"
    echo ""
    echo -e "${CYAN}Silakan pasang tool yang kurang sebelum menjalankan installer ini:${NC}"
    
    if [[ " ${MISSING_TOOLS[*]} " =~ " adb " ]] || [[ " ${MISSING_TOOLS[*]} " =~ " fastboot " ]] || [[ " ${MISSING_TOOLS[*]} " =~ " python3 " ]] || [[ " ${MISSING_TOOLS[*]} " =~ " unzip " ]]; then
        echo -e "  - ${BOLD}Paket Sistem (ADB, Fastboot, Python3, Unzip):${NC}"
        echo -e "    ${GREEN}sudo apt update && sudo apt install -y adb fastboot python3 python3-pip unzip wget${NC}"
    fi
    
    if [[ " ${MISSING_TOOLS[*]} " =~ " edl " ]]; then
        echo -e "  - ${BOLD}Qualcomm EDL Tool (bkerler/edl):${NC}"
        echo -e "    ${GREEN}Panduan Instalasi Gist : https://gist.github.com/jimmylpx/b8dba187d772e2c35ee5d2967cd71221${NC}"
        echo -e "    ${GREEN}Atau jalankan skrip    : curl -sSL https://raw.githubusercontent.com/jimmylpx/openstick/main/sourcecode/install_edl.sh | sudo bash${NC}"
    fi
    
    echo ""
    echo -e "${RED}[!] Instalasi DIBATALKAN karena dependensi belum lengkap.${NC}"
    echo -e "${RED}======================================================================${NC}"
    exit 1
fi

# Deteksi lokasi direktori
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/../base" ] || [ "$(basename "${SCRIPT_DIR}")" = "base" ]; then
    ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    BASE_DIR="${SCRIPT_DIR}"
else
    ROOT_DIR="${SCRIPT_DIR}"
    BASE_DIR="${ROOT_DIR}/base"
fi

EXTRACTED_DIR="${ROOT_DIR}/extracted"
DOWNLOADS_DIR="${ROOT_DIR}/downloads"

mkdir -p "${EXTRACTED_DIR}" "${DOWNLOADS_DIR}"

clear
echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}      OPENSTICK SNAPDRAGON 410 DIRECT ONE-CLICK MASTER INSTALLER      ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "Direktori Kerja : ${BOLD}${ROOT_DIR}${NC}"
echo -e "Folder Base     : ${BOLD}${BASE_DIR}${NC}"
echo -e "Folder Backup   : ${BOLD}${EXTRACTED_DIR}${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# Pilihan Varian Debian
echo -e "${YELLOW}Pilih Varian Sistem Operasi Debian yang ingin Anda pasang:${NC}"
echo "  1) Debian 12 Bookworm (Standar)        [Rekomendasi - 4G Modem Aktif, RAM ~390MB]"
echo "  2) Debian 12 Bookworm (Modem-Disabled) [Rekomendasi Server/Homelab - RAM Sekitar ~466MB]"
echo "  3) Debian 13 Trixie                    [Eksperimental - Belum Stabil / Tahap Uji Coba]"
echo ""

if [ -n "$1" ]; then
    CHOICE="$1"
else
    read -r -p "Masukkan pilihan Anda (1/2/3, default: 1): " CHOICE
fi

if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "bookworm-modem-disabled" ] || [ "$CHOICE" = "modem-disabled" ]; then
    DISTRO_NAME="bookworm-modem-disabled"
    DISTRO_TITLE="Debian 12 Bookworm (Modem-Disabled - RAM ~466MB)"
elif [ "$CHOICE" = "3" ] || [ "$CHOICE" = "trixie" ]; then
    DISTRO_NAME="trixie"
    DISTRO_TITLE="Debian 13 Trixie (Eksperimental)"
else
    DISTRO_NAME="bookworm"
    DISTRO_TITLE="Debian 12 Bookworm (Standar Stabil)"
fi

DISTRO_DIR="${ROOT_DIR}/${DISTRO_NAME}"
DISTRO_ZIP="${DISTRO_NAME}.zip"
DISTRO_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${DISTRO_ZIP}"
mkdir -p "${DISTRO_DIR}"

echo ""
echo -e "[+] Varian terpilih: ${GREEN}${BOLD}${DISTRO_TITLE}${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# Helper: Ekstraksi partisi GPT dari full raw dump (backup.bin)
extract_gpt_partitions() {
    local bin_file="$1"
    local out_dir="$2"
    python3 -c "
import struct, os, sys

bin_file = sys.argv[1]
out_dir = sys.argv[2]
required = ['fsc', 'fsg', 'modem', 'modemst1', 'modemst2', 'persist', 'sec']

if not os.path.exists(bin_file):
    print(f'[!] File {bin_file} tidak ditemukan.')
    sys.exit(1)

print(f'[*] Membaca GPT partition table dari {bin_file}...')
with open(bin_file, 'rb') as f:
    f.seek(512)
    hdr = f.read(92)
    if len(hdr) < 92 or hdr[:8] != b'EFI PART':
        print('[!] Header GPT tidak ditemukan di LBA 1.')
        sys.exit(1)
    
    part_lba, num_entries, entry_size = struct.unpack('<QII', hdr[72:88])
    f.seek(part_lba * 512)
    
    extracted_count = 0
    for i in range(num_entries):
        entry = f.read(entry_size)
        if len(entry) < 128 or entry[:16] == b'\x00' * 16:
            continue
        start_lba, end_lba = struct.unpack('<QQ', entry[32:48])
        name = entry[56:128].decode('utf-16le', errors='ignore').rstrip('\x00').lower()
        
        for req in required:
            if name == req:
                size_bytes = (end_lba - start_lba + 1) * 512
                out_path = os.path.join(out_dir, f'{req}.bin')
                
                cur_pos = f.tell()
                f.seek(start_lba * 512)
                data = f.read(size_bytes)
                f.seek(cur_pos)
                
                with open(out_path, 'wb') as out_f:
                    out_f.write(data)
                print(f'    [OK] Partisi {req} ({len(data)} bytes) berhasil diekstrak -> {out_path}')
                extracted_count += 1
                break

print(f'[*] Selesai mengekstrak {extracted_count} partisi asli.')
" "${bin_file}" "${out_dir}"
}

# ==============================================================================
# [TAHAP 1/4] DETEKSI STATUS MODEM & MANAJEMEN BACKUP
# ==============================================================================
echo -e "${YELLOW}${BOLD}>>> [TAHAP 1/4] Memeriksa status koneksi perangkat (EDL 9008 / Fastboot)...${NC}"

REQUIRED_PARTS=("fsc" "fsg" "modem" "modemst1" "modemst2" "persist" "sec")
FASTBOOT_READY_WITH_BACKUP=false

# Cek ketersediaan file backup sebelumnya
EXISTING_BACKUP=$(ls -t "${ROOT_DIR}"/backup*.bin "${EXTRACTED_DIR}"/backup*.bin 2>/dev/null | head -n 1)
HAS_ALL_EXTRACTED=true
for p in "${REQUIRED_PARTS[@]}"; do
    if [ ! -f "${EXTRACTED_DIR}/${p}.bin" ]; then
        HAS_ALL_EXTRACTED=false
        break
    fi
done

# Kondisi 1: Perangkat SUDAH di Fastboot DAN Ditemukan File Backup Sebelumnya
if fastboot devices 2>/dev/null | grep -qE "[a-zA-Z0-9]+\s+fastboot" && ( [ -n "$EXISTING_BACKUP" ] || [ "$HAS_ALL_EXTRACTED" = true ] ); then
    echo -e "${GREEN}[OK] Perangkat terdeteksi di mode Fastboot!${NC}"
    
    if [ "$HAS_ALL_EXTRACTED" = false ] && [ -n "$EXISTING_BACKUP" ]; then
        echo ""
        echo -e "${YELLOW}[!] Ditemukan file backup sebelumnya: $(basename "${EXISTING_BACKUP}")${NC}"
        read -r -p "Apakah file ini adalah backup dari perangkat saat ini? (y/n, default: y): " USE_EXISTING
        USE_EXISTING=${USE_EXISTING:-y}
        if [[ "$USE_EXISTING" =~ ^[Yy]$ ]]; then
            echo "[OK] Mengekstrak partisi asli dari $(basename "${EXISTING_BACKUP}")..."
            extract_gpt_partitions "${EXISTING_BACKUP}" "${EXTRACTED_DIR}"
            FASTBOOT_READY_WITH_BACKUP=true
        else
            echo "[!] File backup tidak digunakan. Wajib masuk mode EDL 9008 untuk membuat backup baru."
        fi
    else
        FASTBOOT_READY_WITH_BACKUP=true
    fi

    if [ "$FASTBOOT_READY_WITH_BACKUP" = true ]; then
        echo -e "${GREEN}[OK] Seluruh partisi backup asli sudah siap.${NC}"
        echo -e "${GREEN}[OK] Menyesuaikan kondisi: langsung melanjutkan proses download & flashing firmware...${NC}"
    fi
fi

# Kondisi 2: Perangkat BELUM di-backup atau BELUM masuk Fastboot dengan backup valid
if [ "$FASTBOOT_READY_WITH_BACKUP" = false ]; then
    if fastboot devices 2>/dev/null | grep -qE "[a-zA-Z0-9]+\s+fastboot" && [ -z "$EXISTING_BACKUP" ] && [ "$HAS_ALL_EXTRACTED" = false ]; then
        echo ""
        echo -e "${RED}[!] Perangkat berada di mode Fastboot tetapi BELUM DITEMUKAN file backup eMMC!${NC}"
        echo -e "${YELLOW}[!] Untuk mengamankan partisi baseband (IMEI & sinyal 4G), perangkat WAJIB di-backup terlebih dahulu.${NC}"
        echo "    -> Silakan cabut modem dari port USB."
        echo "    -> Tahan tombol fisik EDL (atau hubungkan titik test point EDL), lalu colokkan kembali ke port USB."
        echo ""
    fi

    echo "Menunggu modem dalam mode EDL (Qualcomm 9008)..."
    while true; do
        if lsusb 2>/dev/null | grep -qi "05c6:9008" || [ -e /dev/ttyUSB0 ]; then
            echo -e "${GREEN}[OK] Port EDL Qualcomm 9008 terdeteksi!${NC}"
            break
        else
            echo -n "."
            sleep 1
        fi
    done

    # Eksekusi Backup di Mode EDL (9008)
    if lsusb 2>/dev/null | grep -qi "05c6:9008" || [ -e /dev/ttyUSB0 ]; then
        BACKUP_TIMESTAMP=$(date +"%Y_%m_%d_%H_%M")
        BACKUP_NAME="backup_${BACKUP_TIMESTAMP}.bin"
        FULL_BACKUP_PATH="${ROOT_DIR}/${BACKUP_NAME}"
        
        EXISTING_BACKUP=$(ls -t "${ROOT_DIR}"/backup*.bin "${EXTRACTED_DIR}"/backup*.bin 2>/dev/null | head -n 1)
        SKIP_BACKUP=false

        if [ -n "$EXISTING_BACKUP" ] && [ -f "$EXISTING_BACKUP" ]; then
            echo ""
            echo -e "${YELLOW}[!] Ditemukan file backup sebelumnya: $(basename "${EXISTING_BACKUP}")${NC}"
            read -r -p "Apakah file ini adalah backup dari perangkat saat ini? (y/n, default: y): " USE_EXISTING
            USE_EXISTING=${USE_EXISTING:-y}

            if [[ "$USE_EXISTING" =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}[OK] Menggunakan file backup yang ada. Proses dump EDL dilewati (skip backup)...${NC}"
                FULL_BACKUP_PATH="${EXISTING_BACKUP}"
                SKIP_BACKUP=true
            else
                echo "[*] Menyiapkan dump file backup baru..."
            fi
        fi

        if [ "$SKIP_BACKUP" = false ]; then
            echo -e "${BLUE}[*] Melakukan FULL RAW DUMP seluruh eMMC flash via edl -> ${BACKUP_NAME}...${NC}"
            edl rf "${FULL_BACKUP_PATH}"
        fi

        # Ekstrak partisi asli
        if [ -f "${FULL_BACKUP_PATH}" ]; then
            extract_gpt_partitions "${FULL_BACKUP_PATH}" "${EXTRACTED_DIR}"
        else
            echo "[*] Mencadangkan partisi individual via edl..."
            for p in "${REQUIRED_PARTS[@]}"; do
                echo "    -> Dumping ${p}..."
                edl r "${p}" "${EXTRACTED_DIR}/${p}.bin"
            done
        fi

        echo -e "${BLUE}[*] Menyiapkan Fastboot direct jump via EDL...${NC}"
        echo "    -> Menulis bootloader aboot..."
        edl w aboot "${BASE_DIR}/aboot.bin"
        echo "    -> Mengosongkan partisi boot (force Fastboot mode)..."
        edl e boot
        echo "    -> Mengirim edl reset (langsung melompat ke Fastboot)..."
        edl reset || true
        echo -e "${GREEN}[OK] Reset terkirim, beralih langsung ke Fastboot mode...${NC}"
        sleep 2
    fi
fi

# ==============================================================================
# [TAHAP 2/4] VERIFIKASI FASTBOOT & FLASH BASE GENERIC
# ==============================================================================
echo ""
echo -e "${YELLOW}${BOLD}>>> [TAHAP 2/4] Menunggu perangkat online di Fastboot mode...${NC}"
while true; do
    if fastboot devices 2>/dev/null | grep -qE "[a-zA-Z0-9]+\s+fastboot"; then
        break
    fi
    echo -n "."
    sleep 1
done
echo -e "${GREEN}[OK] Perangkat terdeteksi di Fastboot:${NC}"
fastboot devices
echo ""

echo -e "${YELLOW}${BOLD}>>> Flashing Base Generic Partitions...${NC}"
if [ -f "${BASE_DIR}/gpt_both0.bin" ]; then
    fastboot flash partition "${BASE_DIR}/gpt_both0.bin"
    fastboot flash hyp "${BASE_DIR}/hyp.mbn"
    fastboot flash rpm "${BASE_DIR}/rpm.mbn"
    fastboot flash sbl1 "${BASE_DIR}/sbl1.mbn"
    fastboot flash tz "${BASE_DIR}/tz.mbn"
    [ -f "${BASE_DIR}/sbc_1.0_8016.bin" ] && fastboot flash cdt "${BASE_DIR}/sbc_1.0_8016.bin" || true
    fastboot erase boot || true
    fastboot erase rootfs || true
fi
echo -e "${GREEN}[OK] Tahap Base generic selesai!${NC}"

# ==============================================================================
# [TAHAP 3/4] DOWNLOAD & FLASH DEBIAN FIRMWARE (BOOKWORM / TRIXIE)
# ==============================================================================
echo ""
echo -e "${YELLOW}${BOLD}>>> [TAHAP 3/4] Menyiapkan & Flashing ${DISTRO_TITLE} (/${DISTRO_NAME})...${NC}"

if [ ! -f "${DISTRO_DIR}/rootfs.bin" ] || [ ! -f "${DISTRO_DIR}/boot.bin" ]; then
    LOCAL_ZIP="${DOWNLOADS_DIR}/${DISTRO_ZIP}"
    if [ ! -f "${LOCAL_ZIP}" ] && [ -f "${ROOT_DIR}/${DISTRO_ZIP}" ]; then
        LOCAL_ZIP="${ROOT_DIR}/${DISTRO_ZIP}"
    fi

    if [ ! -f "${LOCAL_ZIP}" ]; then
        echo -e "${BLUE}[*] Mengunduh ${DISTRO_ZIP} dari ${DISTRO_URL}...${NC}"
        wget -c -O "${DOWNLOADS_DIR}/${DISTRO_ZIP}" "${DISTRO_URL}" || \
        curl -L -o "${DOWNLOADS_DIR}/${DISTRO_ZIP}" "${DISTRO_URL}"
        LOCAL_ZIP="${DOWNLOADS_DIR}/${DISTRO_ZIP}"
    fi

    echo -e "${BLUE}[*] Mengekstrak ${LOCAL_ZIP} ke ${DISTRO_DIR}...${NC}"
    unzip -o "${LOCAL_ZIP}" -d "${DISTRO_DIR}"
fi

echo -e "${BLUE}[*] Flashing firmware ${DISTRO_TITLE} (dengan Wi-Fi WCNSS, fastfetch, sbrmenu, fix ping & dynamic DNS)...${NC}"
fastboot flash partition "${DISTRO_DIR}/gpt_both0.bin"
fastboot flash aboot "${DISTRO_DIR}/aboot.mbn"
fastboot flash hyp "${DISTRO_DIR}/hyp.mbn"
fastboot flash rpm "${DISTRO_DIR}/rpm.mbn"
fastboot flash sbl1 "${DISTRO_DIR}/sbl1.mbn"
fastboot flash tz "${DISTRO_DIR}/tz.mbn"
fastboot flash boot "${DISTRO_DIR}/boot.bin"
fastboot -S 200M flash rootfs "${DISTRO_DIR}/rootfs.bin"

echo -e "${GREEN}[OK] Firmware ${DISTRO_TITLE} berhasil di-flash!${NC}"

# ==============================================================================
# [TAHAP 4/4] RESTORE ORIGINAL BASEBAND PARTITIONS & REBOOT
# ==============================================================================
echo ""
echo -e "${YELLOW}${BOLD}>>> [TAHAP 4/4] Mengembalikan partisi asli dari folder extracted/...${NC}"
for n in "${REQUIRED_PARTS[@]}"; do
    PART_PATH="${EXTRACTED_DIR}/${n}.bin"
    if [ -f "${PART_PATH}" ]; then
        echo -e "    -> Flashing ${BOLD}${n}${NC} (${PART_PATH})..."
        fastboot flash "${n}" "${PART_PATH}"
    else
        echo -e "    ${YELLOW}[!] File ${PART_PATH} tidak ditemukan, melewati partisi ${n}.${NC}"
    fi
done

echo ""
echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}   PROSES FLASHING SELESAI! ME-REBOOT PERANGKAT KE LINUX...           ${NC}"
echo -e "${CYAN}======================================================================${NC}"
fastboot reboot

echo ""
echo -e "${GREEN}Perangkat sedang me-reboot ke sistem ${DISTRO_TITLE}.${NC}"
echo ""
echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}${BOLD}⚠️  PENTING (POWER CYCLE USB):${NC}"
echo -e "  Jika dalam waktu ${BOLD}1 menit${NC} perangkat belum menyala (LED mati/belum terdeteksi),"
echo -e "  silakan ${GREEN}${BOLD}CABUT dan COLOK KEMBALI${NC} stik USB Anda ke port PC/server!"
echo -e "${YELLOW}======================================================================${NC}"
echo ""
echo "Setelah booting selesai (~40 detik):"
echo "  - Wi-Fi Hotspot : SSID '4G-UFI-XX' (Password: 1234567890)"
echo "  - Windows PC    : Colokkan USB (RNDIS) -> ssh user@192.168.100.1"
echo "  - Linux PC      : Cek nama interface via 'ip a show' (usb0 / enx*****):"
echo "                    sudo ip link set dev <nama_interface> up"
echo "                    sudo dhclient <nama_interface>"
echo "  - Login SSH     : ssh user@192.168.100.1 (Password: 1)"
echo "  - Akses ADB     : adb connect 192.168.100.1:5555 && adb shell"
echo ""
echo -e "${YELLOW}Setelah login, ketik 'sbrmenu' untuk mengelola Hotspot, 4G LTE, SMS, dan USB Mode.${NC}"
echo -e "Untuk akses root: jalankan ${CYAN}sudo su${NC} (Password: 1)"
echo -e "${CYAN}======================================================================${NC}"
