#!/bin/bash
# ==============================================================================
# OpenStick Snapdragon 410 (MSM8916) - Direct One-Click Master Installer
# GitHub: https://github.com/jimmylpx/openstick
# ==============================================================================
set -e

GITHUB_REPO="jimmylpx/openstick"
RELEASE_TAG="v1"

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
echo "======================================================================"
echo "      OPENSTICK SNAPDRAGON 410 DIRECT ONE-CLICK MASTER INSTALLER      "
echo "======================================================================"
echo "Direktori Kerja : ${ROOT_DIR}"
echo "Folder Base     : ${BASE_DIR}"
echo "Folder Backup   : ${EXTRACTED_DIR}"
echo "======================================================================"
echo ""

# Pilihan Varian Debian
echo "Pilih Varian Sistem Operasi Debian yang ingin Anda pasang:"
echo "  1) Debian 12 Bookworm  [Rekomendasi - Stabil untuk pemakaian harian]"
echo "  2) Debian 13 Trixie    [Eksperimental - Belum Stabil / Tahap Uji Coba]"
echo ""

if [ -n "$1" ]; then
    CHOICE="$1"
else
    read -r -p "Masukkan pilihan Anda (1 atau 2, default: 1): " CHOICE
fi

if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "trixie" ]; then
    DISTRO_NAME="trixie"
    DISTRO_TITLE="Debian 13 Trixie (Eksperimental)"
else
    DISTRO_NAME="bookworm"
    DISTRO_TITLE="Debian 12 Bookworm (Stabil)"
fi

DISTRO_DIR="${ROOT_DIR}/${DISTRO_NAME}"
DISTRO_ZIP="${DISTRO_NAME}.zip"
DISTRO_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${DISTRO_ZIP}"
mkdir -p "${DISTRO_DIR}"

echo ""
echo "[+] Varian terpilih: ${DISTRO_TITLE}"
echo "======================================================================"
echo ""

# Helper: Ekstraksi partisi GPT dari full raw dump (backup.bin / HM.bin)
extract_gpt_partitions() {
    local bin_file="$1"
    local out_dir="$2"
    python3 -c "
import struct, os, sys

bin_file = sys.argv[1]
out_dir = sys.argv[2]
required = ['fsc', 'fsg', 'modem', 'modemst1', 'modemst2', 'persist', 'sec']

if not os.path.exists(bin_file):
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
" "${bin_file}" "${out_dir}" 2>/dev/null || true
}

# ==============================================================================
# [TAHAP 1/4] DETEKSI STATUS MODEM & MANAJEMEN BACKUP
# ==============================================================================
echo -e "\033[1;33m>>> [TAHAP 1/4] Memeriksa status koneksi perangkat (EDL 9008 / Fastboot)...\033[0m"

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
    echo "[OK] Perangkat terdeteksi di mode Fastboot!"
    
    if [ "$HAS_ALL_EXTRACTED" = false ] && [ -n "$EXISTING_BACKUP" ]; then
        echo ""
        echo "[!] Ditemukan file backup sebelumnya: $(basename "${EXISTING_BACKUP}")"
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
        echo "[OK] Seluruh partisi backup asli sudah siap."
        echo "[OK] Menyesuaikan kondisi: langsung melanjutkan proses download & flashing firmware..."
    fi
fi

# Kondisi 2: Perangkat BELUM di-backup atau BELUM masuk Fastboot dengan backup valid
if [ "$FASTBOOT_READY_WITH_BACKUP" = false ]; then
    if fastboot devices 2>/dev/null | grep -qE "[a-zA-Z0-9]+\s+fastboot" && [ -z "$EXISTING_BACKUP" ] && [ "$HAS_ALL_EXTRACTED" = false ]; then
        echo ""
        echo "[!] Perangkat berada di Fastboot tetapi BELUM DITEMUKAN file backup eMMC!"
        echo "[!] Untuk mengamankan IMEI & sinyal 4G, perangkat wajib di-backup via EDL 9008."
        echo "    -> Mengirim perintah reboot ke EDL (fastboot oem edl)..."
        fastboot oem edl 2>/dev/null || true
        echo "    (Jika tidak beralih otomatis, cabut modem dan tahan tombol EDL saat dicolokkan)."
        echo ""
    fi

    echo "Silakan hubungkan modem Snapdragon 410 Anda dalam mode EDL (Qualcomm 9008)."
    while true; do
        if lsusb 2>/dev/null | grep -qi "05c6:9008" || [ -e /dev/ttyUSB0 ]; then
            echo "[OK] Port EDL Qualcomm 9008 terdeteksi!"
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
            echo "[!] Ditemukan file backup sebelumnya: $(basename "${EXISTING_BACKUP}")"
            read -r -p "Apakah file ini adalah backup dari perangkat saat ini? (y/n, default: y): " USE_EXISTING
            USE_EXISTING=${USE_EXISTING:-y}

            if [[ "$USE_EXISTING" =~ ^[Yy]$ ]]; then
                echo "[OK] Menggunakan file backup yang ada. Proses dump EDL dilewati (skip backup)..."
                FULL_BACKUP_PATH="${EXISTING_BACKUP}"
                SKIP_BACKUP=true
            else
                echo "[*] Menyiapkan dump file backup baru..."
            fi
        fi

        if [ "$SKIP_BACKUP" = false ]; then
            echo "[*] Melakukan FULL RAW DUMP seluruh eMMC flash via edl -> ${BACKUP_NAME}..."
            edl rf "${FULL_BACKUP_PATH}" 2>/dev/null || true
        fi

        # Ekstrak partisi asli
        if [ -f "${FULL_BACKUP_PATH}" ]; then
            extract_gpt_partitions "${FULL_BACKUP_PATH}" "${EXTRACTED_DIR}"
        else
            echo "[*] Mencadangkan partisi individual via edl..."
            for p in "${REQUIRED_PARTS[@]}"; do
                echo "    -> Dumping ${p}..."
                edl r "${p}" "${EXTRACTED_DIR}/${p}.bin" 2>/dev/null || true
            done
        fi

        echo "[*] Menyiapkan Fastboot direct jump via EDL..."
        echo "    -> Menulis bootloader aboot..."
        edl w aboot "${BASE_DIR}/aboot.bin" 2>/dev/null || true
        echo "    -> Mengosongkan partisi boot (force Fastboot mode)..."
        edl e boot 2>/dev/null || true
        echo "    -> Mengirim edl reset (langsung melompat ke Fastboot)..."
        edl reset 2>/dev/null || true
        echo "[OK] Reset terkirim, beralih langsung ke Fastboot mode..."
        sleep 2
    fi
fi

# ==============================================================================
# [TAHAP 2/4] VERIFIKASI FASTBOOT & FLASH BASE GENERIC
# ==============================================================================
echo ""
echo -e "\033[1;33m>>> [TAHAP 2/4] Menunggu perangkat online di Fastboot mode...\033[0m"
while true; do
    if fastboot devices 2>/dev/null | grep -qE "[a-zA-Z0-9]+\s+fastboot"; then
        break
    fi
    echo -n "."
    sleep 1
done
echo "[OK] Perangkat terdeteksi di Fastboot:"
fastboot devices
echo ""

echo -e "\033[1;33m>>> Flashing Base Generic Partitions...\033[0m"
if [ -f "${BASE_DIR}/gpt_both0.bin" ]; then
    fastboot flash partition "${BASE_DIR}/gpt_both0.bin"
    fastboot flash hyp "${BASE_DIR}/hyp.mbn"
    fastboot flash rpm "${BASE_DIR}/rpm.mbn"
    fastboot flash sbl1 "${BASE_DIR}/sbl1.mbn"
    fastboot flash tz "${BASE_DIR}/tz.mbn"
    [ -f "${BASE_DIR}/sbc_1.0_8016.bin" ] && fastboot flash cdt "${BASE_DIR}/sbc_1.0_8016.bin" || true
    fastboot erase boot 2>/dev/null || true
    fastboot erase rootfs 2>/dev/null || true
fi
echo "[OK] Tahap Base generic selesai!"

# ==============================================================================
# [TAHAP 3/4] DOWNLOAD & FLASH DEBIAN FIRMWARE (BOOKWORM / TRIXIE)
# ==============================================================================
echo ""
echo -e "\033[1;33m>>> [TAHAP 3/4] Menyiapkan & Flashing ${DISTRO_TITLE} (/${DISTRO_NAME})...\033[0m"

if [ ! -f "${DISTRO_DIR}/rootfs.bin" ] || [ ! -f "${DISTRO_DIR}/boot.bin" ]; then
    LOCAL_ZIP="${DOWNLOADS_DIR}/${DISTRO_ZIP}"
    if [ ! -f "${LOCAL_ZIP}" ] && [ -f "${ROOT_DIR}/${DISTRO_ZIP}" ]; then
        LOCAL_ZIP="${ROOT_DIR}/${DISTRO_ZIP}"
    fi

    if [ ! -f "${LOCAL_ZIP}" ]; then
        echo "[*] Mengunduh ${DISTRO_ZIP} dari ${DISTRO_URL}..."
        wget -c -O "${DOWNLOADS_DIR}/${DISTRO_ZIP}" "${DISTRO_URL}" || \
        curl -L -o "${DOWNLOADS_DIR}/${DISTRO_ZIP}" "${DISTRO_URL}"
        LOCAL_ZIP="${DOWNLOADS_DIR}/${DISTRO_ZIP}"
    fi

    echo "[*] Mengekstrak ${LOCAL_ZIP} ke ${DISTRO_DIR}..."
    unzip -q -o "${LOCAL_ZIP}" -d "${DISTRO_DIR}"
fi

echo "[*] Flashing firmware ${DISTRO_TITLE} (dengan Wi-Fi WCNSS, fastfetch, sbrmenu, fix ping & dynamic DNS)..."
fastboot flash partition "${DISTRO_DIR}/gpt_both0.bin"
fastboot flash aboot "${DISTRO_DIR}/aboot.mbn"
fastboot flash hyp "${DISTRO_DIR}/hyp.mbn"
fastboot flash rpm "${DISTRO_DIR}/rpm.mbn"
fastboot flash sbl1 "${DISTRO_DIR}/sbl1.mbn"
fastboot flash tz "${DISTRO_DIR}/tz.mbn"
fastboot flash boot "${DISTRO_DIR}/boot.bin"
fastboot -S 200M flash rootfs "${DISTRO_DIR}/rootfs.bin"

echo "[OK] Firmware ${DISTRO_TITLE} berhasil di-flash!"

# ==============================================================================
# [TAHAP 4/4] RESTORE ORIGINAL BASEBAND PARTITIONS & REBOOT
# ==============================================================================
echo ""
echo -e "\033[1;33m>>> [TAHAP 4/4] Mengembalikan partisi asli dari folder extracted/...\033[0m"
for n in "${REQUIRED_PARTS[@]}"; do
    PART_PATH="${EXTRACTED_DIR}/${n}.bin"
    if [ -f "${PART_PATH}" ]; then
        echo "    -> Flashing ${n} (${PART_PATH})..."
        fastboot flash "${n}" "${PART_PATH}"
    else
        echo "    [!] File ${PART_PATH} tidak ditemukan, melewati partisi ${n}."
    fi
done

echo ""
echo "======================================================================"
echo -e "\033[1;32m   PROSES FLASHING SELESAI! ME-REBOOT PERANGKAT KE LINUX...           \033[0m"
echo "======================================================================"
fastboot reboot

echo ""
echo "Perangkat sedang me-reboot ke sistem ${DISTRO_TITLE}."
echo "Wajib Dilakukan: Cabut modem dari port USB, lalu colokkan kembali secara normal (Cold Boot)."
echo "Setelah booting selesai (~40 detik):"
echo "  - Wi-Fi Hotspot : SSID '4G-UFI-XX' (Password: 1234567890)"
echo "  - Windows PC    : Colokkan USB (RNDIS) -> ssh user@192.168.100.1"
echo "  - Login SSH     : ssh user@192.168.100.1 (Password: 1)"
echo "  - Akses ADB     : adb connect 192.168.100.1:5555 && adb shell"
echo ""
echo "Setelah login, ketik 'sbrmenu' untuk mengelola Hotspot, 4G LTE, SMS, dan USB Mode."
echo "Untuk akses root: jalankan 'sudo su' (Password: 1)"
echo "======================================================================"
