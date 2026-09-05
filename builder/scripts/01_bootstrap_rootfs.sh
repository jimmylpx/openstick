#!/bin/bash
# 01_bootstrap_rootfs.sh - Generate Debian RootFS via base template (fast) or debootstrap
set -e

VARIANT="$1"
BUILD_DIR="$2"
SCRIPT_ROOT="$3"
FROM_SCRATCH="${4:-0}"

TARGET_ROOTFS="${BUILD_DIR}/rootfs"
CACHE_DIR="${SCRIPT_ROOT}/.cache"
MNT_TMP="${BUILD_DIR}/mnt_tmp"
mkdir -p "${CACHE_DIR}" "${MNT_TMP}" "${TARGET_ROOTFS}"

BASE_DISTRO="bookworm"
if [[ "$VARIANT" == trixie* ]]; then
    BASE_DISTRO="trixie"
fi

# ==============================================================================
# OPSI A: FROM SCRATCH (DEBOOTSTRAP MURNI)
# ==============================================================================
if [ "$FROM_SCRATCH" -eq 1 ]; then
    echo "--> [1/4] Menjalankan pure debootstrap (${BASE_DISTRO} arm64)..."
    rm -rf "${TARGET_ROOTFS}"
    mkdir -p "${TARGET_ROOTFS}"

    debootstrap --arch=arm64 --foreign "${BASE_DISTRO}" "${TARGET_ROOTFS}" http://deb.debian.org/debian/
    cp /usr/bin/qemu-aarch64-static "${TARGET_ROOTFS}/usr/bin/"
    chroot "${TARGET_ROOTFS}" /debootstrap/debootstrap --second-stage

    # Pasang paket esensial dari packages.list
    mount --bind /dev "${TARGET_ROOTFS}/dev"
    mount --bind /dev/pts "${TARGET_ROOTFS}/dev/pts"
    mount -t proc proc "${TARGET_ROOTFS}/proc"
    mount -t sysfs sys "${TARGET_ROOTFS}/sys"
    echo "nameserver 8.8.8.8" > "${TARGET_ROOTFS}/etc/resolv.conf"

    if [ -f "${SCRIPT_ROOT}/config/packages.list" ]; then
        echo "--> [1/4] Menginstal paket esensial dari config/packages.list..."
        PKGS=$(grep -v '^#' "${SCRIPT_ROOT}/config/packages.list" | grep -v '^$' | tr '\n' ' ')
        chroot "${TARGET_ROOTFS}" apt-get update
        chroot "${TARGET_ROOTFS}" apt-get install -y --no-install-recommends ${PKGS}
    fi

    umount -l "${TARGET_ROOTFS}/dev/pts" 2>/dev/null || true
    umount -l "${TARGET_ROOTFS}/dev" 2>/dev/null || true
    umount -l "${TARGET_ROOTFS}/proc" 2>/dev/null || true
    umount -l "${TARGET_ROOTFS}/sys" 2>/dev/null || true
    echo "--> [1/4] Pure debootstrap selesai!"
    exit 0
fi

# ==============================================================================
# OPSI B: FAST BASE TEMPLATE (CEPAT, STABIL & DRIVER QUALCOMM LENGKAP)
# ==============================================================================
echo "--> [1/4] Mencari template base rootfs terverifikasi..."

BASE_IMG=""
CANDIDATES=(
    "${SCRIPT_ROOT}/../${VARIANT}/rootfs.bin"
    "${SCRIPT_ROOT}/../bookworm/rootfs.bin"
    "${SCRIPT_ROOT}/../bookworm-modem-disabled/rootfs.bin"
    "${CACHE_DIR}/rootfs.bin"
)

for c in "${CANDIDATES[@]}"; do
    if [ -f "$c" ]; then
        BASE_IMG="$c"
        echo "    Ditemukan base image lokal: ${BASE_IMG}"
        break
    fi
done

# Jika tidak ditemukan secara lokal, cari zip atau unduh dari GitHub Releases
if [ -z "$BASE_IMG" ]; then
    ZIP_CANDIDATE=""
    for z in "${SCRIPT_ROOT}/../${VARIANT}.zip" "${SCRIPT_ROOT}/../bookworm.zip" "${CACHE_DIR}/bookworm.zip"; do
        if [ -f "$z" ]; then
            ZIP_CANDIDATE="$z"
            break
        fi
    done

    if [ -z "$ZIP_CANDIDATE" ]; then
        echo "--> [1/4] Mengunduh template base (bookworm.zip) dari GitHub Releases..."
        curl -fsSL -o "${CACHE_DIR}/bookworm.zip" "https://github.com/jimmylpx/openstick/releases/download/v1/bookworm.zip"
        ZIP_CANDIDATE="${CACHE_DIR}/bookworm.zip"
    fi

    echo "    Mengekstrak rootfs.bin dari: ${ZIP_CANDIDATE}"
    unzip -q -o "${ZIP_CANDIDATE}" "rootfs.bin" -d "${CACHE_DIR}/"
    BASE_IMG="${CACHE_DIR}/rootfs.bin"
fi

echo "--> [1/4] Mengekstrak filesystem dari ${BASE_IMG} ke build directory..."
mount -o loop,ro "${BASE_IMG}" "${MNT_TMP}"
cp -a "${MNT_TMP}/." "${TARGET_ROOTFS}/"
sync
umount "${MNT_TMP}"

# Jika target adalah Trixie dan base asalnya adalah Bookworm, lakukan dist-upgrade
if [[ "$VARIANT" == trixie* ]]; then
    CURRENT_DISTRO=$(grep "^VERSION_CODENAME=" "${TARGET_ROOTFS}/etc/os-release" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
    if [ "$CURRENT_DISTRO" != "trixie" ]; then
        echo "--> [1/4] Mengupgrade base filesystem ke Debian 13 (Trixie)..."
        cp /usr/bin/qemu-aarch64-static "${TARGET_ROOTFS}/usr/bin/"
        rm -f "${TARGET_ROOTFS}/etc/resolv.conf"
        echo "nameserver 8.8.8.8" > "${TARGET_ROOTFS}/etc/resolv.conf"

        cat << 'SOURCES' > "${TARGET_ROOTFS}/etc/apt/sources.list"
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free-firmware
SOURCES

        mount --bind /dev "${TARGET_ROOTFS}/dev"
        mount --bind /dev/pts "${TARGET_ROOTFS}/dev/pts"
        mount -t proc proc "${TARGET_ROOTFS}/proc"
        mount -t sysfs sys "${TARGET_ROOTFS}/sys"

        cat << 'CHROOT_UPGRADE' > "${TARGET_ROOTFS}/tmp/upgrade.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
apt-get update
apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages     -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_UPGRADE

        chmod +x "${TARGET_ROOTFS}/tmp/upgrade.sh"
        chroot "${TARGET_ROOTFS}" /tmp/upgrade.sh
        rm -f "${TARGET_ROOTFS}/tmp/upgrade.sh" "${TARGET_ROOTFS}/usr/bin/qemu-aarch64-static"

        umount -l "${TARGET_ROOTFS}/dev/pts" 2>/dev/null || true
        umount -l "${TARGET_ROOTFS}/dev" 2>/dev/null || true
        umount -l "${TARGET_ROOTFS}/proc" 2>/dev/null || true
        umount -l "${TARGET_ROOTFS}/sys" 2>/dev/null || true

        rm -f "${TARGET_ROOTFS}/etc/resolv.conf"
        ln -sf /run/systemd/resolve/resolv.conf "${TARGET_ROOTFS}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${TARGET_ROOTFS}/etc/resolv.conf"
    fi
fi

echo "--> [1/4] Base RootFS berhasil disiapkan!"
