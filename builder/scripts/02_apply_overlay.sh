#!/bin/bash
# 02_apply_overlay.sh - Apply configuration, services, and patches matching golden reference
set -e

MNT="$1"
OVERLAY_DIR="$2"
BASE_DISTRO="$3"
IS_MODEM_DISABLED="$4"
BUILD_DIR="$5"
VARIANT="$6"
SCRIPT_ROOT="$7"

if [ -z "$MNT" ] || [ -z "$OVERLAY_DIR" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 MNT_ROOTFS OVERLAY_DIR BASE_DISTRO IS_MODEM_DISABLED BUILD_DIR VARIANT SCRIPT_ROOT"
    exit 1
fi

ROOTFS_IMG="${BUILD_DIR}/partitions/rootfs.bin"

echo "--> [2/4] Menyalin berkas overlay ke filesystem rootfs..."
cp -a "${OVERLAY_DIR}/." "${MNT}/"

# Bersihkan helper binary modem-disabled dari filesystem jika ada
rm -f "${MNT}/usr/local/bin/sbrmenu_modem_disabled"

# 1. Konfigurasi Khusus Varian Modem
if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
    echo "--> [2/4] Mengonfigurasi varian Modem-Disabled (High-RAM ~512MB)..."
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

    # Perbarui MOTD Fastfetch persis seperti golden release (--disk-folders / agar modem/persist tidak muncul)
    cat << 'EOF' > "${MNT}/etc/profile.d/00-motd-fastfetch.sh"
[ -z "$TERM" ] || [ "$TERM" = "unknown" ] && export TERM=xterm-256color
if [ -t 1 ] && [ -n "$PS1" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch --disk-folders / --logo debian_small 2>/dev/null || fastfetch --disk-folders / 2>/dev/null || true
    fi
    echo ""
    echo -e "===================================================================="
    echo -e "  [1;32m🚀 Debian 12 Bookworm (Modem-Disabled Edition)[0m"
    echo -e "  [1;33m💡 HINT: Ketik [1;32msbrmenu[1;33m untuk mengelola Wi-Fi, Hotspot, USB Mode, dll.[0m"
    echo -e "  [1;33m🔑 ROOT: Jalankan [1;32msudo su[1;33m (Password: 1) untuk akses administrator.[0m"
    echo -e "===================================================================="
    echo ""
fi
EOF
    sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm - Modem-Disabled)"/' "${MNT}/etc/os-release" 2>/dev/null || true
    echo "Debian GNU/Linux 12 (bookworm - Modem-Disabled) 
 \l" > "${MNT}/etc/issue"
else
    echo "--> [2/4] Mengonfigurasi varian Modem-Enabled (Standar)..."
    if [ -f "${OVERLAY_DIR}/usr/local/bin/sbrmenu" ]; then
        cp -fv "${OVERLAY_DIR}/usr/local/bin/sbrmenu" "${MNT}/usr/local/bin/sbrmenu"
    fi
    rm -f "${MNT}/etc/systemd/system/ModemManager.service"
    rm -f "${MNT}/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service"
    rm -f "${MNT}/etc/systemd/system/rmtfs.service"
    rm -f "${MNT}/etc/systemd/system/qrtr-ns.service"

    cat << 'EOF' > "${MNT}/etc/profile.d/00-motd-fastfetch.sh"
[ -z "$TERM" ] || [ "$TERM" = "unknown" ] && export TERM=xterm-256color
if [ -t 1 ] && [ -n "$PS1" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch --disk-folders / --logo debian_small 2>/dev/null || fastfetch --disk-folders / 2>/dev/null || true
    fi
    echo ""
    echo -e "===================================================================="
    echo -e "  [1;33m💡 HINT: Ketik [1;32msbrmenu[1;33m untuk mengelola Hotspot, 4G LTE, SMS, dll.[0m"
    echo -e "  [1;33m🔑 ROOT: Jalankan [1;32msudo su[1;33m (Password: 1) untuk akses administrator.[0m"
    echo -e "===================================================================="
    echo ""
fi
EOF
    sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm)"/' "${MNT}/etc/os-release" 2>/dev/null || true
    echo "Debian GNU/Linux 12 (bookworm) 
 \l" > "${MNT}/etc/issue"
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
apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages     -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
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
        echo "Debian GNU/Linux 13 (trixie - Modem-Disabled ~466MB) 
 \l" > "${MNT}/etc/issue"
    else
        sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 13 (trixie)"/' "${MNT}/etc/os-release" 2>/dev/null || true
        echo "Debian GNU/Linux 13 (trixie) 
 \l" > "${MNT}/etc/issue"
    fi
fi

# 3. Instalasi Paket Tambahan Pengguna (Optional Custom Packages)
CUSTOM_PKGS_FILE="${SCRIPT_ROOT}/config/custom_packages.list"
if [ -f "${CUSTOM_PKGS_FILE}" ]; then
    PKGS_TO_INSTALL=$(grep -v '^#' "${CUSTOM_PKGS_FILE}" | grep -v '^[[:space:]]*$' | tr '
' ' ' || true)
    if [ -n "${PKGS_TO_INSTALL}" ]; then
        echo "--> [2/4] Memasang paket kustom pengguna dari config/custom_packages.list: ${PKGS_TO_INSTALL}..."
        cp /usr/bin/qemu-aarch64-static "${MNT}/usr/bin/" 2>/dev/null || true
        rm -f "${MNT}/etc/resolv.conf"
        echo "nameserver 8.8.8.8" > "${MNT}/etc/resolv.conf"

        mount --bind /dev "${MNT}/dev"
        mount --bind /dev/pts "${MNT}/dev/pts"
        mount -t proc proc "${MNT}/proc"
        mount -t sysfs sys "${MNT}/sys"

        cat << 'CHROOT_PKGS' > "${MNT}/tmp/install_custom_pkgs.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
apt-get update -qq
apt-get install -y --no-install-recommends "$@"
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_PKGS
        chmod +x "${MNT}/tmp/install_custom_pkgs.sh"
        chroot "${MNT}" /tmp/install_custom_pkgs.sh ${PKGS_TO_INSTALL} || echo "[!] Peringatan: Beberapa paket kustom mungkin gagal dipasang."
        rm -f "${MNT}/tmp/install_custom_pkgs.sh" "${MNT}/usr/bin/qemu-aarch64-static"

        umount -l "${MNT}/dev/pts" 2>/dev/null || true
        umount -l "${MNT}/dev" 2>/dev/null || true
        umount -l "${MNT}/proc" 2>/dev/null || true
        umount -l "${MNT}/sys" 2>/dev/null || true

        rm -f "${MNT}/etc/resolv.conf"
        ln -sf /run/systemd/resolve/resolv.conf "${MNT}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${MNT}/etc/resolv.conf"
    fi
fi

# 4. Eksekusi Custom Hook Pengguna (Optional Post-Install Hook)
CUSTOM_HOOK="${SCRIPT_ROOT}/hooks/custom.sh"
if [ -f "${CUSTOM_HOOK}" ] && [ -x "${CUSTOM_HOOK}" ]; then
    echo "--> [2/4] Menjalankan custom hook pengguna: hooks/custom.sh..."
    cp /usr/bin/qemu-aarch64-static "${MNT}/usr/bin/" 2>/dev/null || true
    cp "${CUSTOM_HOOK}" "${MNT}/tmp/custom_hook.sh"
    mount --bind /dev "${MNT}/dev"
    mount -t proc proc "${MNT}/proc"
    mount -t sysfs sys "${MNT}/sys"
    chroot "${MNT}" /tmp/custom_hook.sh || echo "[!] Peringatan: Hook kustom selesai dengan status non-nol."
    rm -f "${MNT}/tmp/custom_hook.sh" "${MNT}/usr/bin/qemu-aarch64-static"
    umount -l "${MNT}/dev" 2>/dev/null || true
    umount -l "${MNT}/proc" 2>/dev/null || true
    umount -l "${MNT}/sys" 2>/dev/null || true
fi

# 5. Layanan Systemd Esensial & Konfigurasi Booting
echo "--> [2/4] Mengaktifkan layanan auto-expand rootfs & USB networking..."
mkdir -p "${MNT}/etc/systemd/system/sysinit.target.wants"
ln -sf /etc/systemd/system/resize-rootfs.service "${MNT}/etc/systemd/system/sysinit.target.wants/resize-rootfs.service"

mkdir -p "${MNT}/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/openstick-wifi-watchdog.service "${MNT}/etc/systemd/system/multi-user.target.wants/openstick-wifi-watchdog.service"
ln -sf /etc/systemd/system/usb-mode-init.service "${MNT}/etc/systemd/system/multi-user.target.wants/usb-mode-init.service"
ln -sf /etc/systemd/system/adbd.service "${MNT}/etc/systemd/system/multi-user.target.wants/adbd.service"

# Pastikan /etc/machine-id kosong (0 byte)
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

echo "openstick" > "${MNT}/etc/hostname"

sync
echo "--> [2/4] Melepaskan mount rootfs..."
umount "${MNT}"

tune2fs -L rootfs "${ROOTFS_IMG}"
e2fsck -fy "${ROOTFS_IMG}" || true

echo "--> [2/4] Patching rootfs selesai dan filesystem bersih!"
