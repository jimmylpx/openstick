#!/usr/bin/env python3
"""
OpenStick Snapdragon 410 (MSM8916) - Direct One-Click Master Installer (Windows Python Edition)
GitHub: https://github.com/jimmylpx/openstick
"""

import os
import sys
import time
import glob
import shutil
import struct
import zipfile
import subprocess
import urllib.request
from datetime import datetime

GITHUB_REPO = "jimmylpx/openstick"
RELEASE_TAG = "v1"

REQUIRED_PARTS = ["fsc", "fsg", "modem", "modemst1", "modemst2", "persist", "sec"]

# Color support for Windows Terminal & Command Prompt
def print_cyan(text): print(f"\033[96m{text}\033[0m")
def print_green(text): print(f"\033[92m{text}\033[0m")
def print_yellow(text): print(f"\033[93m{text}\033[0m")
def print_red(text): print(f"\033[91m{text}\033[0m")
def print_blue(text): print(f"\033[94m{text}\033[0m")

# Enable ANSI escape sequences on Windows CMD
if os.name == 'nt':
    os.system('')

def run_cmd(cmd, check=True, capture=False):
    """Helper to run system commands cleanly"""
    if capture:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    res = subprocess.run(cmd, shell=True)
    if check and res.returncode != 0:
        raise subprocess.CalledProcessError(res.returncode, cmd)
    return res.returncode

def extract_gpt_partitions(bin_file, out_dir):
    """Extract required baseband partitions from raw eMMC dump using GPT table"""
    if not os.path.exists(bin_file):
        print_red(f"[!] File {bin_file} tidak ditemukan.")
        return False

    os.makedirs(out_dir, exist_ok=True)
    print_blue(f"[*] Membaca GPT partition table dari {bin_file}...")

    try:
        with open(bin_file, 'rb') as f:
            f.seek(512)
            hdr = f.read(92)
            if len(hdr) < 92 or hdr[:8] != b'EFI PART':
                print_red("[!] Header GPT tidak ditemukan di LBA 1.")
                return False

            part_lba, num_entries, entry_size = struct.unpack('<QII', hdr[72:88])
            f.seek(part_lba * 512)

            extracted_count = 0
            for _ in range(num_entries):
                entry = f.read(entry_size)
                if len(entry) < 128 or entry[:16] == b'\x00' * 16:
                    continue
                start_lba, end_lba = struct.unpack('<QQ', entry[32:48])
                name = entry[56:128].decode('utf-16le', errors='ignore').rstrip('\x00').lower()

                for req in REQUIRED_PARTS:
                    if name == req:
                        size_bytes = (end_lba - start_lba + 1) * 512
                        out_path = os.path.join(out_dir, f"{req}.bin")

                        cur_pos = f.tell()
                        f.seek(start_lba * 512)
                        data = f.read(size_bytes)
                        f.seek(cur_pos)

                        with open(out_path, 'wb') as out_f:
                            out_f.write(data)
                        print_green(f"    [OK] Partisi {req} ({len(data)} bytes) berhasil diekstrak -> {out_path}")
                        extracted_count += 1
                        break

        print_green(f"[*] Selesai mengekstrak {extracted_count} partisi asli.")
        return extracted_count == len(REQUIRED_PARTS)
    except Exception as e:
        print_red(f"[!] Gagal mengekstrak GPT: {e}")
        return False

def check_fastboot_connected():
    rc, stdout, _ = run_cmd("fastboot devices", capture=True)
    return any("fastboot" in line for line in stdout.splitlines())

def check_edl_connected():
    rc, stdout, stderr = run_cmd("edl printgpt", capture=True)
    return rc == 0

def download_file_with_progress(url, dest_path):
    print_blue(f"[*] Mengunduh {os.path.basename(dest_path)} dari {url}...")
    headers = {'User-Agent': 'Mozilla/5.0'}
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response, open(dest_path, 'wb') as out_file:
        total_size = int(response.info().get('Content-Length', 0))
        downloaded = 0
        chunk_size = 1024 * 1024
        while True:
            chunk = response.read(chunk_size)
            if not chunk:
                break
            out_file.write(chunk)
            downloaded += len(chunk)
            if total_size > 0:
                percent = downloaded * 100 / total_size
                mb_down = downloaded / (1024 * 1024)
                mb_total = total_size / (1024 * 1024)
                sys.stdout.write(f"\r    -> {mb_down:.1f} MB / {mb_total:.1f} MB ({percent:.1f}%)")
                sys.stdout.flush()
        print()
    print_green("    [OK] Unduhan selesai!")

def main():
    print_cyan("======================================================================")
    print_green("      OPENSTICK SNAPDRAGON 410 DIRECT ONE-CLICK MASTER INSTALLER      ")
    print_cyan("                         (WINDOWS PYTHON EDITION)                     ")
    print_cyan("======================================================================")
    print()

    # 0. Pengecekan Tool
    missing = []
    for tool in ["fastboot", "edl"]:
        if shutil.which(tool) is None:
            missing.append(tool)
    if missing:
        print_red("======================================================================")
        print_red("[ERROR] TOOL PENDUKUNG BELUM TERPASANG DI WINDOWS ANDA!")
        print_red("======================================================================")
        print_yellow(f"Tool yang belum ditemukan: {', '.join(missing)}")
        print()
        print_cyan("Silakan jalankan script instalasi PowerShell berikut sebagai Administrator:")
        print_green("  powershell -ExecutionPolicy Bypass -File install_adb_fastboot_edl.ps1")
        print_cyan("Atau baca panduan: ADB_FASTBOOT_EDL_INSTALL_WINDOWS.md")
        print_red("======================================================================")
        input("Tekan Enter untuk keluar...")
        sys.exit(1)

    # Direktori kerja
    script_dir = os.path.dirname(os.path.abspath(__file__))
    current_dir = script_dir
    base_dir = current_dir
    extracted_dir = os.path.join(current_dir, "extracted")
    downloads_dir = os.path.join(current_dir, "downloads")

    os.makedirs(extracted_dir, exist_ok=True)
    os.makedirs(downloads_dir, exist_ok=True)

    print(f"Folder Installer : {current_dir}")
    print(f"Folder Base      : {base_dir}")
    print(f"Folder Extracted : {extracted_dir}")
    print_cyan("======================================================================")
    print()

    # Pilihan Distro
    print_yellow("Pilih Varian Sistem Operasi Debian yang ingin Anda pasang:")
    print("  1) Debian 12 Bookworm (Standar)        [Rekomendasi - 4G Modem Aktif, RAM ~390MB]")
    print("  2) Debian 12 Bookworm (Modem-Disabled) [Rekomendasi Server/Homelab - RAM Sekitar ~466MB]")
    print("  3) Debian 13 Trixie (Standar)          [Eksperimental - 4G Modem Aktif]")
    print("  4) Debian 13 Trixie (Modem-Disabled)   [Eksperimental - RAM Sekitar ~466MB]")
    print()

    choice = input("Masukkan pilihan Anda (1/2/3/4, default: 1): ").strip()
    if choice == "2" or choice == "bookworm-modem-disabled":
        distro_name = "bookworm-modem-disabled"
        distro_title = "Debian 12 Bookworm (Modem-Disabled - RAM ~466MB)"
    elif choice == "3" or choice == "trixie":
        distro_name = "trixie"
        distro_title = "Debian 13 Trixie (Standar Eksperimental)"
    elif choice == "4" or choice == "trixie-modem-disabled":
        distro_name = "trixie-modem-disabled"
        distro_title = "Debian 13 Trixie (Modem-Disabled - RAM ~466MB)"
    else:
        distro_name = "bookworm"
        distro_title = "Debian 12 Bookworm (Standar Stabil)"

    distro_dir = os.path.join(current_dir, distro_name)
    distro_zip = f"{distro_name}.zip"
    distro_url = f"https://github.com/{GITHUB_REPO}/releases/download/{RELEASE_TAG}/{distro_zip}"
    os.makedirs(distro_dir, exist_ok=True)

    print()
    print_green(f"[+] Varian terpilih: {distro_title}")
    print_cyan("======================================================================")
    print()

    # ==============================================================================
    # [TAHAP 1/4] DETEKSI STATUS MODEM & MANAJEMEN BACKUP
    # ==============================================================================
    print_yellow(">>> [TAHAP 1/4] Memeriksa status koneksi perangkat (EDL 9008 / Fastboot)...")

    has_all_extracted = all(os.path.exists(os.path.join(extracted_dir, f"{p}.bin")) for p in REQUIRED_PARTS)

    # Cari file backup sebelumnya jika ada
    existing_backups = glob.glob(os.path.join(current_dir, "backup*.bin"))
    existing_backups.sort(key=os.path.getmtime, reverse=True)
    existing_backup = existing_backups[0] if existing_backups else None

    fastboot_ready = False

    # KONDISI 1: Perangkat SUDAH di Fastboot
    if check_fastboot_connected():
        print_green("[OK] Perangkat terdeteksi di mode Fastboot!")
        if not has_all_extracted and existing_backup:
            print()
            print_yellow(f"[!] Ditemukan file backup sebelumnya: {os.path.basename(existing_backup)}")
            ans = input("Apakah file ini adalah backup dari perangkat saat ini? (y/n, default: y): ").strip().lower()
            if ans in ['', 'y', 'yes']:
                success = extract_gpt_partitions(existing_backup, extracted_dir)
                if success:
                    fastboot_ready = True
                else:
                    print_red("[!] Gagal mengekstrak partisi dari backup lama. Wajib masuk mode EDL 9008.")
            else:
                print_yellow("[!] File backup dilewati. Wajib masuk mode EDL 9008 untuk membuat backup baru.")
        elif has_all_extracted:
            fastboot_ready = True

        if fastboot_ready:
            print_green("[OK] Seluruh partisi backup asli sudah siap.")
            print_green("[OK] Menyesuaikan kondisi: langsung melanjutkan proses flashing firmware...")

    # KONDISI 2: Belum Fastboot / Belum siap backup -> Wajib EDL 9008
    if not fastboot_ready:
        if check_fastboot_connected() and not existing_backup and not has_all_extracted:
            print()
            print_red("[!] Perangkat berada di mode Fastboot tetapi BELUM DITEMUKAN file backup eMMC!")
            print_yellow("[!] Untuk mengamankan partisi baseband (IMEI & sinyal 4G), perangkat WAJIB di-backup terlebih dahulu.")
            print("    -> Silakan cabut modem dari port USB.")
            print("    -> Tahan tombol fisik EDL (atau hubungkan titik test point EDL), lalu colokkan kembali ke port USB.")
            print()

        print("Menunggu modem dalam mode EDL (Qualcomm 9008)...")
        print("Tips: Tahan tombol EDL saat mencolokkan stik USB ke PC Windows.")

        while True:
            if check_edl_connected():
                print()
                print_green("[OK] Port EDL Qualcomm 9008 terdeteksi dan merespons!")
                break
            sys.stdout.write(".")
            sys.stdout.flush()
            time.sleep(2)

        # Proses Dump & Skip Backup di EDL
        full_backup_path = None
        skip_backup = False

        if existing_backup:
            print()
            print_yellow(f"[!] Ditemukan file backup sebelumnya: {os.path.basename(existing_backup)}")
            ans = input("Apakah file ini adalah backup dari perangkat saat ini? (y/n, default: y): ").strip().lower()
            if ans in ['', 'y', 'yes']:
                print_green("[OK] Menggunakan file backup yang ada. Proses dump EDL dilewati (skip backup)...")
                full_backup_path = existing_backup
                skip_backup = True

        if not skip_backup:
            timestamp = datetime.now().strftime("%Y_%m_%d_%H_%M")
            backup_name = f"backup_{timestamp}.bin"
            full_backup_path = os.path.join(current_dir, backup_name)
            print_blue(f"[*] Melakukan FULL RAW DUMP seluruh eMMC flash via edl -> {backup_name}...")
            run_cmd(f'edl rf "{full_backup_path}"')

        # Ekstrak partisi asli
        if full_backup_path and os.path.exists(full_backup_path):
            extract_gpt_partitions(full_backup_path, extracted_dir)
        else:
            print_blue("[*] Mencadangkan partisi individual via edl...")
            for p in REQUIRED_PARTS:
                out_p = os.path.join(extracted_dir, f"{p}.bin")
                print(f"    -> Dumping {p}...")
                run_cmd(f'edl r {p} "{out_p}"')

        print_blue("[*] Menyiapkan Fastboot direct jump via EDL...")
        print("    -> Menulis bootloader aboot...")
        run_cmd(f'edl w aboot "{os.path.join(base_dir, "aboot.bin")}"')
        print("    -> Mengosongkan partisi boot (force Fastboot mode)...")
        run_cmd("edl e boot")
        print("    -> Mengirim edl reset (langsung melompat ke Fastboot)...")
        run_cmd("edl reset", check=False)
        print_green("[OK] Reset terkirim, beralih langsung ke Fastboot mode...")
        time.sleep(3)

    # ==============================================================================
    # [TAHAP 2/4] VERIFIKASI FASTBOOT & FLASH BASE GENERIC
    # ==============================================================================
    print()
    print_yellow(">>> [TAHAP 2/4] Menunggu perangkat online di Fastboot mode...")
    while True:
        if check_fastboot_connected():
            break
        sys.stdout.write(".")
        sys.stdout.flush()
        time.sleep(1)
    print()
    print_green("[OK] Perangkat terdeteksi di Fastboot:")
    run_cmd("fastboot devices")
    print()

    print_yellow(">>> Flashing Base Generic Partitions...")
    gpt_both0 = os.path.join(base_dir, "gpt_both0.bin")
    if os.path.exists(gpt_both0):
        run_cmd(f'fastboot flash partition "{gpt_both0}"')
        run_cmd(f'fastboot flash hyp "{os.path.join(base_dir, "hyp.mbn")}"')
        run_cmd(f'fastboot flash rpm "{os.path.join(base_dir, "rpm.mbn")}"')
        run_cmd(f'fastboot flash sbl1 "{os.path.join(base_dir, "sbl1.mbn")}"')
        run_cmd(f'fastboot flash tz "{os.path.join(base_dir, "tz.mbn")}"')
        cdt_bin = os.path.join(base_dir, "sbc_1.0_8016.bin")
        if os.path.exists(cdt_bin):
            run_cmd(f'fastboot flash cdt "{cdt_bin}"')
        run_cmd("fastboot erase boot", check=False)
        run_cmd("fastboot erase rootfs", check=False)
    print_green("[OK] Tahap Base generic selesai!")

    # ==============================================================================
    # [TAHAP 3/4] DOWNLOAD & FLASH DEBIAN FIRMWARE (BOOKWORM / TRIXIE)
    # ==============================================================================
    print()
    print_yellow(f">>> [TAHAP 3/4] Menyiapkan & Flashing {distro_title}...")

    rootfs_bin = os.path.join(distro_dir, "rootfs.bin")
    boot_bin = os.path.join(distro_dir, "boot.bin")

    if not os.path.exists(rootfs_bin) or not os.path.exists(boot_bin):
        local_zip = os.path.join(downloads_dir, distro_zip)
        if not os.path.exists(local_zip) and os.path.exists(os.path.join(current_dir, distro_zip)):
            local_zip = os.path.join(current_dir, distro_zip)

        if not os.path.exists(local_zip):
            download_file_with_progress(distro_url, local_zip)

        print_blue(f"[*] Mengekstrak {local_zip} ke {distro_dir} via Python zipfile...")
        try:
            with zipfile.ZipFile(local_zip, 'r') as z:
                z.extractall(distro_dir)
            print_green("    [OK] Ekstraksi firmware berhasil!")
        except Exception as e:
            print_red(f"[!] Gagal mengekstrak berkas ZIP ({e}). Mengunduh ulang berkas...")
            if os.path.exists(local_zip):
                os.remove(local_zip)
            download_file_with_progress(distro_url, local_zip)
            with zipfile.ZipFile(local_zip, 'r') as z:
                z.extractall(distro_dir)
            print_green("    [OK] Ekstraksi firmware berhasil!")

    print_blue(f"[*] Flashing firmware {distro_title}...")
    run_cmd(f'fastboot flash partition "{os.path.join(distro_dir, "gpt_both0.bin")}"')
    run_cmd(f'fastboot flash aboot "{os.path.join(distro_dir, "aboot.mbn")}"')
    run_cmd(f'fastboot flash hyp "{os.path.join(distro_dir, "hyp.mbn")}"')
    run_cmd(f'fastboot flash rpm "{os.path.join(distro_dir, "rpm.mbn")}"')
    run_cmd(f'fastboot flash sbl1 "{os.path.join(distro_dir, "sbl1.mbn")}"')
    run_cmd(f'fastboot flash tz "{os.path.join(distro_dir, "tz.mbn")}"')
    run_cmd(f'fastboot flash boot "{os.path.join(distro_dir, "boot.bin")}"')
    run_cmd(f'fastboot -S 200M flash rootfs "{os.path.join(distro_dir, "rootfs.bin")}"')
    print_green(f"[OK] Firmware {distro_title} berhasil di-flash!")

    # ==============================================================================
    # [TAHAP 4/4] RESTORE ORIGINAL BASEBAND PARTITIONS & REBOOT
    # ==============================================================================
    print()
    print_yellow(">>> [TAHAP 4/4] Mengembalikan partisi asli dari folder extracted/...")
    for p in REQUIRED_PARTS:
        p_path = os.path.join(extracted_dir, f"{p}.bin")
        if os.path.exists(p_path):
            print_blue(f"    -> Flashing {p} ({p_path})...")
            run_cmd(f'fastboot flash {p} "{p_path}"')
        else:
            print_yellow(f"    [!] File {p_path} tidak ditemukan, melewati partisi {p}.")

    print()
    print_cyan("======================================================================")
    print_green("   PROSES FLASHING SELESAI! ME-REBOOT PERANGKAT KE LINUX...           ")
    print_cyan("======================================================================")
    print_blue("[*] Memulai boot ke sistem Linux (Direct Jump / Fastboot Continue)...")
    rc = run_cmd("fastboot continue", check=False)
    if rc != 0:
        run_cmd("fastboot reboot", check=False)

    print()
    print_green(f"[OK] Perangkat sedang booting ke sistem {distro_title}.")
    print()
    print_yellow("======================================================================")
    print_yellow("PENTING (POWER CYCLE USB):")
    print_yellow("  Jika dalam waktu 1 menit perangkat belum menyala (LED mati/belum terdeteksi),")
    print_yellow("  silakan CABUT dan COLOK KEMBALI stik USB Anda ke port PC!")
    print_yellow("======================================================================")
    print()
    print("Setelah booting selesai (~40 detik):")
    print("  - Wi-Fi Hotspot : SSID '4G-UFI-XX' (Password: 1234567890)")
    print("  - Koneksi USB   : RNDIS Network Adapter aktif otomatis")
    print("  - Login SSH     : ssh user@192.168.100.1 (Password: 1)")
    print("  - Akses ADB     : adb connect 192.168.100.1:5555 && adb shell")
    print()
    print_yellow("Setelah login, ketik 'sbrmenu' untuk mengelola Hotspot, Wi-Fi, dan USB Mode.")
    print_cyan("Untuk akses administrator: ketik 'sudo su' (Password: 1)")
    print_cyan("======================================================================")
    print()
    input("Tekan Enter untuk keluar...")

if __name__ == '__main__':
    main()
