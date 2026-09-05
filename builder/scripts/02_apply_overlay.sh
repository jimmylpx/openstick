#!/bin/bash
# 02_apply_overlay.sh - Apply OpenStick configurations, services, user accounts, and tweaks
set -e

TARGET_ROOTFS="$1"
OVERLAY_DIR="$2"
BASE_DISTRO="${3:-bookworm}"
IS_MODEM_DISABLED="${4:-0}"

if [ -z "$TARGET_ROOTFS" ] || [ -z "$OVERLAY_DIR" ]; then
    echo "Usage: $0 <target_rootfs_dir> <overlay_dir> [base_distro] [is_modem_disabled]"
    exit 1
fi

echo "--> [2/4] Menerapkan filesystem overlay..."
cp -a "${OVERLAY_DIR}/." "${TARGET_ROOTFS}/"

# Bersihkan file helper dari overlay jika ada di rootfs
rm -f "${TARGET_ROOTFS}/usr/local/bin/sbrmenu_modem_disabled"

# Pasang varian sbrmenu yang sesuai
if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
    echo "--> [2/4] Memasang sbrmenu versi Modem-Disabled..."
    cp -a "${OVERLAY_DIR}/usr/local/bin/sbrmenu_modem_disabled" "${TARGET_ROOTFS}/usr/local/bin/sbrmenu"
fi

# Sesuaikan /etc/os-release dan /etc/issue
if [ "$IS_MODEM_DISABLED" -eq 1 ]; then
    if [ "$BASE_DISTRO" = "trixie" ]; then
        echo "PRETTY_NAME=\"Debian GNU/Linux 13 (trixie - Modem-Disabled)\"" > "${TARGET_ROOTFS}/etc/os-release"
        echo "NAME=\"Debian GNU/Linux\"" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "VERSION_ID=\"13\"" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "VERSION=\"13 (trixie)\"" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "VERSION_CODENAME=trixie" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "ID=debian" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "Debian GNU/Linux 13 (trixie - Modem-Disabled) \\n \\l" > "${TARGET_ROOTFS}/etc/issue"
    else
        echo "PRETTY_NAME=\"Debian GNU/Linux 12 (bookworm - Modem-Disabled)\"" > "${TARGET_ROOTFS}/etc/os-release"
        echo "NAME=\"Debian GNU/Linux\"" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "VERSION_ID=\"12\"" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "VERSION=\"12 (bookworm)\"" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "VERSION_CODENAME=bookworm" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "ID=debian" >> "${TARGET_ROOTFS}/etc/os-release"
        echo "Debian GNU/Linux 12 (bookworm - Modem-Disabled) \\n \\l" > "${TARGET_ROOTFS}/etc/issue"
    fi
    sed -i 's/Hotspot, 4G LTE, SMS, dll./Hotspot, Jaringan Wi-Fi, dll./g' "${TARGET_ROOTFS}/etc/profile.d/00-motd-fastfetch.sh" 2>/dev/null || true
fi

# Hapus skrip sysvinit yang konflik jika ada di early boot
rm -f "${TARGET_ROOTFS}/etc/init.d/kmod" "${TARGET_ROOTFS}/etc/init.d/udev"
rm -f "${TARGET_ROOTFS}/etc/rcS.d/S01kmod" "${TARGET_ROOTFS}/etc/rcS.d/S01udev"
rm -f "${TARGET_ROOTFS}/etc/rc0.d/K01udev" "${TARGET_ROOTFS}/etc/rc6.d/K01udev"

echo "--> [2/4] Menyiapkan environment Chroot..."
mount --bind /dev "${TARGET_ROOTFS}/dev"
mount --bind /dev/pts "${TARGET_ROOTFS}/dev/pts"
mount -t proc proc "${TARGET_ROOTFS}/proc"
mount -t sysfs sys "${TARGET_ROOTFS}/sys"
rm -f "${TARGET_ROOTFS}/etc/resolv.conf"
echo "nameserver 8.8.8.8" > "${TARGET_ROOTFS}/etc/resolv.conf"
cp -f /usr/bin/qemu-aarch64-static "${TARGET_ROOTFS}/usr/bin/" 2>/dev/null || true

cat << CHROOT_TWEAKS > "${TARGET_ROOTFS}/tmp/tweaks.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 1. Konfigurasi Hostname & Hosts
echo "openstick" > /etc/hostname
echo "127.0.0.1 localhost openstick" > /etc/hosts

# 2. Buat Akun User default (user:1) & Root (root:1)
echo "root:1" | chpasswd
for grp in sudo dialout plugdev netdev audio video users; do
    groupadd -f "$grp" 2>/dev/null || true
done
if ! id -u user >/dev/null 2>&1; then
    useradd -m -s /bin/bash user
fi
usermod -aG sudo,dialout,plugdev,netdev,audio,video,users user 2>/dev/null || true
echo "user:1" | chpasswd

# 3. Aktifkan Services Esensial
systemctl enable adbd.service 2>/dev/null || true
systemctl enable usb-gadget-rndis.service 2>/dev/null || true
systemctl enable usb-mode-init.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable ssh.service 2>/dev/null || true
systemctl enable resize-rootfs.service 2>/dev/null || true
systemctl enable openstick-wifi-watchdog.service 2>/dev/null || true
systemctl enable zramswap.service 2>/dev/null || true
systemctl enable msm-firmware-loader.service 2>/dev/null || true
systemctl enable regenerate-ssh-host-keys.service 2>/dev/null || true
systemctl enable systemd-timesyncd.service 2>/dev/null || true
systemctl enable dnscrypt-proxy.service 2>/dev/null || true

# 4. Konfigurasi Khusus Modem-Disabled (Masking services agar tidak crash-loop)
if [ "${IS_MODEM_DISABLED}" -eq 1 ]; then
    systemctl mask ModemManager.service 2>/dev/null || ln -sf /dev/null /etc/systemd/system/ModemManager.service
    systemctl mask qrtr-ns.service 2>/dev/null || ln -sf /dev/null /etc/systemd/system/qrtr-ns.service
    systemctl mask rmtfs.service 2>/dev/null || ln -sf /dev/null /etc/systemd/system/rmtfs.service
fi

# 5. SUID Ping
chmod u+s /bin/ping 2>/dev/null || chmod u+s /usr/bin/ping 2>/dev/null || true

# 6. Izin eksekusi script & biner OpenStick
chmod +x /opt/dnscrypt-proxy/dnscrypt-proxy 2>/dev/null || true
chmod +x /usr/bin/fastfetch 2>/dev/null || true
chmod +x /usr/bin/gt 2>/dev/null || true
chmod +x /usr/bin/adbd 2>/dev/null || true
chmod +x /usr/sbin/adbd 2>/dev/null || true
chmod +x /usr/sbin/msm-firmware-loader.sh 2>/dev/null || true
chmod +x /usr/local/bin/adb-sh 2>/dev/null || true
chmod +x /usr/local/bin/py_adbd.py 2>/dev/null || true
chmod +x /usr/local/bin/sbrmenu 2>/dev/null || true
chmod +x /usr/local/bin/usb-mode-init 2>/dev/null || true
chmod +x /usr/local/bin/openstick-wifi-watchdog 2>/dev/null || true
chmod +x /usr/sbin/usb-gadget-rndis 2>/dev/null || true

# 7. Update library cache untuk libusbgx dan libcrypto.so.1.1
ldconfig 2>/dev/null || true

# 7. Kosongkan machine-id agar firstboot trigger berjalan normal
echo -n "" > /etc/machine-id
rm -f /var/lib/dbus/machine-id
exit 0
CHROOT_TWEAKS

chmod +x "${TARGET_ROOTFS}/tmp/tweaks.sh"
chroot "${TARGET_ROOTFS}" /tmp/tweaks.sh
rm -f "${TARGET_ROOTFS}/tmp/tweaks.sh" "${TARGET_ROOTFS}/usr/bin/qemu-aarch64-static"

umount -l "${TARGET_ROOTFS}/dev/pts" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/dev" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/proc" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/sys" 2>/dev/null || true

# Restore resolv.conf default
rm -f "${TARGET_ROOTFS}/etc/resolv.conf"
ln -sf /run/systemd/resolve/resolv.conf "${TARGET_ROOTFS}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${TARGET_ROOTFS}/etc/resolv.conf"

echo "--> [2/4] Overlay & Konfigurasi selesai!"
