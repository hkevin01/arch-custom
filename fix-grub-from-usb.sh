#!/usr/bin/env bash
# fix-grub-from-usb.sh — reinstall GRUB EFI from Arch USB rescue environment
# Usage: sudo bash fix-grub-from-usb.sh
#   or:  LUKS_PASSPHRASE=yourpass sudo -E bash fix-grub-from-usb.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok()   { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${YELLOW}[!!] $1${NC}"; }
die()  { echo -e "${RED}[ERR] $1${NC}"; exit 1; }

TARGET_DISK="${TARGET_DISK:-/dev/mmcblk0}"
EFI_PART="${EFI_PART:-${TARGET_DISK}p1}"
ROOT_PART="${ROOT_PART:-${TARGET_DISK}p2}"
CRYPT_NAME="${CRYPT_NAME:-cryptroot}"
LUKS_PASSPHRASE="${LUKS_PASSPHRASE:-}"
PASS_ATTEMPTS="${PASS_ATTEMPTS:-3}"
MAPPER_PATH="/dev/mapper/${CRYPT_NAME}"

TARGET_MOUNTED=0
CRYPT_OPENED=0

cleanup() {
  [[ "$TARGET_MOUNTED" -eq 1 ]] && { umount -R /mnt >/dev/null 2>&1 || true; }
  [[ "$CRYPT_OPENED"   -eq 1 ]] && { cryptsetup close "$CRYPT_NAME" >/dev/null 2>&1 || true; }
}
trap cleanup EXIT

[[ "${EUID}" -ne 0 ]] && die "Run as root."
[[ -b "$EFI_PART"  ]] || die "EFI partition not found: $EFI_PART"
[[ -b "$ROOT_PART" ]] || die "Root partition not found: $ROOT_PART"

# ── LUKS unlock ──────────────────────────────────────────────────────────────
open_luks() {
  local part="$1" i passphrase

  if [[ -n "$LUKS_PASSPHRASE" ]]; then
    info "Trying LUKS_PASSPHRASE env var..."
    if printf '%s' "$LUKS_PASSPHRASE" | cryptsetup open "$part" "$CRYPT_NAME" --key-file -; then
      return 0
    fi
    warn "LUKS_PASSPHRASE did not unlock $part"
  fi

  for i in $(seq 1 "$PASS_ATTEMPTS"); do
    info "LUKS unlock attempt $i/$PASS_ATTEMPTS for $part"
    if [[ -r /dev/tty ]]; then
      read -r -s -p "Enter LUKS passphrase: " passphrase </dev/tty
      echo "" >/dev/tty
      if printf '%s' "$passphrase" | cryptsetup open "$part" "$CRYPT_NAME" --key-file -; then
        unset passphrase; return 0
      fi
      unset passphrase
    elif cryptsetup open "$part" "$CRYPT_NAME"; then
      return 0
    fi
    warn "Incorrect passphrase"
  done
  return 1
}

# ── Check if already open ────────────────────────────────────────────────────
if [[ -b "$MAPPER_PATH" ]]; then
  info "LUKS mapper already open at $MAPPER_PATH"
  CRYPT_OPENED=1
else
  open_luks "$ROOT_PART" || die "Could not unlock LUKS on $ROOT_PART"
  CRYPT_OPENED=1
  [[ -b "$MAPPER_PATH" ]] || die "Mapper not found after unlock: $MAPPER_PATH"
fi

# ── Mount ────────────────────────────────────────────────────────────────────
if ! mountpoint -q /mnt; then
  info "Mounting root..."
  mount "$MAPPER_PATH" /mnt
fi
mkdir -p /mnt/boot
if ! mountpoint -q /mnt/boot; then
  info "Mounting EFI..."
  mount "$EFI_PART" /mnt/boot
fi
TARGET_MOUNTED=1

[[ -f /etc/resolv.conf ]] && cp -f /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || true

EFI_UUID="$(blkid -s UUID -o value "$EFI_PART")"
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
info "EFI UUID : $EFI_UUID"
info "ROOT UUID: $ROOT_UUID"

# ── Chroot repair ────────────────────────────────────────────────────────────
info "Entering chroot to reinstall GRUB..."
arch-chroot /mnt env ROOT_UUID="$ROOT_UUID" /bin/bash <<'CHROOTEOF'
set -euo pipefail

echo "[chroot] Ensure grub is installed..."
pacman -Sy --noconfirm
pacman -S --noconfirm --needed grub efibootmgr os-prober

echo "[chroot] Configuring /etc/default/grub for LUKS..."
GRUB_DEFAULT=/etc/default/grub

# Enable cryptodisk support so GRUB can unlock LUKS
grep -q 'GRUB_ENABLE_CRYPTODISK' "$GRUB_DEFAULT" \
  && sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' "$GRUB_DEFAULT" \
  || echo 'GRUB_ENABLE_CRYPTODISK=y' >> "$GRUB_DEFAULT"

# Set the cryptdevice kernel parameter so initramfs unlocks root
CURRENT_CMDLINE="$(grep '^GRUB_CMDLINE_LINUX=' "$GRUB_DEFAULT" | head -1 | cut -d'"' -f2)"
if [[ -n "$ROOT_UUID" ]] && ! echo "$CURRENT_CMDLINE" | grep -q 'cryptdevice'; then
  NEW_CMDLINE="cryptdevice=UUID=${ROOT_UUID}:cryptroot root=/dev/mapper/cryptroot ${CURRENT_CMDLINE}"
  sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"${NEW_CMDLINE}\"|" "$GRUB_DEFAULT"
  echo "[chroot] Set GRUB_CMDLINE_LINUX → $NEW_CMDLINE"
fi

# Remove old stale GRUB EFI entries
echo "[chroot] Removing stale GRUB EFI files if present..."
rm -f /boot/EFI/GRUB/grubx64.efi 2>/dev/null || true

echo "[chroot] Running grub-install..."
grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot \
  --bootloader-id=GRUB \
  --recheck \
  --verbose 2>&1 | tail -20

echo "[chroot] Generating grub.cfg..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[chroot] Verifying normal.mod exists..."
ls /boot/grub/x86_64-efi/normal.mod \
  && echo "[chroot] normal.mod OK" \
  || echo "[chroot] WARNING: normal.mod NOT found — install may have failed"

echo "[chroot] Done."
CHROOTEOF

# ── Unmount cleanly (trap handles remainder on error) ────────────────────────
TARGET_MOUNTED=0
umount -R /mnt
CRYPT_OPENED=0
cryptsetup close "$CRYPT_NAME"

ok "GRUB reinstalled. Remove USB and reboot."
echo ""
echo "  If you still land at grub rescue>, run:"
echo "    ls"
echo "    ls (hd0,gpt1)/grub/x86_64-efi/normal.mod"
echo "    set prefix=(hd0,gpt1)/grub"
echo "    set root=(hd0,gpt1)"
echo "    insmod normal && normal"
