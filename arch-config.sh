#!/bin/bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok() { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${RED}[!!] $1${NC}"; }
die() { echo -e "${RED}[ERR] $1${NC}"; exit 1; }

TARGET_DISK="/dev/mmcblk0"
ROOT_PART="${TARGET_DISK}p2"
EFI_PART="${TARGET_DISK}p1"
CRYPT_NAME="cryptroot"
MAPPER_PATH="/dev/mapper/${CRYPT_NAME}"
USERNAME="kevin"
HOSTNAME_VALUE="arch-laptop"
DEFAULT_PASS="password"

if [[ "${EUID}" -ne 0 ]]; then
  die "Run this as root from Arch ISO (root@archiso)."
fi

echo -e "\n${BOLD}${CYAN}=== Arch Chroot Recovery Config ===${NC}\n"

[[ -d /sys/firmware/efi ]] || die "UEFI not detected. Boot installer in UEFI mode."

info "Preparing encrypted root mapping"
if [[ ! -e "$MAPPER_PATH" ]]; then
  if [[ ! -b "$ROOT_PART" ]]; then
    die "Missing $ROOT_PART. Confirm target disk is mmcblk0."
  fi
  if ! echo -n "$DEFAULT_PASS" | cryptsetup open "$ROOT_PART" "$CRYPT_NAME" -; then
    warn "Default LUKS password failed. Enter passphrase manually."
    cryptsetup open "$ROOT_PART" "$CRYPT_NAME" || die "Unable to open LUKS root"
  fi
fi
ok "Encrypted root is available at $MAPPER_PATH"

info "Ensuring target mounts"
mountpoint -q /mnt || mount "$MAPPER_PATH" /mnt
mkdir -p /mnt/boot
mountpoint -q /mnt/boot || mount "$EFI_PART" /mnt/boot
ok "/mnt and /mnt/boot are mounted"

info "Running chroot recovery steps"
arch-chroot /mnt /bin/bash <<CHROOTEOF
set -euo pipefail

grep -n "en_US.UTF-8" /etc/locale.gen || true
sed -i 's/^#[[:space:]]*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "${HOSTNAME_VALUE}" > /etc/hostname
printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME_VALUE}.localdomain ${HOSTNAME_VALUE}\n' > /etc/hosts

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

pacman -S --noconfirm --needed linux-zen linux-zen-headers
pacman -Rns --noconfirm linux linux-headers 2>/dev/null || true
pacman -Rns --noconfirm linux-lts linux-lts-headers 2>/dev/null || true

pacman -S --noconfirm --needed plasma-meta kde-applications-meta sddm
systemctl enable NetworkManager sddm fstrim.timer

id ${USERNAME} >/dev/null 2>&1 || useradd -m -G wheel,audio,video,optical,storage -s /bin/bash ${USERNAME}
echo "${USERNAME}:${DEFAULT_PASS}" | chpasswd
echo "root:${DEFAULT_PASS}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true
bootctl --path=/boot install

LUKS_UUID="\$(blkid -s UUID -o value ${ROOT_PART})"
mkdir -p /boot/loader/entries

cat > /boot/loader/loader.conf <<EOF
default arch-zen.conf
timeout 5
console-mode max
editor no
EOF

cat > /boot/loader/entries/arch-zen.conf <<EOF
title   Arch Linux (zen)
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen.img
options cryptdevice=UUID=\${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rw quiet splash
EOF

find /boot/loader/entries -maxdepth 1 -type f \( -name '*linux.conf' -o -name '*lts.conf' \) -delete 2>/dev/null || true
CHROOTEOF

ok "Chroot recovery steps completed"

info "Finishing cleanup"
chown -R 1000:1000 "/mnt/home/${USERNAME}" 2>/dev/null || true
umount -R /mnt
cryptsetup close "$CRYPT_NAME" 2>/dev/null || true

ok "Recovery complete"
echo ""
echo "Login after reboot with:"
echo "  user: ${USERNAME}"
echo "  password: ${DEFAULT_PASS}"
echo "  disk unlock passphrase: ${DEFAULT_PASS}"
echo ""
echo "Run reboot when ready."
