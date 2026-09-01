# Panduan Instalasi Qualcomm EDL Tool (bkerler/edl) di Linux

Panduan ini menyediakan **2 metode** untuk menginstal **Qualcomm Sahara / Firehose EDL Tool (`bkerler/edl`)** pada berbagai distro Linux berbasis Debian (Ubuntu, Debian 11/12/13, Linux Mint, Raspberry Pi OS, Kali Linux, dsb.), serta mengonfigurasi perintah `edl` agar dapat dijalankan sebagai binary global dari direktori mana saja.

---

## Metode 1: Instalasi Otomatis (One-Liner Script — Rekomendasi)

Cukup buka terminal di Linux Anda, lalu salin dan jalankan **satu baris perintah** berikut:

```bash
curl -sSL https://raw.githubusercontent.com/jimmylpx/openstick/main/edl_autoinstall.sh | sudo bash
```

> **Catatan:** Skrip otomatis ini akan melakukan pembaruan repositori, instalasi dependensi, kloning submodul loader Qualcomm, pemasangan driver/udev rules, instalasi modul Python, penyalinan ke `/opt/edl`, dan konfigurasi binary global `/usr/local/bin/edl` secara instan.

---

## Metode 2: Instalasi Manual (Step-by-Step)

Jika Anda ingin melakukan instalasi langkah demi langkah secara manual, ikuti panduan berikut:

### 1. Instal Dependensi Sistem

Pastikan paket compiler dan pustaka pendukung USB telah terpasang:

```bash
sudo apt update
sudo apt install -y git curl wget python3 python3-pip python3-dev python3-setuptools \
    libusb-1.0-0 libusb-1.0-0-dev build-essential pkg-config android-sdk-platform-tools-common udev
```

---

### 2. Kloning Source Code & Submodules

Unduh repository resmi beserta submodul loader Qualcomm:

```bash
git clone https://github.com/bkerler/edl.git # do NOT use --recurse-submodules
cd edl
git submodule update --init --recursive
```

---

### 3. Pasang Driver Linux, Paket Python & Salin ke `/opt/edl`

Jalankan script driver bawaan, pasang paket Python `edlclient`, lalu salin folder ke `/opt/edl`:

```bash
chmod +x ./install-linux-edl-drivers.sh
sudo ./install-linux-edl-drivers.sh
pip3 install .
```

Jika muncul peringatan *externally-managed-environment*, gunakan:

```bash
pip3 install . --break-system-packages
```

Salin seluruh isi folder `edl` ke direktori sistem `/opt/edl`:

```bash
sudo mkdir -p /opt/edl
sudo cp -r . /opt/edl
```

---

### 4. Konfigurasi Binary Global `/usr/local/bin/edl`

Buat file wrapper `/usr/local/bin/edl`:

```bash
sudo nano /usr/local/bin/edl
```

Kemudian tempelkan (*paste*) kode di bawah ini:

```bash
#!/usr/bin/env bash
if [ -f "/opt/edl/edl.py" ]; then
    exec python3 /opt/edl/edl.py "$@"
else
    echo "Error: File /opt/edl/edl.py tidak ditemukan."
    exit 1
fi
```

Simpan file (pada nano: `Ctrl+O`, `Enter`, lalu `Ctrl+X`), kemudian berikan izin eksekusi:

```bash
sudo chmod +x /usr/local/bin/edl
```

---

## 5. Verifikasi & Pengujian

Setelah proses instalasi selesai (baik Metode 1 maupun Metode 2), Anda dapat menjalankan perintah `edl` langsung dari direktori mana saja di terminal:

```bash
# 1. Cek menu bantuan
edl --help

# 2. Cek koneksi perangkat Qualcomm EDL 9008
edl printgpt
```

---

> **Tips Izin Port USB:**  
> Jika saat menjalankan `edl` muncul kendala izin akses USB (*Permission denied*), pastikan akun user Anda telah dimasukkan ke grup `plugdev` & `dialout`:
> ```bash
> sudo usermod -aG plugdev,dialout $USER
> ```
> *(Lalu relog terminal atau jalankan `newgrp plugdev` agar izin langsung aktif).*
