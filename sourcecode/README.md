# OpenStick Build System & Source Tree

Source code dan build system modular untuk membangun firmware kustom **OpenStick Qualcomm Snapdragon 410 (MSM8916)** berbasis **Debian GNU/Linux (ARM64)** secara mandiri.

Build system ini dirancang agar developer atau komunitas dapat:
1. Menambahkan paket, driver, atau fitur baru ke dalam *filesystem* (`rootfs.bin`).
2. Melakukan kustomisasi menu TUI (`sbrmenu`), daemon ADB (`py_adbd.py`), atau layanan USB Gadget.
3. Memilih versi distro target (**Debian 12 Bookworm** atau **Debian 13 Trixie**).
4. Menghasilkan paket rilis biner siap flash (`.zip`) secara otomatis.

---

## 📁 Struktur Direktori

```text
sourcecode/
├── build.sh                   # Script utama build otomatis
├── installer.sh               # Script installer & flasher OpenStick
├── README.md                  # Panduan build & kustomisasi
├── config/
│   └── packages.list          # Daftar paket Debian yang akan diinstal
├── overlay/                   # Filesystem overlay (ditimpa ke / di rootfs)
│   ├── etc/
│   │   ├── systemd/system/
│   │   │   ├── adbd.service            # Layanan daemon ADB isolated (User level)
│   │   │   ├── resize-rootfs.service   # Layanan auto-expand filesystem (~3.5 GB)
│   │   │   └── usb-gadget-rndis.service# Layanan USB Gadget RNDIS network
│   │   └── udev/rules.d/
│   │       └── 99-qualcomm.rules       # Aturan izin USB Modem Qualcomm
│   └── usr/
│       ├── local/bin/
│       │   ├── py_adbd.py              # Zero-Auth ADB Daemon (Controlling PTY)
│       │   └── sbrmenu                 # TUI Network & Hardware Manager (Default path)
│       └── sbin/
│           └── usb-gadget-rndis        # Script inisialisasi USB RNDIS & IP
└── scripts/
    ├── 01_bootstrap_rootfs.sh # Pembuatan base rootfs via debootstrap / chroot
    ├── 02_apply_overlay.sh    # Pemasangan layanan OpenStick & konfigurasi user
    ├── 03_build_kernel_boot.sh# Perakitan boot.bin (Kernel + DTB + Initramfs)
    └── 04_pack_release.sh     # Pengemasan file rilis zip siap flash
```

---

## 🛠️ Persyaratan Sistem Komputer Build

Disarankan menggunakan OS **Debian / Ubuntu / Raspberry Pi OS (Linux x86_64 atau ARM64)**:

```bash
sudo apt update
sudo apt install -y debootstrap qemu-user-static binfmt-support   e2fsprogs zip unzip wget curl rsync abootimg parted python3
```

---

## 🚀 Cara Membangun Firmware

### 1. Build Versi Standar (Debian 12 Bookworm - Stabil):
```bash
sudo ./build.sh --distro bookworm
```

### 2. Build Versi Eksperimental (Debian 13 Trixie):
```bash
sudo ./build.sh --distro trixie
```

---

## 📦 Output Hasil Build

Setelah proses selesai, file rilis akan dibuat di direktori `output/`:
- `output/bookworm.zip` (atau `output/trixie.zip`)
  - `aboot.mbn` (LK Bootloader)
  - `boot.bin` (Linux Kernel Mainline 6.12.x + DTB)
  - `gpt_both0.bin` (Partition Table)
  - `hyp.mbn`, `rpm.mbn`, `sbl1.mbn`, `tz.mbn` (Firmware TrustZone & Bootloader dasar)
  - `rootfs.bin` (Sistem Operasi Debian 698MB ext4)

File `.zip` ini siap digunakan langsung dengan script `installer.sh` bawaan proyek.
