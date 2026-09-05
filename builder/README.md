# OpenStick Debian Firmware Builder

Source code dan build system modular untuk membangun firmware kustom **OpenStick Qualcomm Snapdragon 410 (MSM8916)** berbasis **Debian GNU/Linux (ARM64)** secara mandiri.

Build system ini mendukung 4 varian target:
1. **Debian 12 Bookworm (Standar)** — 4G LTE Modem aktif (RAM ~390MB).
2. **Debian 12 Bookworm (Modem-Disabled)** — Modem nonaktif, memori dimaksimalkan untuk server/homelab (RAM ~466MB).
3. **Debian 13 Trixie (Standar)** — 4G LTE Modem aktif dengan paket Debian 13 terbaru.
4. **Debian 13 Trixie (Modem-Disabled)** — Modem nonaktif pada Debian 13 (RAM ~466MB).

---

## 📁 Struktur Direktori

```text
builder/
├── build.sh                   # Script utama build otomatis
├── README.md                  # Panduan build & kustomisasi
├── config/
│   └── packages.list          # Daftar paket Debian yang akan diinstal
├── overlay/                   # Filesystem overlay (ditimpa ke / di rootfs)
│   ├── etc/
│   │   ├── profile.d/
│   │   │   └── 00-motd-fastfetch.sh        # MOTD banner & info fastfetch
│   │   ├── systemd/system/
│   │   │   ├── adbd.service                # Layanan daemon ADB (User level)
│   │   │   ├── openstick-wifi-watchdog.service # Auto fallback Wi-Fi
│   │   │   ├── resize-rootfs.service       # Layanan auto-expand filesystem (~3.5 GB)
│   │   │   ├── usb-gadget-rndis.service    # Layanan USB Gadget RNDIS network
│   │   │   └── usb-mode-init.service       # Inisialisasi hardware role USB
│   │   └── udev/rules.d/
│   │       └── 99-qualcomm.rules           # Aturan izin USB Modem Qualcomm
│   └── usr/
│       ├── local/bin/
│       │   ├── openstick-wifi-watchdog     # Skrip watchdog Wi-Fi client / hotspot
│       │   ├── py_adbd.py                  # Zero-Auth ADB Daemon
│       │   ├── sbrmenu                     # TUI Manager Versi Standar (4G/SMS)
│       │   ├── sbrmenu_modem_disabled      # TUI Manager Versi Modem-Disabled
│       │   └── usb-mode-init               # Skrip switch mode host / gadget
│       └── sbin/
│           └── usb-gadget-rndis            # Skrip inisialisasi USB RNDIS & IP
└── scripts/
    ├── 01_bootstrap_rootfs.sh # Pembuatan base rootfs via debootstrap / chroot
    ├── 02_apply_overlay.sh    # Pemasangan overlay, services, & konfigurasi distro
    ├── 03_build_kernel_boot.sh# Menyiapkan partisi bootloader & boot.bin
    └── 04_pack_release.sh     # Pengemasan file rilis zip siap flash
```

> **Catatan:** Skrip installer (`installer.sh`, `installer.bat`, dan `win_installer.py`) tidak disimpan di folder builder ini karena sudah tersedia dan dikemas secara resmi di dalam paket **[base-generic.zip](https://github.com/jimmylpx/openstick/releases/download/v1/base-generic.zip)**.

---

## 🛠️ Persyaratan Sistem Komputer Build

Build system ini berjalan di OS **Debian / Ubuntu / Linux Mint / Raspberry Pi OS (Linux x86_64 atau ARM64)**.

> [!TIP]
> **Otomatis:** Script `build.sh` sudah dilengkapi fitur **Auto Host Check & Installer**. Jika ada dependensi yang belum terpasang di komputer Anda (seperti `debootstrap`, `qemu-user-static`, `binfmt-support`, dll.), script akan **otomatis memasangnya via `apt-get`** saat pertama kali dijalankan dengan `sudo`.

Jika Anda ingin memasang seluruh dependensi secara manual terlebih dahulu, jalankan:

```bash
sudo apt update
sudo apt install -y debootstrap qemu-user-static binfmt-support e2fsprogs zip unzip wget curl rsync parted python3
```

---

## 🚀 Cara Membangun Firmware

Jalankan `build.sh` dengan memilih target varian yang diinginkan:

### 1. Build Debian 12 Bookworm Standar:
```bash
sudo ./build.sh --target bookworm
```

### 2. Build Debian 12 Bookworm Modem-Disabled:
```bash
sudo ./build.sh --target bookworm-modem-disabled
```

### 3. Build Debian 13 Trixie Standar:
```bash
sudo ./build.sh --target trixie
```

### 4. Build Debian 13 Trixie Modem-Disabled:
```bash
sudo ./build.sh --target trixie-modem-disabled
```

### 5. Build Seluruh Varian Sekaligus:
```bash
sudo ./build.sh --target all
```

### ⚡ Mode Build:
* **Mode Default (Rekomendasi - Cepat & Stabil):** Menggunakan template base rootfs terverifikasi dengan driver kernel MSM8916 & firmware modem/Wi-Fi resmi. Build hanya membutuhkan waktu **~20–30 detik**.
* **Mode Dari Nol (`--from-scratch`):** Menjalankan bootstrap murni dari repositori Debian via `debootstrap` (memerlukan koneksi internet dan waktu ekstra untuk kompilasi/unpack di QEMU).
  ```bash
  sudo ./build.sh --target bookworm --from-scratch
  ```

---

## 📦 Output Hasil Build

Setelah proses selesai, file rilis akan dibuat di direktori `output/`:
- `output/<target>.zip` (misalnya `output/bookworm-modem-disabled.zip`)
  - `aboot.mbn` (LK Bootloader)
  - `boot.bin` (Linux Kernel Mainline 6.12.x + DTB)
  - `gpt_both0.bin` (Partition Table)
  - `hyp.mbn`, `rpm.mbn`, `sbl1.mbn`, `tz.mbn` (Firmware TrustZone & Bootloader dasar)
  - `rootfs.bin` (Sistem Operasi Debian 698MB ext4)

File `.zip` ini siap digunakan langsung dengan flasher bawaan dari `base-generic.zip`.
