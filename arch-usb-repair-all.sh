#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok() { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${YELLOW}[!!] $1${NC}"; }
die() { echo -e "${RED}[ERR] $1${NC}"; exit 1; }

TARGET_DISK="${TARGET_DISK:-/dev/mmcblk0}"
EFI_PART="${EFI_PART:-${TARGET_DISK}p1}"
ROOT_PART="${ROOT_PART:-${TARGET_DISK}p2}"
CRYPT_NAME="${CRYPT_NAME:-cryptroot}"
MAPPER_PATH="/dev/mapper/${CRYPT_NAME}"
DEFAULT_PASS="${DEFAULT_PASS:-password}"
SKIP_POST_VALIDATION="${SKIP_POST_VALIDATION:-false}"

if [[ "${EUID}" -ne 0 ]]; then
  die "Run as root from Arch USB."
fi

echo ""
echo -e "${BOLD}${CYAN}=== Arch USB All-In-One Repair + Validate ===${NC}"
echo ""

[[ -d /sys/firmware/efi ]] || die "UEFI mode not detected. Reboot USB in UEFI mode."
[[ -b "$EFI_PART" ]] || die "EFI partition not found: $EFI_PART"
[[ -b "$ROOT_PART" ]] || die "Root partition not found: $ROOT_PART"

info "Checking network before pulling repair script"
if ! ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
  die "No internet. Connect first with iwctl, then rerun."
fi

info "Running primary repair script"
rm -f /var/lib/pacman/db.lck
curl --http1.1 -fsSL "https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-usb-rescue.sh" | DEFAULT_PASS="$DEFAULT_PASS" bash

if [[ "$SKIP_POST_VALIDATION" == "true" ]]; then
  warn "Post-repair validation skipped (SKIP_POST_VALIDATION=true)."
  echo ""
  echo "Commands:"
  echo "  reboot"
  exit 0
fi

info "Post-repair validation: remounting target"
cryptsetup close "$CRYPT_NAME" 2>/dev/null || true
if ! echo -n "$DEFAULT_PASS" | cryptsetup open "$ROOT_PART" "$CRYPT_NAME" - 2>/dev/null; then
  warn "Default passphrase failed for post-validation (no key available with this passphrase)."
  warn "Primary repair already ran; skipping remount validation to avoid false failure."
  echo ""
  echo "If you want to validate manually, run:"
  echo "  cryptsetup open $ROOT_PART $CRYPT_NAME"
  echo "  mount /dev/mapper/$CRYPT_NAME /mnt && mount $EFI_PART /mnt/boot"
  echo ""
  echo "Then reboot and test normal boot."
  exit 0
fi
mkdir -p /mnt /mnt/boot
mount "$MAPPER_PATH" /mnt
mount "$EFI_PART" /mnt/boot

info "Validation checks"
echo ""
echo "--- /boot mount ---"
arch-chroot /mnt findmnt /boot || die "/boot is not mounted in chroot"

echo ""
echo "--- fstab /boot entry ---"
grep ' /boot ' /mnt/etc/fstab || die "Missing /boot entry in /mnt/etc/fstab"

echo ""
echo "--- loader entries ---"
arch-chroot /mnt ls -1 /boot/loader/entries || true
if ! arch-chroot /mnt test -f /boot/loader/entries/arch-zen.conf; then
  die "Missing /boot/loader/entries/arch-zen.conf"
fi

echo ""
echo "--- random-seed permissions ---"
if arch-chroot /mnt test -f /boot/loader/random-seed; then
  arch-chroot /mnt stat -c '%n %a %U:%G' /boot/loader/random-seed
else
  warn "/boot/loader/random-seed does not exist (this can be normal on some setups)."
fi

ok "Validation complete"

echo ""
warn "Next steps"
echo "1) Remove USB before reboot"
echo "2) Reboot into installed Arch"
echo ""
echo "Commands:"
echo "  umount -R /mnt"
echo "  cryptsetup close $CRYPT_NAME"
echo "  reboot"
