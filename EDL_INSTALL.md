# 🛠️ Panduan Instalasi Qualcomm EDL Tool (bkerler/edl) di Linux

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

## 3. Pasang Driver Linux & Paket Python

Jalankan script driver bawaan dan pasang paket Python `edlclient`:

```bash
chmod +x ./install-linux-edl-drivers.sh
sudo ./install-linux-edl-drivers.sh
pip3 install .
```

Jika gagal, gunakan:

```bash
pip3 install . --break-system-packages
```

---

## 4. Konfigurasi Binary Global `/usr/local/bin/edl`

Pindah ke akun **root** terlebih dahulu:

```bash
sudo su
```

Kemudian jalankan perintah di bawah ini untuk membuat wrapper global:

```bash
cat << 'EOF' > /usr/local/bin/edl
#!/usr/bin/env bash
if [ -f "/opt/edl/edl.py" ]; then
    exec python3 /opt/edl/edl.py "$@"
elif [ -f "$HOME/edl/edl.py" ]; then
    exec python3 "$HOME/edl/edl.py" "$@"
elif command -v python3 &>/dev/null; then
    exec python3 -m edlclient.edl "$@"
else
    echo "Error: Python3 atau EDL source tidak ditemukan."
    exit 1
fi
EOF

chmod 755 /usr/local/bin/edl
```

Setelah selesai, Anda bisa keluar dari sesi root:

```bash
exit
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

> 💡 **Tips Izin Port USB:**  
> Jika saat menjalankan `edl` muncul kendala izin akses USB, pastikan user Anda telah dimasukkan ke grup `plugdev` & `dialout`:
> ```bash
> sudo usermod -aG plugdev,dialout $USER
> ```
> *(Lalu relog terminal atau jalankan `newgrp plugdev`).*
