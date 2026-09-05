#!/bin/bash
# 01_bootstrap_rootfs.sh - Pure clean Debian ARM64 bootstrap from scratch
set -e

VARIANT="$1"
TARGET_ROOTFS="$2"
SCRIPT_ROOT="$3"

if [ -z "$VARIANT" ] || [ -z "$TARGET_ROOTFS" ]; then
    echo "Usage: $0 <variant> <target_rootfs_dir> [script_root]"
    exit 1
fi

BASE_DISTRO="bookworm"
if [[ "$VARIANT" == trixie* ]]; then
    BASE_DISTRO="trixie"
fi

echo "--> [1/4] Menjalankan debootstrap (${BASE_DISTRO} arm64) dari repositori resmi..."
rm -rf "${TARGET_ROOTFS}"
mkdir -p "${TARGET_ROOTFS}"

# Jalankan debootstrap bersih minbase (cepat dan murni)
debootstrap --arch=arm64 --variant=minbase "${BASE_DISTRO}" "${TARGET_ROOTFS}" http://deb.debian.org/debian/

# Setup chroot environment
mount --bind /dev "${TARGET_ROOTFS}/dev"
mount --bind /dev/pts "${TARGET_ROOTFS}/dev/pts"
mount -t proc proc "${TARGET_ROOTFS}/proc"
mount -t sysfs sys "${TARGET_ROOTFS}/sys"

rm -f "${TARGET_ROOTFS}/etc/resolv.conf"
echo "nameserver 8.8.8.8" > "${TARGET_ROOTFS}/etc/resolv.conf"
cp -f /usr/bin/qemu-aarch64-static "${TARGET_ROOTFS}/usr/bin/" 2>/dev/null || true

# Konfigurasi sources.list lengkap (main, contrib, non-free, non-free-firmware, backports)
cat << SOURCES > "${TARGET_ROOTFS}/etc/apt/sources.list"
deb http://deb.debian.org/debian ${BASE_DISTRO} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ ${BASE_DISTRO}-security main contrib non-free-firmware
deb http://deb.debian.org/debian ${BASE_DISTRO}-updates main contrib non-free-firmware
deb http://deb.debian.org/debian ${BASE_DISTRO}-backports main contrib non-free non-free-firmware
SOURCES

# Update dan pasang daftar paket dari config/packages.list
if [ -f "${SCRIPT_ROOT}/config/packages.list" ]; then
    echo "--> [1/4] Menginstal paket esensial dari config/packages.list..."
    PKGS=$(grep -v '^#' "${SCRIPT_ROOT}/config/packages.list" | grep -v '^$' | tr '\n' ' ')
    
    cat << 'CHROOT_INSTALL' > "${TARGET_ROOTFS}/install_pkgs.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
apt-get update -qq
apt-get install -y --no-install-recommends "$@" || true
# Install fastfetch from backports if needed
if ! command -v fastfetch >/dev/null 2>&1; then
    apt-get install -y -t "${1:-bookworm}-backports" --no-install-recommends fastfetch 2>/dev/null || apt-get install -y --no-install-recommends fastfetch 2>/dev/null || true
fi
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/*
exit 0
CHROOT_INSTALL

    chmod +x "${TARGET_ROOTFS}/install_pkgs.sh"
    chroot "${TARGET_ROOTFS}" /install_pkgs.sh ${BASE_DISTRO} ${PKGS}
    rm -f "${TARGET_ROOTFS}/install_pkgs.sh"
fi

# Pasang driver kernel MSM8916 dan firmware Qualcomm dari folder firmware/
if [ -f "${SCRIPT_ROOT}/firmware/modules.tar.gz" ]; then
    echo "--> [1/4] Memasang modul kernel MSM8916 dari firmware/modules.tar.gz..."
    mkdir -p "${TARGET_ROOTFS}/lib"
    tar -xzf "${SCRIPT_ROOT}/firmware/modules.tar.gz" -C "${TARGET_ROOTFS}/lib/"
elif [ -d "${SCRIPT_ROOT}/firmware/modules" ]; then
    echo "--> [1/4] Memasang modul kernel MSM8916 dari firmware/modules/..."
    mkdir -p "${TARGET_ROOTFS}/lib/modules"
    cp -a "${SCRIPT_ROOT}/firmware/modules/." "${TARGET_ROOTFS}/lib/modules/"
fi

if [ -f "${SCRIPT_ROOT}/firmware/firmware.tar.gz" ]; then
    echo "--> [1/4] Memasang firmware Qualcomm MSM8916 dari firmware/firmware.tar.gz..."
    mkdir -p "${TARGET_ROOTFS}/lib"
    tar -xzf "${SCRIPT_ROOT}/firmware/firmware.tar.gz" -C "${TARGET_ROOTFS}/lib/"
elif [ -d "${SCRIPT_ROOT}/firmware/firmware" ]; then
    echo "--> [1/4] Memasang firmware Qualcomm MSM8916 dari firmware/firmware/..."
    mkdir -p "${TARGET_ROOTFS}/lib/firmware"
    cp -a "${SCRIPT_ROOT}/firmware/firmware/." "${TARGET_ROOTFS}/lib/firmware/"
fi

# Unmount chroot
umount -l "${TARGET_ROOTFS}/dev/pts" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/dev" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/proc" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/sys" 2>/dev/null || true
rm -f "${TARGET_ROOTFS}/usr/bin/qemu-aarch64-static"

rm -f "${TARGET_ROOTFS}/etc/resolv.conf"
ln -sf /run/systemd/resolve/resolv.conf "${TARGET_ROOTFS}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${TARGET_ROOTFS}/etc/resolv.conf"

echo "--> [1/4] Base RootFS selesai dibangun dari awal!"
