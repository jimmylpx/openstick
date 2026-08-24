# OpenStick: Transform 4G USB Modem (Snapdragon 410 / MSM8916) into Linux Server

[![Linux](https://img.shields.io/badge/OS-Debian%2012%20Bookworm%20ARM64-red.svg)](https://www.debian.org/)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.12.x--msm8916-blue.svg)](https://github.com/msm8916-mainline)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/jimmylpx/openstick)](https://github.com/jimmylpx/openstick/releases/tag/v1)

Proyek ini bertujuan untuk mengubah dongle USB Modem 4G LTE berbasis prosesor **Qualcomm Snapdragon 410 (MSM8916)** (seperti board **HMUF02-V05**, **UZ801**, dan varian sejenis) dari firmware Android bawaan pabrik menjadi **perangkat server Linux murni (Debian 12 Bookworm 64-bit)** yang hemat daya, stabil, dan kaya fitur.

---

## 🌟 Fitur Utama

- **🚀 One-Click Automated Installer (`installer.sh`)**:
  - Otomatis melakukan backup full firmware asli (`HM.bin`) via Qualcomm EDL 9008.
  - Mengekstrak partisi baseband & EFS asli (`fsc`, `fsg`, `modem`, `modemst1`, `modemst2`, `persist`, `sec`) secara dinamis langsung dari GPT dump.
  - Mem-flash bootloader Qualcomm, CDT, kernel mainline Linux 6.12, dan Debian 12 rootfs.
  - Memulihkan seluruh partisi modem asli sehingga SIM card (Telkomsel, Indosat, XL, Tri, Smartfren) langsung aktif *out-of-the-box*.
- **🛡️ Pre-flight Dependency Check**: Memeriksa ketersediaan tool `adb`, `fastboot`, `edl`, `python3`, `unzip`, dan `wget` sebelum proses flashing dimulai.
- **❄️ Manajemen Termal Cerdas (Anti-Overheat & Anti-Restart)**:
  - **4G LTE Nonaktif Secara Default**: Menjaga perangkat tetap dingin saat awal booting.
  - **Dynamic Thermal Throttling**: Ketika 4G LTE diaktifkan, daemon termal otomatis mematikan Core 2 & 3 (*core offlining*) dan membatasi frekuensi Core 0 & 1 (800MHz/400MHz) sehingga suhu tetap stabil di kisaran **~53°C – 57°C**.
  - Saat 4G LTE dimatikan, semua 4 Core CPU otomatis dipulihkan ke kecepatan penuh (1.0 GHz).
- **🔌 Pengatur Mode USB (Host OTG / Gadget / Auto-Detect)**:
  - **Gadget Mode**: Untuk dicolokkan ke PC/Laptop (Network RNDIS + ADB).
  - **Host Mode (OTG)**: Untuk membaca Flashdisk, USB Hub, USB Ethernet, atau Keyboard.
  - **Auto-Detect**: Otomatis mendeteksi role saat dicolokkan ke PC Host.
- **📱 ADB Debugging Bawaan (Network & USB)**:
  - Akses shell ADB via jaringan: `adb connect 192.168.100.1:5555` $\rightarrow$ `adb shell`.
  - Akses shell ADB native langsung saat dicolokkan ke port USB.
- **🎛️ `sbrmenu` — TUI Network & Hardware Manager**:
  Menu interaktif berbasis TUI (`whiptail`) yang dapat dijalankan kapan saja dengan mengetik `sbrmenu`:
  1. **Buat Hotspot**: Konfigurasi SSID & Password WPA2 Personal, di-bridge ke `br0`.
  2. **Aktifkan Wi-Fi Client**: Terhubung ke Wi-Fi luar dengan proteksi *auto-fallback* ke hotspot darurat jika gagal.
  3. **Toggle 4G LTE**: Mengaktifkan/mematikan koneksi seluler & konfigurasi APN.
  4. **Papan Chat SMS Modem**: Membaca inbox/outbox per-kontak serta mengirim dan membalas SMS langsung dari modem.
  5. **Aktivasi DNSCrypt-Proxy**: Mengaktifkan Cloudflare DoH terenkripsi pada `127.0.0.1:5353`.
  6. **Installer Pi-hole**: Instalasi ad-blocker Pi-hole secara interaktif.
  7. **Atur Mode USB**: Beralih antara mode Host OTG, Gadget, atau set default boot permanen.

---

## 🛠️ Persyaratan Sistem & Alat

Pastikan komputer flasher (Linux / Raspberry Pi OS / Ubuntu / WSL2) telah menginstal dependensi berikut:

### Debian / Ubuntu / Raspberry Pi OS:
```bash
sudo apt update
sudo apt install -y adb fastboot python3 python3-pip unzip wget
pip3 install edl   # Atau clone dari https://github.com/bkerler/edl
```

### Arch Linux:
```bash
sudo pacman -S android-tools python unzip wget
# Install edl via AUR: yay -S edl-git
```

---

## 📥 Panduan Instalasi (Step-by-Step)

### 1. Masuk ke Mode EDL 9008
- Cabut dongle USB modem.
- Tekan dan tahan tombol recovery / hubungkan pin test-point EDL (*Short Test Point* D+ / GND sesuai tipe board) lalu colokkan ke port USB PC.
- Pastikan perangkat terdeteksi sebagai `05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)` saat dicek dengan perintah `lsusb`.

### 2. Unduh Paket Base Flasher
```bash
wget https://github.com/jimmylpx/openstick/releases/download/v1/hmuf02-v05.zip
unzip hmuf02-v05.zip
cd base
chmod +x installer.sh
```

### 3. Jalankan Installer Otomatis
```bash
./installer.sh
```

Script akan mengeksekusi seluruh tahapan:
1. Memeriksa dependensi sistem (`adb`, `fastboot`, `edl`).
2. Membuat full backup `HM.bin` dari eMMC dan me-reset modem.
3. Mengekstrak partisi baseband/modem asli.
4. Menyalakan root pada ADB dan reboot ke fastboot.
5. Mem-flash bootloader Qualcomm & konfigurasi CDT.
6. Mengunduh dan mem-flash OS Debian 12 kustom (`openstick-debian.zip`).
7. Memulihkan seluruh partisi modem asli dari dump.
8. Melakukan final reboot ke Debian Linux.

---

## 🖥️ Cara Mengakses Perangkat Setelah Instalasi

Setelah instalasi selesai dan modem selesai booting:

### 1. Akses via SSH (USB Ethernet / Wi-Fi)
- **IP Default**: `192.168.100.1`
- **Username**: `user` (Password: `1`) atau `root` (Password: `1`)
```bash
ssh user@192.168.100.1
```

### 2. Akses via ADB
```bash
adb connect 192.168.100.1:5555
adb shell
```

### 3. Menjalankan TUI Manager
Cukup ketik:
```bash
sbrmenu
```

---

## 📂 Struktur Direktori Repository

```text
.
├── base/
│   ├── installer.sh              # Master installer script
│   ├── extract_hm_partitions.py  # Ekstraktor partisi modem dari dump GPT HM.bin
│   ├── flash.sh                  # Flasher bootloader Qualcomm & CDT
│   └── [File MBN SoC: aboot.bin, gpt_both0.bin, hyp.mbn, rpm.mbn, sbl1.mbn, tz.mbn, sbc_*.bin]
├── openstick-debian.zip          # Image OS Debian 12 kustom (dikelola via Git LFS)
└── README.md
```

---

## 🙏 Ucapan Terima Kasih & Kredit

- **[OpenStick Project](https://github.com/OpenStick/OpenStick)** oleh *HandsomeYingyan*
- **[OpenStick-Builder](https://github.com/LongQT-sea/OpenStick-Builder)** oleh *LongQT-sea*
- **[Linux MSM8916 Mainline](https://github.com/msm8916-mainline)**
- **[bkerler/edl](https://github.com/bkerler/edl)** oleh *B. Kerler*
- **[DNSCrypt](https://github.com/DNSCrypt/dnscrypt-proxy)**
