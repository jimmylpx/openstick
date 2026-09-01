# Panduan Instalasi Qualcomm EDL Tool (bkerler/edl) di Linux

Panduan langkah demi langkah untuk menginstal **Qualcomm Sahara / Firehose EDL Tool (`bkerler/edl`)** pada distro Linux berbasis Debian (Ubuntu, Debian 11/12/13, Linux Mint, Raspberry Pi OS, dsb.), serta mengonfigurasi perintah `edl` agar dapat dijalankan sebagai binary global dari direktori mana saja.

---

## 1. Instal Dependensi Sistem

Sebelum memulai, pastikan paket compiler dan pustaka pendukung USB telah terpasang:

```bash
sudo apt update
sudo apt install -y git curl wget python3 python3-pip python3-dev python3-setuptools \
    libusb-1.0-0 libusb-1.0-0-dev build-essential pkg-config android-sdk-platform-tools-common udev
```

---

## 2. Kloning Source Code & Submodules

Unduh repository resmi beserta submodul loader Qualcomm:

```bash
git clone https://github.com/bkerler/edl.git # do NOT use --recurse-submodules
cd edl
git submodule update --init --recursive
```

---

## 3. Pasang Driver Linux, Paket Python & Salin ke `/opt/edl`

Jalankan script driver bawaan, pasang paket Python `edlclient`, lalu salin folder ke `/opt/edl`:

```bash
chmod +x ./install-linux-edl-drivers.sh
sudo ./install-linux-edl-drivers.sh
pip3 install .
```

Jika muncul error *externally-managed-environment*, gunakan:

```bash
pip3 install . --break-system-packages
```

Salin seluruh isi folder `edl` ke direktori sistem `/opt/edl`:

```bash
sudo mkdir -p /opt/edl
sudo cp -r . /opt/edl
```

---

## 4. Konfigurasi Binary Global `/usr/local/bin/edl`

Buat file /usr/local/bin/edl:

```bash
sudo nano /usr/local/bin/edl
```

Kemudian paste kode bawah ini untuk membuat wrapper global:

```bash
#!/usr/bin/env bash
if [ -f "/opt/edl/edl.py" ]; then
    exec python3 /opt/edl/edl.py "$@"
else
    echo "Error: File /opt/edl/edl.py tidak ditemukan."
    exit 1
fi
```

Setelah selesai, lakukan chmod:

```bash
sudo chmod +x /usr/local/bin/edl
```

---

## 5. Verifikasi & Pengujian

Sekarang Anda dapat menjalankan perintah `edl` langsung dari direktori mana saja di terminal:

```bash
# 1. Cek menu bantuan
edl --help

# 2. Cek koneksi perangkat Qualcomm EDL 9008
edl printgpt
```

---

> **Tips Izin Port USB:**  
> Jika saat menjalankan `edl` muncul kendala izin akses USB, pastikan user Anda telah dimasukkan ke grup `plugdev` & `dialout`:
> ```bash
> sudo usermod -aG plugdev,dialout $USER
> ```
> *(Lalu relog terminal atau jalankan `newgrp plugdev`).*
