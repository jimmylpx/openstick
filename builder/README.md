# OpenStick Debian Firmware Builder

Build system modular dan terverifikasi untuk membangun firmware kustom **OpenStick Qualcomm Snapdragon 410 (MSM8916)** berbasis **Debian GNU/Linux (ARM64)** secara mandiri.

Build system ini mengadopsi metode pembangunan dan in-place patching yang terbukti berhasil dan stabil pada hardware OpenStick fisik, mendukung 4 varian target:
1. **Debian 12 Bookworm (Standar)** — 4G LTE Modem aktif (RAM ~390MB).
2. **Debian 12 Bookworm (Modem-Disabled)** — Modem nonaktif, memori dimaksimalkan untuk server/homelab (RAM ~466MB).
3. **Debian 13 Trixie (Standar)** — 4G LTE Modem aktif dengan paket Debian 13 terbaru.
4. **Debian 13 Trixie (Modem-Disabled)** — Modem nonaktif pada Debian 13 (RAM ~466MB).

---

## Struktur Direktori

```text
builder/
├── build.sh                   # Script utama build otomatis
├── README.md                  # Panduan build & kustomisasi
├── base/                      # Base rootfs OpenStick terverifikasi (auto-download jika belum ada)
│   └── rootfs.bin             # Image ext4 kompatibel MSM8916 (732.356.608 bytes)
├── firmware/                  # Biner bootloader Qualcomm & kernel boot.bin
│   ├── aboot.mbn
│   ├── boot.bin               # Linux Kernel 6.12.x Standar (Modem Aktif)
│   ├── boot_modem_disabled.bin# Linux Kernel 6.12.x Modem-Disabled (~85MB reclaimed RAM)
│   ├── gpt_both0.bin, hyp.mbn, rpm.mbn, sbl1.mbn, tz.mbn
│   ├── modules.tar.gz         # Modul kernel Qualcomm MSM8916
│   └── firmware.tar.gz        # Firmware modem & Wi-Fi Qualcomm
├── overlay/                   # Filesystem overlay (diterapkan ke rootfs)
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
    ├── 01_prepare_base.sh     # Menyiapkan base rootfs terverifikasi
    ├── 02_apply_overlay.sh    # Pemasangan overlay, services, & konfigurasi distro
    ├── 03_build_kernel_boot.sh# Menyiapkan partisi bootloader & boot.bin
    └── 04_pack_release.sh     # Pengemasan file rilis zip siap flash
```

---

## 🛠️ Persyaratan Sistem Komputer Build

Build system ini berjalan di OS **Debian / Ubuntu / Linux Mint / Raspberry Pi OS (Linux x86_64 atau ARM64)**.

> [!TIP]
> **Otomatis:** Script `build.sh` sudah dilengkapi fitur **Auto Host Check & Installer**. Jika dependensi pendukung (`zip`, `unzip`, `curl`, `e2fsprogs`) belum terpasang, script akan otomatis memasangnya via `apt-get` saat dijalankan dengan `sudo`.

---

## Cara Membangun Firmware

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

File zip hasil kompilasi akan otomatis disimpan di folder `builder/output/`:
- `builder/output/bookworm.zip`
- `builder/output/bookworm-modem-disabled.zip`
- `builder/output/trixie.zip`
- `builder/output/trixie-modem-disabled.zip`
