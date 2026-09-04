# Panduan Instalasi ADB, Fastboot & Qualcomm EDL Tool di Windows

Dokumen ini menjelaskan cara mudah dan otomatis menginstal **Android Platform-Tools (ADB & Fastboot)** serta **Qualcomm Sahara / Firehose EDL Tool (`bkerler/edl`)** di sistem operasi **Windows 10 / Windows 11 (64-bit)** menggunakan skrip otomatis [`install_adb_fastboot_edl.ps1`](install_adb_fastboot_edl.ps1).

Setelah penginstalan selesai, perintah `adb`, `fastboot`, dan `edl` dapat langsung dipanggil dari Command Prompt (CMD) atau PowerShell mana saja.

---

## Fitur Skrip Auto-Installer

Skrip PowerShell [`install_adb_fastboot_edl.ps1`](install_adb_fastboot_edl.ps1) melakukan seluruh konfigurasi secara otomatis:
1. **Memasang Python 3 & Git for Windows** (jika belum terpasang).
2. **Mengunduh Google Android Platform-Tools resmi** (`adb.exe` dan `fastboot.exe`).
3. **Mengkloning repository resmi `bkerler/edl`** lengkap beserta submodul loader Qualcomm.
4. **Memasang dependensi Python** (`pyusb`, `pyserial`, `capstone`, `pycryptodome`, dll.).
5. **Mendaftarkan Environment Variable `PATH` sistem secara permanen** ke `C:\OpenStick_Tools\platform-tools` dan `C:\OpenStick_Tools\edl`.
6. **Menyiapkan UsbDk & Zadig (Driver WinUSB Installer)** untuk mengaktifkan komunikasi USB mode EDL 9008 di Windows.

---

## Cara Instalasi Cepat (1-Langkah)

### Metode 1: Jalankan Langsung dari Terminal PowerShell (Rekomendasi)

1. Klik kanan pada tombol **Start Windows** (ikon Windows di taskbar).
2. Pilih **Terminal (Admin)** atau **PowerShell (Run as Administrator)**.
3. Jalankan perintah satu baris berikut untuk mengunduh dan mengeksekusi installer:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; iex (irm https://raw.githubusercontent.com/jimmylpx/openstick/main/install_adb_fastboot_edl.ps1)
```

---

### Metode 2: Jalankan dari Berkas Lokal

Jika Anda sudah mengkloning atau mengunduh repository OpenStick:

1. Buka folder proyek di File Explorer.
2. Klik kanan pada berkas [`install_adb_fastboot_edl.ps1`](install_adb_fastboot_edl.ps1) $\rightarrow$ Pilih **Run with PowerShell**.
3. Jika muncul jendela peringatan UAC (Administrator), klik **Yes**.
4. Biarkan proses penginstalan berjalan hingga muncul pesan hijau:
   ```text
   ======================================================================
                 INSTALASI TOOLS SELESAI DENGAN SUKSES!                  
   ======================================================================
   ```

---

## Konfigurasi Driver Qualcomm EDL 9008 di Windows

Setelah tools terpasang, saat Anda menghubungkan OpenStick dalam mode EDL (Qualcomm 9008), Windows memerlukan driver **WinUSB** agar Python dan tool `edl` dapat berkomunikasi langsung ke port USB tanpa hambatan virtual serial port.

### Langkah Pasang Driver WinUSB via Zadig:

1. Colokkan OpenStick ke port USB komputer dalam mode EDL, bisa lihat [`dsini`](https://github.com/jimmylpx/openstick/#1-masuk-ke-edl-9008)
2. Buka aplikasi **Zadig** (sudah otomatis diunduh ke `C:\OpenStick_Tools\zadig.exe`).
3. Pada menu atas Zadig, klik **Options** $\rightarrow$ Centang **List All Devices**.
4. Pada menu *dropdown*, pilih perangkat yang bertuliskan:
   - `QHSUSB__BULK` atau `Qualcomm HS-USB QDLoader 9008`.
5. Di sebelah kanan panah hijau (Target Driver), pastikan terpilih:
   - **`WinUSB (v6.x.xxxx.xxxxx)`**
6. Klik tombol **Install Driver** (atau **Replace Driver**).
7. Tunggu beberapa detik hingga proses instalasi driver selesai.

---

## Pengujian & Verifikasi Perintah

Buka jendela Command Prompt (CMD) atau PowerShell **baru**, lalu jalankan perintah berikut untuk memastikan semua tool telah siap:

### 1. Uji ADB
```cmd
adb version
```
*Hasil yang diharapkan: Menampilkan versi Android Debug Bridge.*

### 2. Uji Fastboot
```cmd
fastboot --version
```
*Hasil yang diharapkan: Menampilkan versi fastboot.*

### 3. Uji Qualcomm EDL
```cmd
edl --help
```
*Hasil yang diharapkan: Menampilkan daftar perintah Qualcomm Firehose / Sahara client.*

Jika OpenStick sudah dicolokkan dalam mode EDL 9008:
```cmd
edl printgpt
```
*Hasil yang diharapkan: Tool akan mendeteksi chipset Snapdragon 410 (MSM8916), memuat loader otomatis, dan mencetak tabel partisi eMMC.*

---

## Langkah Berikutnya

Setelah ADB, Fastboot, dan EDL siap di Windows:
- Buka folder `base-generic` dan klik dua kali **`installer.bat`** (atau jalankan `python win_installer.py`) untuk memulai proses flashing firmware Debian OpenStick secara otomatis satu-klik langsung dari Windows.


