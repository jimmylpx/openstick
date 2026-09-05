# OpenStick Debian Firmware Builder

Build system modular dan terverifikasi untuk membangun dan mengkustomisasi firmware **OpenStick Qualcomm Snapdragon 410 (MSM8916)** berbasis **Debian GNU/Linux (ARM64)** secara mandiri langsung dari repositori GitHub.

---

## 🎨 Apa Saja yang Bisa Dikustomisasi oleh Pengguna?

Builder ini dirancang sangat modular agar siapa saja dapat membuat varian Linux sesuai kebutuhan homelab atau server mereka tanpa merusak kompatibilitas hardware:

### 1. Menambah / Mengubah File Sistem (`builder/overlay/`)
Struktur folder di dalam `builder/overlay/` mencerminkan struktur root Linux (`/`). Setiap file atau folder yang Anda letakkan di sini akan langsung ditimpa (*overlay*) ke dalam sistem operasi target:
- **Layanan Systemd Baru:** Letakkan file `.service` di `builder/overlay/etc/systemd/system/`.
- **Script / Biner Eksekusi:** Letakkan skrip Anda di `builder/overlay/usr/local/bin/` (akan otomatis diberi izin `chmod +x`).
- **Konfigurasi Jaringan & Wi-Fi:** Ubah koneksi default di `builder/overlay/etc/NetworkManager/system-connections/`.
- **MOTD / Login Banner:** Edit `builder/overlay/etc/profile.d/00-motd-fastfetch.sh`.
- **Menu TUI:** Ubah atau tambahkan menu di `builder/overlay/usr/local/bin/sbrmenu`.

### 2. Memasang Paket Debian Tambahan (`builder/config/custom_packages.list`)
Ingin menyertakan aplikasi seperti `docker`, `nginx`, `tmux`, `python3-pip`, `wireguard`, atau `iperf3` ke dalam image?
1. Buat file `builder/config/custom_packages.list` (tersedia template `custom_packages.list.example`).
2. Tulis nama paket Debian (satu per baris).
3. Saat Anda menjalankan `./build.sh`, builder akan otomatis memasang paket-paket tersebut ke dalam image firmware menggunakan emulator QEMU ARM64.

### 3. Skrip Hook Otomatisasi (`builder/hooks/custom.sh`)
Jika Anda membutuhkan perintah shell kustom yang dieksekusi di dalam rootfs sebelum firmware dikemas (misalnya membuat user baru, mengatur password default kustom, clone repo git, mengaktifkan service tertentu):
1. Buat file `builder/hooks/custom.sh` (tersedia template `custom.sh.example`).
2. Beri izin eksekusi (`chmod +x builder/hooks/custom.sh`).
3. Skrip akan dijalankan secara otomatis di dalam chroot ARM64.

### 4. Mengganti Kernel / Device Tree (`builder/firmware/`)
Jika Anda memiliki kernel Linux kustom atau file Device Tree (`.dtb`) untuk varian modem stick Snapdragon 410 baru, Anda cukup mengganti file `boot.bin` atau `boot_modem_disabled.bin` di folder `builder/firmware/`.

---

## 📁 Struktur Direktori

```text
builder/
├── build.sh                   # Script utama build otomatis
├── README.md                  # Panduan build & kustomisasi
├── base/                      # Base rootfs OpenStick terverifikasi (auto-download saat pertama kali build)
│   └── rootfs.bin             # Image ext4 kompatibel MSM8916 (732.356.608 bytes)
├── config/
│   ├── packages.list          # Daftar paket esensial bawaan distro
│   └── custom_packages.list   # (Opsional) Daftar paket tambahan kustom pengguna
├── firmware/                  # Biner bootloader Qualcomm & kernel boot.bin
│   ├── aboot.mbn
│   ├── boot.bin               # Linux Kernel 6.12.x Standar (Modem Aktif)
│   ├── boot_modem_disabled.bin# Linux Kernel 6.12.x Modem-Disabled (~85MB reclaimed RAM)
│   └── gpt_both0.bin, hyp.mbn, rpm.mbn, sbl1.mbn, tz.mbn
├── hooks/
│   ├── custom.sh.example      # Template hook eksekusi kustom pengguna
│   └── custom.sh              # (Opsional) Skrip hook kustom Anda
├── overlay/                   # Filesystem overlay (diterapkan ke rootfs)
│   ├── etc/
│   │   ├── profile.d/         # MOTD banner & info fastfetch
│   │   ├── systemd/system/    # Layanan systemd kustom (adbd, watchdog, usb-gadget)
│   │   └── NetworkManager/    # Konfigurasi hotspot, wifi, lte
│   ├── opt/dnscrypt-proxy/    # Biner DNSCrypt-Proxy DoH
│   └── usr/local/bin/         # sbrmenu, py_adbd.py, openstick-wifi-watchdog
└── scripts/
    ├── 01_prepare_base.sh     # Menyiapkan base rootfs terverifikasi
    ├── 02_apply_overlay.sh    # Pemasangan overlay, paket kustom, & konfigurasi distro
    ├── 03_build_kernel_boot.sh# Menyiapkan partisi bootloader & boot.bin
    └── 04_pack_release.sh     # Pengemasan file rilis zip siap flash
```

---

## 🚀 Cara Membangun Firmware

Jalankan `build.sh` dengan memilih target varian yang diinginkan:

### 1. Build Debian 12 Bookworm Standar:
```bash
sudo ./build.sh --target bookworm
```

### 2. Build Debian 12 Bookworm Modem-Disabled (Max RAM):
```bash
sudo ./build.sh --target bookworm-modem-disabled
```

### 3. Build Debian 13 Trixie Standar:
```bash
sudo ./build.sh --target trixie
```

### 4. Build Debian 13 Trixie Modem-Disabled (Max RAM):
```bash
sudo ./build.sh --target trixie-modem-disabled
```

### 5. Build Seluruh 4 Varian Sekaligus:
```bash
sudo ./build.sh --target all
```

File zip hasil kompilasi akan otomatis disimpan di folder `builder/output/`:
- `builder/output/bookworm.zip`
- `builder/output/bookworm-modem-disabled.zip`
- `builder/output/trixie.zip`
- `builder/output/trixie-modem-disabled.zip`
