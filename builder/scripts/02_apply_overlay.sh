#!/bin/bash
# 02_apply_overlay.sh - Apply configuration, services, and patches to rootfs in-place
set -e

MNT="$1"
OVERLAY_DIR="$2"
BASE_DISTRO="$3"
IS_MODEM_DISABLED="$4"
BUILD_DIR="$5"
VARIANT="$6"

if [ -z "$MNT" ] || [ -z "$OVERLAY_DIR" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 MNT_ROOTFS OVERLAY_DIR BASE_DISTRO IS_MODEM_DISABLED BUILD_DIR VARIANT"
    exit 1
fi

ROOTFS_IMG="${BUILD_DIR}/partitions/rootfs.bin"

echo "--> [2/4] Menyalin berkas overlay ke filesystem rootfs..."
cp -a "${OVERLAY_DIR}/." "${MNT}/"

# 1. Konfigurasi Khusus Varian Modem
if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
    echo "--> [2/4] Mengonfigurasi varian Modem-Disabled (Max RAM)..."
    # Pasang sbrmenu khusus modem-disabled (tanpa opsi 4G LTE & SMS)
    if [ -f "${OVERLAY_DIR}/usr/local/bin/sbrmenu_modem_disabled" ]; then
        cp -fv "${OVERLAY_DIR}/usr/local/bin/sbrmenu_modem_disabled" "${MNT}/usr/local/bin/sbrmenu"
    fi

    # Nonaktifkan ModemManager, rmtfs, dan qrtr-ns untuk menghemat RAM dan CPU
    rm -f "${MNT}/etc/systemd/system/multi-user.target.wants/ModemManager.service"
    ln -sf /dev/null "${MNT}/etc/systemd/system/ModemManager.service"
    ln -sf /dev/null "${MNT}/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service"
    ln -sf /dev/null "${MNT}/etc/systemd/system/rmtfs.service"
    ln -sf /dev/null "${MNT}/etc/systemd/system/qrtr-ns.service"

    # Perbarui MOTD Fastfetch
    cat << 'EOF' > "${MNT}/etc/profile.d/00-motd-fastfetch.sh"
[ -z "$TERM" ] || [ "$TERM" = "unknown" ] && export TERM=xterm-256color
if [ -t 1 ] && [ -n "$PS1" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch --logo debian_small 2>/dev/null || fastfetch 2>/dev/null || true
    fi
    echo ""
    echo -e "\033[1;36m====================================================================\033[0m"
    echo -e "\033[1;32m  🚀 Debian 12 Bookworm (Modem-Disabled Edition - Max RAM ~512MB)\033[0m"
    echo -e "\033[1;33m  💡 HINT: Ketik \033[1;32msbrmenu\033[1;33m untuk mengelola Wi-Fi, Hotspot, USB Mode, dll.\033[0m"
    echo -e "\033[1;33m  🔑 ROOT: Jalankan \033[1;32msudo su\033[1;33m (Password: 1) untuk akses administrator.\033[0m"
    echo -e "\033[1;36m====================================================================\033[0m"
    echo ""
fi
EOF
    sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm - Modem-Disabled)"/' "${MNT}/etc/os-release" 2>/dev/null || true
    echo "Debian GNU/Linux 12 (bookworm - Modem-Disabled) \n \l" > "${MNT}/etc/issue"
else
    echo "--> [2/4] Mengonfigurasi varian Modem-Enabled (Standar)..."
    if [ -f "${OVERLAY_DIR}/usr/local/bin/sbrmenu" ]; then
        cp -fv "${OVERLAY_DIR}/usr/local/bin/sbrmenu" "${MNT}/usr/local/bin/sbrmenu"
    fi
    rm -f "${MNT}/etc/systemd/system/ModemManager.service"
    rm -f "${MNT}/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service"
    rm -f "${MNT}/etc/systemd/system/rmtfs.service"
    rm -f "${MNT}/etc/systemd/system/qrtr-ns.service"

    sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm)"/' "${MNT}/etc/os-release" 2>/dev/null || true
    echo "Debian GNU/Linux 12 (bookworm) \n \l" > "${MNT}/etc/issue"
fi

# 2. Upgrade ke Trixie jika targetnya adalah Trixie
if [ "$BASE_DISTRO" = "trixie" ]; then
    echo "--> [2/4] Menjalankan dist-upgrade ke Debian 13 Trixie via QEMU ARM64 chroot..."
    cp /usr/bin/qemu-aarch64-static "${MNT}/usr/bin/"
    rm -f "${MNT}/etc/resolv.conf"
    echo "nameserver 8.8.8.8" > "${MNT}/etc/resolv.conf"

    cat << 'SOURCES' > "${MNT}/etc/apt/sources.list"
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free-firmware
SOURCES

    mount --bind /dev "${MNT}/dev"
    mount --bind /dev/pts "${MNT}/dev/pts"
    mount -t proc proc "${MNT}/proc"
    mount -t sysfs sys "${MNT}/sys"

    cat << 'UPGRADE_SH' > "${MNT}/tmp/upgrade_trixie.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
apt-get update -qq
apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
UPGRADE_SH
    chmod +x "${MNT}/tmp/upgrade_trixie.sh"
    chroot "${MNT}" /tmp/upgrade_trixie.sh
    rm -f "${MNT}/tmp/upgrade_trixie.sh" "${MNT}/usr/bin/qemu-aarch64-static"

    umount -l "${MNT}/dev/pts" 2>/dev/null || true
    umount -l "${MNT}/dev" 2>/dev/null || true
    umount -l "${MNT}/proc" 2>/dev/null || true
    umount -l "${MNT}/sys" 2>/dev/null || true

    rm -f "${MNT}/etc/resolv.conf"
    ln -sf /run/systemd/resolve/resolv.conf "${MNT}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${MNT}/etc/resolv.conf"

    if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
        sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 13 (trixie - Modem-Disabled ~466MB)"/' "${MNT}/etc/os-release" 2>/dev/null || true
        echo "Debian GNU/Linux 13 (trixie - Modem-Disabled ~466MB) \n \l" > "${MNT}/etc/issue"
    else
        sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 13 (trixie)"/' "${MNT}/etc/os-release" 2>/dev/null || true
        echo "Debian GNU/Linux 13 (trixie) \n \l" > "${MNT}/etc/issue"
    fi
fi

# 3. Layanan Systemd Esensial & Konfigurasi Booting
echo "--> [2/4] Mengaktifkan layanan auto-expand rootfs & USB networking..."
mkdir -p "${MNT}/etc/systemd/system/sysinit.target.wants"
ln -sf /etc/systemd/system/resize-rootfs.service "${MNT}/etc/systemd/system/sysinit.target.wants/resize-rootfs.service"

mkdir -p "${MNT}/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/openstick-wifi-watchdog.service "${MNT}/etc/systemd/system/multi-user.target.wants/openstick-wifi-watchdog.service"
ln -sf /etc/systemd/system/usb-mode-init.service "${MNT}/etc/systemd/system/multi-user.target.wants/usb-mode-init.service"
ln -sf /etc/systemd/system/adbd.service "${MNT}/etc/systemd/system/multi-user.target.wants/adbd.service"

# Pastikan /etc/machine-id kosong (0 byte) agar systemd membuat ID unik pada first boot
touch "${MNT}/etc/machine-id"
chmod 444 "${MNT}/etc/machine-id"
chown root:root "${MNT}/etc/machine-id"

# Atur perizinan file eksekusi dan SSH keys
chmod 755 "${MNT}/usr/local/bin/"* 2>/dev/null || true
chmod 755 "${MNT}/usr/sbin/usb-gadget-rndis" 2>/dev/null || true
chmod 755 "${MNT}/etc/profile.d/00-motd-fastfetch.sh" 2>/dev/null || true
chmod -R 755 "${MNT}/lib/firmware" 2>/dev/null || true
chmod 600 "${MNT}/etc/ssh/"*_key 2>/dev/null || true
chmod 644 "${MNT}/etc/ssh/"*.pub 2>/dev/null || true

# Pastikan hostname default adalah openstick
echo "openstick" > "${MNT}/etc/hostname"

sync
echo "--> [2/4] Melepaskan mount rootfs..."
umount "${MNT}"

# Verifikasi dan perbaiki integritas filesystem
tune2fs -L rootfs "${ROOTFS_IMG}"
e2fsck -fy "${ROOTFS_IMG}" || true

echo "--> [2/4] Patching rootfs selesai dan filesystem bersih!"
