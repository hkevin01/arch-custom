#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok() { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${YELLOW}[!!] $1${NC}"; }
die() { echo -e "${RED}[ERR] $1${NC}"; exit 1; }

TARGET_DISK="${TARGET_DISK:-/dev/mmcblk0}"
EFI_PART="${EFI_PART:-${TARGET_DISK}p1}"
ROOT_PART="${ROOT_PART:-${TARGET_DISK}p2}"
CRYPT_NAME="${CRYPT_NAME:-cryptroot}"

if [[ "${EUID}" -ne 0 ]]; then
  die "Run as root from Arch USB."
fi

[[ -b "$EFI_PART" ]] || die "EFI partition not found: $EFI_PART"
[[ -b "$ROOT_PART" ]] || die "Root partition not found: $ROOT_PART"

info "Opening encrypted root"
cryptsetup open "$ROOT_PART" "$CRYPT_NAME"

info "Mounting target"
mount /dev/mapper/$CRYPT_NAME /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

if [[ -f /etc/resolv.conf ]]; then
  cp -f /etc/resolv.conf /mnt/etc/resolv.conf || true
fi

info "Applying vfat/boot repair in chroot"
arch-chroot /mnt /bin/bash <<'CHROOTEOF'
set -euo pipefail

echo "[chroot] Reinstall linux-zen + headers"
pacman -Sy --noconfirm
pacman -S --noconfirm --needed linux-zen linux-zen-headers

echo "[chroot] Backing up config files"
mkdir -p /root/boot-repair-backups
cp -a /etc/fstab /root/boot-repair-backups/fstab.$(date +%Y%m%d-%H%M%S).bak || true

echo "[chroot] Removing modules_disabled=1 lines if present"
for f in /etc/sysctl.conf /etc/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf; do
  [[ -f "$f" ]] || continue
  if grep -q 'modules_disabled' "$f"; then
    sed -i -E 's/^([^#].*modules_disabled\s*=\s*1.*)$/# disabled by fix-vfat-from-usb: \1/' "$f" || true
  fi
done

echo "[chroot] Ensure vfat module autoload hint exists"
mkdir -p /etc/modules-load.d
echo vfat > /etc/modules-load.d/vfat.conf

echo "[chroot] Fix /boot fstab entry"
BOOT_UUID="$(blkid -s UUID -o value /dev/mmcblk0p1)"
sed -i '\|[[:space:]]/boot[[:space:]]|d' /etc/fstab
echo "UUID=${BOOT_UUID}  /boot  vfat  rw,nofail,x-systemd.device-timeout=10,umask=0077  0  2" >> /etc/fstab

echo "[chroot] Rebuild initramfs"
mkinitcpio -P

if [[ -f /boot/loader/random-seed ]]; then
  chmod 600 /boot/loader/random-seed || true
  chown root:root /boot/loader/random-seed || true
fi

echo "[chroot] Done"
CHROOTEOF

info "Unmounting target"
umount -R /mnt || true
cryptsetup close "$CRYPT_NAME" || true

ok "Repair complete. Reboot and test without USB."