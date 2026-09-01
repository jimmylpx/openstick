#!/usr/bin/env bash
# ==============================================================================
# Script Auto-Installer Qualcomm EDL Tool (bkerler/edl)
# Berdasarkan panduan resmi EDL_INSTALL.md
# Kompatibel: Debian, Ubuntu, Raspberry Pi OS, Linux Mint & Kali Linux
# ==============================================================================

set -e

# Warna Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}      AUTO INSTALLER QUALCOMM EDL TOOL (BKERLER / LINUX)              ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# 1. Pengecekan Hak Akses Root / Sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Script ini membutuhkan hak akses root/sudo.${NC}"
    echo -e "${YELLOW}[*] Menjalankan ulang dengan sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# 2. Instal Dependensi Sistem
echo -e "${BLUE}[1/5] Menginstal dependensi sistem & compiler...${NC}"
apt update -y
apt install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    libusb-1.0-0 \
    libusb-1.0-0-dev \
    build-essential \
    pkg-config \
    android-sdk-platform-tools-common \
    udev

# 3. Kloning Source Code & Submodules
echo -e "${BLUE}[2/5] Mengunduh repository bkerler/edl & submodules...${NC}"
BUILD_DIR="/tmp/edl_build"
rm -rf "$BUILD_DIR"
git clone https://github.com/bkerler/edl.git "$BUILD_DIR"
cd "$BUILD_DIR"
git submodule update --init --recursive

# 4. Pasang Driver Linux, Paket Python & Salin ke /opt/edl
echo -e "${BLUE}[3/5] Memasang driver Linux EDL, modul pip, dan menyalin ke /opt/edl...${NC}"
chmod +x ./install-linux-edl-drivers.sh
./install-linux-edl-drivers.sh || true

echo -e "${BLUE}[*] Menginstal edlclient via pip3...${NC}"
pip3 install . --break-system-packages || pip3 install .

echo -e "${BLUE}[*] Menyalin folder source ke /opt/edl...${NC}"
mkdir -p /opt/edl
rm -rf /opt/edl/*
cp -r . /opt/edl/

# 5. Konfigurasi Binary Global /usr/local/bin/edl
echo -e "${BLUE}[4/5] Mengonfigurasi binary global /usr/local/bin/edl...${NC}"
cat << 'EOF' > /usr/local/bin/edl
#!/usr/bin/env bash
if [ -f "/opt/edl/edl.py" ]; then
    exec python3 /opt/edl/edl.py "$@"
else
    echo "Error: File /opt/edl/edl.py tidak ditemukan."
    exit 1
fi
EOF

chmod +x /usr/local/bin/edl

# Buat symlink juga ke ~/.local/bin jika jalurnya pernah digunakan
if [ -n "$USER_HOME" ]; then
    mkdir -p "$USER_HOME/.local/bin"
    ln -sf /usr/local/bin/edl "$USER_HOME/.local/bin/edl" 2>/dev/null || true
    chown -h "$REAL_USER:$REAL_USER" "$USER_HOME/.local/bin/edl" 2>/dev/null || true
fi

# 6. Konfigurasi Izin Akses USB untuk User
echo -e "${BLUE}[5/5] Mengonfigurasi grup akses USB (plugdev & dialout)...${NC}"
groupadd -f plugdev
groupadd -f dialout
if [ -n "$REAL_USER" ]; then
    usermod -aG plugdev,dialout "$REAL_USER" 2>/dev/null || true
fi

# Bersihkan cache perintah bash & direktori temporary
hash -r 2>/dev/null || true
rm -rf "$BUILD_DIR"

# 7. Verifikasi
echo ""
if command -v edl &>/dev/null || [ -f "/usr/local/bin/edl" ]; then
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}     [OK] Qualcomm EDL Tool BERHASIL TERINSTALL & SIAP DIGUNAKAN!     ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "Lokasi Source   : ${CYAN}/opt/edl${NC}"
    echo -e "Perintah Global : ${CYAN}edl${NC} (Path: ${CYAN}/usr/local/bin/edl${NC})"
    echo ""
    echo -e "${YELLOW}Catatan Sesi Terminal:${NC}"
    echo -e "  Jika sesi terminal lama masih mencari path cache lama, jalankan: ${CYAN}hash -r${NC}"
    echo ""
    echo -e "${YELLOW}Perintah Penggunaan:${NC}"
    echo -e "  - Cek menu bantuan     : ${CYAN}edl --help${NC}"
    echo -e "  - Cek koneksi EDL 9008 : ${CYAN}edl printgpt${NC}"
    echo "======================================================================${NC}"
else
    echo -e "${RED}[X] Instalasi gagal. Silakan periksa pesan log di atas.${NC}"
    exit 1
fi
