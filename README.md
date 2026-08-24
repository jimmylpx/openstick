# OpenStick Snapdragon 410 (MSM8916) - Debian Linux Suite

[![Linux](https://img.shields.io/badge/OS-Debian%2012%20ARM64-red.svg)](https://www.debian.org/)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.12.x--msm8916-blue.svg)](https://github.com/msm8916-mainline)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/jimmylpx/openstick)](https://github.com/jimmylpx/openstick/releases/tag/v1)

Proyek ini bertujuan untuk mengubah dongle USB Modem 4G LTE berbasis prosesor **Qualcomm Snapdragon 410 (MSM8916)** (seperti board **HMUF02-V05**, **UZ801**, **UFI103S-V05**, dan varian sejenis) dari firmware Android bawaan pabrik menjadi **perangkat server Linux murni (Debian 12 Bookworm 64-bit)** yang hemat daya, stabil, dan kaya fitur.

---

## 🌟 Fitur Utama & Kustomisasi

- **🚀 Direct One-Click Installer (`installer.sh`)**:
  - Alur cepat & bersih: mendeteksi EDL 9008, backup partisi modem/IMEI asli, aktivasi root ADB, reboot bootloader, flash Base Generic, dan langsung mem-flash Debian 12 Bookworm kustom tanpa tahapan perantara yang berlebih.
  - Otomatis memulihkan seluruh partisi modem asli (`fsc`, `fsg`, `modem`, `modemst1`, `modemst2`, `persist`, `sec`) sehingga kartu SIM (Telkomsel, Indosat, XL, Tri, Smartfren) langsung aktif *out-of-the-box*.
- **🌐 Dynamic DHCP DNS & SUID Ping**:
  - DNS resolver otomatis mengikuti nameserver dinamis yang diberikan oleh DHCP router atau modem seluler tanpa konfigurasi manual.
  - Perintah `ping` dapat dijalankan langsung oleh akun pengguna biasa (`user`) tanpa kendala permission socket.
- **📊 Fastfetch & Hint `sbrmenu` Bawaan**:
  - Menampilkan ringkasan informasi sistem, status CPU, RAM, kernel, dan IP lokal via `fastfetch` secara otomatis saat login SSH, lengkap dengan panduan banner interaktif untuk menjalankan `sbrmenu`.
- **❄️ Manajemen Termal & Stabilitas**:
  - **4G LTE Nonaktif Secara Default**: Menjaga perangkat tetap dingin saat awal booting.
  - Saat 4G LTE diaktifkan, frekuensi CPU dikelola secara optimal agar suhu tetap stabil di **~53°C – 57°C**.
- **🔌 Pengatur Mode USB (Host OTG / Gadget)**:
  - **Gadget Mode (Default)**: Untuk dicolokkan ke Windows PC (RNDIS USB Ethernet).
  - **Host Mode (OTG)**: Untuk membaca Flashdisk, USB Hub, USB Ethernet, atau Keyboard.
- **🔒 DNSCrypt-Proxy (Cloudflare DoH)**:
  - Tersedia opsi DNS over HTTPS (DoH) terenkripsi via Cloudflare pada `127.0.0.1:5353`.
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

Pastikan komputer flasher (Linux / Raspberry Pi OS / Ubuntu / WSL2) telah menginstal dependensi:

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
Sebelum menjalankan script instalasi, perangkat harus dimasukkan ke mode **Qualcomm EDL (Emergency Download Mode 9008)**. Pilih metode sesuai dengan tipe board modem Anda:

#### Opsi A: Board HMUF02-V05 / UFI103S-V05 (Tombol EDL)
![Tombol EDL Mode](edl_button.jpg)
1. Cabut dongle USB modem dari komputer.
2. **Tekan dan tahan tombol kecil pada board** (lihat lingkaran merah pada gambar di atas).
3. Sambil tetap menahan tombol tersebut, **colokkan modem ke port USB komputer**.
4. **Tahan tombol selama ~5 detik** setelah dicolokkan, lalu lepaskan.

---

#### Opsi B: Board UZ801
Untuk board UZ801, terdapat **2 cara** untuk masuk ke mode EDL:

![UZ801 Short Pin](uz801_edl.png)

1. **Cara 1 (Software via Web Debug & ADB)**:
   - Hubungkan PC ke Wi-Fi modem atau colok via USB.
   - Buka browser dan akses alamat: `http://192.168.100.1/usbdebug.html` lalu tunggu hingga modem me-restart dirinya sendiri.
   - Buka terminal di PC Anda, lalu jalankan perintah:
     ```bash
     adb wait-for-device
     adb shell "setprop service.adb.root 1; busybox killall adbd"
     adb wait-for-device
     adb reboot edl
     ```
2. **Cara 2 (Hardware via Short Pin)**:
   - Cabut modem dari port USB.
   - Hubungkan (*short*) kedua pin test point yang berada di dalam **kotak merah** pada gambar di atas menggunakan pinset / kabel jumper.
   - Sambil menghubungkan pin tersebut, **colokkan modem ke port USB**.
   - Tunggu **~5 detik**, lalu lepaskan pinset/jumper.

> **Verifikasi Mode EDL:**  
> Jalankan perintah `lsusb` di terminal Linux. Pastikan muncul baris:  
> `05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)`.

---

### 2. Unduh Paket Base Flasher
```bash
wget https://github.com/jimmylpx/openstick/releases/download/v1/base-generic.zip
unzip base-generic.zip -d base
cd base
chmod +x installer.sh
```

---

### 3. Jalankan Installer Otomatis
```bash
./installer.sh
```

Script akan secara otomatis mengeksekusi tahapan berikut:
1. **Mendeteksi Mode EDL 9008 & Full Backup**: Melakukan backup penuh seluruh flash eMMC (`edl rf backup.bin`) dan mengekstrak partisi baseband asli (`fsc`, `fsg`, `modem`, `modemst1`, `modemst2`, `persist`, `sec`) ke folder `extracted/`.
2. **Direct Fastboot Jump (Tanpa ADB)**: Menulis bootloader aboot, mengosongkan partisi boot, dan mengeksekusi `edl reset` untuk langsung melompat ke mode Fastboot dalam ~3 detik.
3. **Flashing Base Generic**: Mem-flash partisi dasar dan partition table dari folder `base/`.
4. **Download & Flash Langsung Debian 12 Bookworm**: Mengunduh `bookworm.zip` dan mem-flash firmware Debian 12 Bookworm kustom lengkap.
5. **Restore Baseband Modem**: Mengembalikan seluruh partisi asli dari folder `extracted/`.
6. **Reboot ke Linux**: Me-reboot perangkat ke sistem operasi Debian Linux baru.

---

### ⚠️ 4. Penting Setelah Flashing Selesai (Re-Plug Perangkat)
Setelah proses flashing pada `installer.sh` selesai, perangkat biasanya akan berada dalam kondisi **unresponsive / diam**.

> **Wajib Dilakukan:**  
> **Cabut modem dari port USB komputer, kemudian colokkan kembali secara normal** (tanpa menekan tombol atau men-short pin) agar modem dapat melakukan cold boot dan melanjutkan proses booting ke Debian Linux!

---

## 🖥️ Cara Mengakses Perangkat Setelah Instalasi

Setelah modem dicolokkan kembali dan selesai booting (~40 detik), perangkat OpenStick dapat diakses melalui berbagai metode berikut:

### 🪟 1. Dari Windows PC
Anda dapat mengakses perangkat melalui 3 metode:
- **Metode A (Kabel USB — RNDIS Ethernet / SSH)**:
  Colokkan modem ke port USB PC Windows (driver *Remote NDIS Compatible Device* akan aktif secara otomatis). Buka PowerShell / CMD / PuTTY, lalu hubungkan via SSH:
  ```bash
  ssh user@192.168.100.1
  # Password: 1
  ```
- **Metode B (Kabel USB — ADB Shell)**:
  Buka CMD atau PowerShell di Windows, lalu jalankan:
  ```bash
  adb shell
  ```
  *(Sistem akan otomatis login sebagai `user`, menampilkan `fastfetch` dan banner petunjuk `sbrmenu`).*
- **Metode C (Koneksi Wi-Fi / Hotspot)**:
  Sambungkan Wi-Fi Windows ke Hotspot bawaan (**SSID:** `4G-UFI-XX`, **Password:** `1234567890`), lalu hubungkan via SSH:
  ```bash
  ssh user@192.168.100.1
  # Password: 1
  ```

---

### 🐧 2. Dari Linux PC / HP / Laptop
Anda dapat mengakses perangkat melalui 2 metode:
- **Metode A (Kabel USB — ADB Shell Langsung)**:
  Colokkan modem ke port USB PC Linux, buka terminal, lalu jalankan:
  ```bash
  adb shell
  ```
  *(Langsung login interaktif sebagai `user` lengkap dengan tampilan `fastfetch` dan banner `sbrmenu`).*
- **Metode B (Koneksi Wi-Fi / Hotspot / LAN)**:
  Sambungkan PC Linux atau Smartphone Anda ke Hotspot bawaan (**SSID:** `4G-UFI-XX`, **Password:** `1234567890`) atau pastikan berada di jaringan Wi-Fi lokal yang sama:
  ```bash
  # Jika terhubung ke Hotspot modem:
  ssh user@192.168.100.1

  # Atau jika modem terhubung ke Wi-Fi rumah:
  ssh user@<IP_LOKAL_MODEM>
  # Password: 1
  ```

---

### 🔑 Hak Akses Administrator (Root)
Untuk alasan keamanan, login langsung sebagai `root` via SSH dinonaktifkan secara default. Setelah login sebagai akun `user`, Anda dapat beralih ke root kapan saja dengan perintah:
```bash
sudo su
# Password: 1
```

---

### 🎛️ Mengelola Jaringan & Fitur (`sbrmenu`)
Setelah login ke terminal SSH modem, jalankan menu TUI interaktif:
```bash
sbrmenu
```
Ketik nomor menu untuk mengonfigurasi Hotspot, WiFi Client, 4G LTE, SMS Modem, DNSCrypt, Pi-hole, atau USB Mode sesuai kebutuhan.
