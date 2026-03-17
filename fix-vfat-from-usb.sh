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
PASS_ATTEMPTS="${PASS_ATTEMPTS:-3}"
LUKS_PASSPHRASE="${LUKS_PASSPHRASE:-}"

if [[ "${EUID}" -ne 0 ]]; then
  die "Run as root from Arch USB."
fi

[[ -b "$EFI_PART" ]] || die "EFI partition not found: $EFI_PART"

detect_luks_partition() {
  if [[ -b "$ROOT_PART" ]] && blkid "$ROOT_PART" 2>/dev/null | grep -q 'TYPE="crypto_LUKS"'; then
    echo "$ROOT_PART"
    return 0
  fi

  local detected
  detected="$(lsblk -pnro NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1; exit}')"
  [[ -n "$detected" ]] || return 1
  echo "$detected"
}

open_luks_with_retries() {
  local part="$1"
  local i=1
  local passphrase

  if [[ -n "$LUKS_PASSPHRASE" ]]; then
    info "Trying provided LUKS_PASSPHRASE for $part"
    if printf '%s' "$LUKS_PASSPHRASE" | cryptsetup open "$part" "$CRYPT_NAME" --key-file -; then
      return 0
    fi
    warn "Provided LUKS_PASSPHRASE did not unlock $part"
  fi

  while [[ $i -le $PASS_ATTEMPTS ]]; do
    info "Opening encrypted root ($part), attempt $i/$PASS_ATTEMPTS"

    # Running via curl|bash can make stdin non-interactive, so read from /dev/tty.
    if [[ -r /dev/tty ]]; then
      read -r -s -p "Enter LUKS passphrase for $part: " passphrase < /dev/tty
      echo "" > /dev/tty
      if printf '%s' "$passphrase" | cryptsetup open "$part" "$CRYPT_NAME" --key-file -; then
        unset passphrase
        return 0
      fi
    elif cryptsetup open "$part" "$CRYPT_NAME"; then
      return 0
    fi

    unset passphrase
    warn "No key available with this passphrase for $part"
    i=$((i + 1))
  done
  return 1
}

ROOT_PART="$(detect_luks_partition || true)"
[[ -n "$ROOT_PART" ]] || die "Could not find a LUKS root partition. Run: lsblk -f"

info "Using LUKS root partition: $ROOT_PART"

info "Opening encrypted root"
open_luks_with_retries "$ROOT_PART" || die "Unable to unlock $ROOT_PART after $PASS_ATTEMPTS attempts."

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
