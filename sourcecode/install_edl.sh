#!/usr/bin/env bash
# ==============================================================================
# Script Auto-Installer Qualcomm EDL Tool (bkerler/edl)
# Menggunakan alur resmi git clone + submodule + install-linux-edl-drivers.sh
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
echo -e "${GREEN}${BOLD}       AUTO INSTALLER QUALCOMM EDL TOOL (BKERLER / OFFICIAL)         ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# 1. Pengecekan Hak Akses Root / Sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Script ini membutuhkan hak akses root untuk menginstal dependensi sistem.${NC}"
    echo -e "${YELLOW}[*] Menjalankan ulang dengan sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"

# 2. Instalasi Dependensi Sistem & Compiler
echo -e "${BLUE}[1/5] Menginstal dependensi sistem & compiler...${NC}"
apt-get update -y
apt-get install -y --no-install-recommends \
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
INSTALL_DIR="/opt/edl"
rm -rf "$INSTALL_DIR"
git clone https://github.com/bkerler/edl.git "$INSTALL_DIR"
cd "$INSTALL_DIR"
git submodule update --init --recursive

# 4. Pemasangan Driver & Udev Rules Resmi Linux EDL
echo -e "${BLUE}[3/5] Memasang driver & udev rules Linux EDL...${NC}"
if [ -f "./install-linux-edl-drivers.sh" ]; then
    chmod +x ./install-linux-edl-drivers.sh
    ./install-linux-edl-drivers.sh || true
fi

# Pastikan user terdaftar di grup dialout & plugdev
groupadd -f plugdev
groupadd -f dialout
if [ -n "$REAL_USER" ]; then
    usermod -aG plugdev,dialout "$REAL_USER" 2>/dev/null || true
fi

# 5. Pemasangan Package Python via Pip3
echo -e "${BLUE}[4/5] Menginstal edl package via pip3 (--break-system-packages)...${NC}"
pip3 install . --break-system-packages --ignore-installed

# 6. Pembuatan Binary Executable Global di /usr/local/bin/edl
echo -e "${BLUE}[5/5] Mengonfigurasi binary global /usr/local/bin/edl...${NC}"
cat << 'EOF' > /usr/local/bin/edl
#!/usr/bin/env bash
if [ -f "/opt/edl/edl.py" ]; then
    exec python3 /opt/edl/edl.py "$@"
elif command -v python3 &>/dev/null; then
    exec python3 -m edlclient.edl "$@"
else
    echo "Error: Python3 atau EDL source tidak ditemukan."
    exit 1
fi
EOF
chmod 755 /usr/local/bin/edl

# 7. Verifikasi
echo -e "${BLUE}[*] Memverifikasi instalasi...${NC}"
echo ""
if command -v edl &>/dev/null || [ -f "/usr/local/bin/edl" ]; then
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}     [OK] Qualcomm EDL Tool BERHASIL TERINSTALL & SIAP DIGUNAKAN!     ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "Lokasi Source   : ${CYAN}/opt/edl${NC}"
    echo -e "Perintah Global : ${CYAN}edl${NC} (Path: ${CYAN}/usr/local/bin/edl${NC})"
    echo ""
    echo -e "${YELLOW}Perintah Penggunaan:${NC}"
    echo -e "  - Cek koneksi EDL    : ${CYAN}edl printgpt${NC}"
    echo -e "  - Backup eMMC penuh  : ${CYAN}edl rf backup.bin${NC}"
    echo -e "  - Reset ke Fastboot  : ${CYAN}edl reset${NC}"
    echo -e "  - Bantuan lengkap    : ${CYAN}edl --help${NC}"
    echo "======================================================================${NC}"
else
    echo -e "${RED}[X] Instalasi gagal. Silakan periksa pesan kesalahan di atas.${NC}"
    exit 1
fi
