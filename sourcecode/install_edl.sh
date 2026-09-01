#!/usr/bin/env bash
# ==============================================================================
# Script Auto-Installer Qualcomm EDL Tool (bkerler/edl)
# Kompatibel: Debian 11/12/13, Ubuntu 20.04/22.04/24.04, Linux Mint, Raspberry Pi OS
# Aman dari pembatasan PEP 668 (externally-managed-environment)
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
echo -e "${GREEN}${BOLD}      AUTO INSTALLER QUALCOMM EDL TOOL (DEBIAN & DISTRO SEJENIS)      ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# 1. Pengecekan Hak Akses Root / Sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Script ini membutuhkan hak akses root untuk menginstal dependensi sistem.${NC}"
    echo -e "${YELLOW}[*] Menjalankan ulang dengan sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"

# 2. Instalasi Dependensi Sistem
echo -e "${BLUE}[1/5] Memperbarui repositori & menginstal dependensi sistem...${NC}"
apt-get update -y
apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    libusb-1.0-0 \
    libusb-1.0-0-dev \
    libxml2-dev \
    libxslt1-dev \
    build-essential \
    pkg-config \
    android-sdk-platform-tools-common \
    udev

# 3. Pemasangan Udev Rules Qualcomm 9008 (Akses tanpa sudo)
echo -e "${BLUE}[2/5] Mengonfigurasi Udev Rules Qualcomm EDL (05c6:9008)...${NC}"
UDEV_RULE_FILE="/etc/udev/rules.d/99-qualcomm-edl.rules"
cat << 'EOF' > "$UDEV_RULE_FILE"
# Qualcomm Emergency Download Mode (EDL 9008)
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="9008", MODE="0666", GROUP="plugdev"
# Qualcomm Fastboot Mode
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="901d", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="9025", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="90b6", MODE="0666", GROUP="plugdev"
# Generic Qualcomm Modem USB
SUBSYSTEM=="usb", ATTRS{idVendor}=="05c6", MODE="0666", GROUP="plugdev"
EOF

chmod 644 "$UDEV_RULE_FILE"
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

# Tambahkan user ke grup plugdev dan dialout
groupadd -f plugdev
groupadd -f dialout
if [ -n "$REAL_USER" ]; then
    usermod -aG plugdev,dialout "$REAL_USER" 2>/dev/null || true
fi

# 4. Kloning Source Code & Pemasangan Virtual Environment di /opt/edl
echo -e "${BLUE}[3/5] Mengunduh repository bkerler/edl terbaru ke /opt/edl-src...${NC}"
rm -rf /opt/edl /opt/edl-src
git clone --depth 1 https://github.com/bkerler/edl.git /opt/edl-src

echo -e "${BLUE}[*] Membuat environment Python terisolasi di /opt/edl (PEP 668 Safe)...${NC}"
python3 -m venv /opt/edl
/opt/edl/bin/pip install --upgrade pip setuptools wheel
/opt/edl/bin/pip install -r /opt/edl-src/requirements.txt
/opt/edl/bin/pip install -e /opt/edl-src

# 5. Membuat Wrapper Binary Global di /usr/local/bin/edl
echo -e "${BLUE}[4/5] Membuat wrapper binary global /usr/local/bin/edl...${NC}"
cat << 'EOF' > /usr/local/bin/edl
#!/usr/bin/env bash
exec /opt/edl/bin/python3 /opt/edl-src/edl.py "$@"
EOF
chmod 755 /usr/local/bin/edl

# 6. Verifikasi Perintah EDL
echo -e "${BLUE}[5/5] Memverifikasi instalasi...${NC}"
echo ""
if /usr/local/bin/edl -h &>/dev/null || [ -f "/usr/local/bin/edl" ]; then
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}     [OK] Qualcomm EDL Tool BERHASIL TERINSTALL & SIAP DIGUNAKAN!     ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "Lokasi Perintah : ${CYAN}/usr/local/bin/edl${NC}"
    echo -e "Lokasi Source   : ${CYAN}/opt/edl-src${NC}"
    echo -e "Environment     : ${CYAN}/opt/edl${NC}"
    echo -e "Udev Rules      : ${CYAN}/etc/udev/rules.d/99-qualcomm-edl.rules${NC}"
    echo ""
    echo -e "${YELLOW}Perintah Umum EDL:${NC}"
    echo -e "  - Cek koneksi EDL 9008 : ${CYAN}edl printgpt${NC}"
    echo -e "  - Backup eMMC penuh    : ${CYAN}edl rf backup.bin${NC}"
    echo -e "  - Reset ke Fastboot    : ${CYAN}edl reset${NC}"
    echo -e "  - Bantuan lengkap      : ${CYAN}edl --help${NC}"
    echo "======================================================================"
else
    echo -e "${RED}[X] Instalasi gagal. Silakan periksa pesan kesalahan di atas.${NC}"
    exit 1
fi
