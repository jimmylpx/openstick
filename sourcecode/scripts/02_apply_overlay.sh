#!/bin/bash
# 02_apply_overlay.sh - Apply OpenStick configurations, services, user accounts, and tweaks
set -e

TARGET_ROOTFS="$1"
OVERLAY_DIR="$2"

if [ -z "$TARGET_ROOTFS" ] || [ -z "$OVERLAY_DIR" ]; then
    echo "Usage: $0 <target_rootfs_dir> <overlay_dir>"
    exit 1
fi

echo "--> [2/4] Menerapkan filesystem overlay..."
cp -a "${OVERLAY_DIR}/." "${TARGET_ROOTFS}/"

echo "--> [2/4] Menyiapkan environment Chroot..."
mount --bind /dev "${TARGET_ROOTFS}/dev"
mount --bind /dev/pts "${TARGET_ROOTFS}/dev/pts"
mount -t proc proc "${TARGET_ROOTFS}/proc"
mount -t sysfs sys "${TARGET_ROOTFS}/sys"
echo "nameserver 8.8.8.8" > "${TARGET_ROOTFS}/etc/resolv.conf"

cat << 'CHROOT_TWEAKS' > "${TARGET_ROOTFS}/tmp/tweaks.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 1. Konfigurasi Hostname
echo "openstick" > /etc/hostname
echo "127.0.0.1 localhost openstick" > /etc/hosts

# 2. Buat Akun User default (user:1) & Root (root:1)
echo "root:1" | chpasswd
if ! id -u user >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,dialout,plugdev,netdev,audio,video user
    echo "user:1" | chpasswd
fi

# Sudoers tanpa password untuk user
echo "user ALL=(ALL:ALL) ALL" > /etc/sudoers.d/010_user-nopasswd
chmod 440 /etc/sudoers.d/010_user-nopasswd

# 3. Aktifkan Services
systemctl enable adbd.service 2>/dev/null || true
systemctl enable usb-gadget-rndis.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable ssh.service 2>/dev/null || true

# 4. SUID Ping (memungkinkan user biasa mengeksekusi ping)
chmod u+s /bin/ping 2>/dev/null || chmod u+s /usr/bin/ping 2>/dev/null || true

# 5. Izin eksekusi script OpenStick
chmod +x /usr/local/bin/py_adbd.py
chmod +x /usr/local/bin/sbrmenu
chmod +x /usr/sbin/usb-gadget-rndis
CHROOT_TWEAKS

chmod +x "${TARGET_ROOTFS}/tmp/tweaks.sh"
chroot "${TARGET_ROOTFS}" /tmp/tweaks.sh
rm -f "${TARGET_ROOTFS}/tmp/tweaks.sh"

umount -l "${TARGET_ROOTFS}/dev/pts" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/dev" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/proc" 2>/dev/null || true
umount -l "${TARGET_ROOTFS}/sys" 2>/dev/null || true

echo "--> [2/4] Overlay & Konfigurasi selesai!"
