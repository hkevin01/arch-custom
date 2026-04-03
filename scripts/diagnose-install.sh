#!/usr/bin/env bash
# diagnose-install.sh — capture system state for boot/install debugging
# Run from: emergency shell, live USB chroot, or an installed Arch session.
# Output is written to a timestamped log file and printed to stdout.
#
# Usage:
#   bash diagnose-install.sh
#   bash diagnose-install.sh > /root/diag.log 2>&1
#   curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/scripts/diagnose-install.sh | bash

set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
section() { echo -e "\n${CYAN}══ $1 ══${NC}"; }
ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!!]${NC} $1"; }

LOG_DIR="/root"
[[ -w "$LOG_DIR" ]] || LOG_DIR="/tmp"
LOG="$LOG_DIR/arch-diag-$(date +%Y%m%d-%H%M%S).log"

# Tee everything to log and stdout.
exec > >(tee -a "$LOG") 2>&1

echo "arch-custom install diagnostics — $(date -Is)"
echo "Log: $LOG"
echo ""

section "Boot Mode"
if [[ -d /sys/firmware/efi ]]; then
  ok "UEFI mode"
  ls /sys/firmware/efi/efivars/ 2>/dev/null | wc -l | xargs -I{} echo "  {} EFI variables"
else
  warn "BIOS/legacy mode or EFI not mounted"
fi

section "Kernel and Cmdline"
uname -a
echo "cmdline: $(cat /proc/cmdline 2>/dev/null || echo unavailable)"

section "Block Devices"
lsblk -f 2>/dev/null || true
echo ""
blkid 2>/dev/null || true

section "LUKS / Device Mapper"
ls /dev/mapper/ 2>/dev/null || echo "  (no mapper devices)"
dmsetup ls 2>/dev/null || true

section "Mount Table"
findmnt 2>/dev/null || mount 2>/dev/null || echo "  (unable to read mounts)"

section "fstab"
cat /etc/fstab 2>/dev/null || cat /mnt/etc/fstab 2>/dev/null || echo "  (fstab not found)"

section "systemd-boot"
if [[ -d /boot/loader ]] || [[ -d /mnt/boot/loader ]]; then
  BOOT_ROOT="/boot"
  [[ -d /mnt/boot/loader ]] && BOOT_ROOT="/mnt/boot"
  echo "loader.conf:"
  cat "$BOOT_ROOT/loader/loader.conf" 2>/dev/null || echo "  (missing)"
  echo ""
  echo "boot entries:"
  ls -1 "$BOOT_ROOT/loader/entries/" 2>/dev/null || echo "  (none)"
  for e in "$BOOT_ROOT"/loader/entries/*.conf; do
    [[ -f "$e" ]] || continue
    echo ""
    echo "--- $e ---"
    cat "$e"
  done
  if [[ -f "$BOOT_ROOT/loader/random-seed" ]]; then
    stat -c '%n  perms=%a  owner=%U:%G' "$BOOT_ROOT/loader/random-seed"
  fi
else
  warn "No /boot/loader directory found"
fi

section "GRUB (if present)"
if [[ -d /boot/grub ]] || [[ -d /mnt/boot/grub ]]; then
  ok "GRUB detected"
  BOOT_ROOT="/boot"
  [[ -d /mnt/boot/grub ]] && BOOT_ROOT="/mnt/boot"
  cat "$BOOT_ROOT/grub/grub.cfg" 2>/dev/null | grep -E '^menuentry|linux|initrd' | head -40 || true
else
  echo "  GRUB not present"
fi

section "mkinitcpio Config"
MKINIT="/etc/mkinitcpio.conf"
[[ -f /mnt/etc/mkinitcpio.conf ]] && MKINIT="/mnt/etc/mkinitcpio.conf"
if [[ -f "$MKINIT" ]]; then
  grep -E '^HOOKS=|^MODULES=' "$MKINIT"
else
  warn "mkinitcpio.conf not found at $MKINIT"
fi

section "Installed Kernels"
if command -v pacman >/dev/null 2>&1; then
  pacman -Q linux linux-zen linux-lts 2>/dev/null || true
elif [[ -d /mnt ]]; then
  arch-chroot /mnt pacman -Q linux linux-zen linux-lts 2>/dev/null || true
fi
echo "vmlinuz files in /boot:"
find /boot /mnt/boot -maxdepth 1 -name 'vmlinuz-*' 2>/dev/null || echo "  (none)"

section "Network"
ip -brief link 2>/dev/null || ip link 2>/dev/null || echo "  ip command not available"
echo ""
ip -brief addr 2>/dev/null || true
echo ""
rfkill list 2>/dev/null || true
echo ""
echo "resolv.conf:"
cat /etc/resolv.conf 2>/dev/null | head -5 || echo "  (missing)"

section "Wi-Fi / RTL8821CE"
if lspci -nn 2>/dev/null | grep -Eqi '10ec:c821|rtl8821ce'; then
  warn "RTL8821CE detected — requires rtl8821ce-dkms-git AUR driver"
  dmesg 2>/dev/null | grep -i rtl | tail -10 || true
else
  echo "  RTL8821CE not detected"
fi

section "pacman Lock"
for lock in /var/lib/pacman/db.lck /mnt/var/lib/pacman/db.lck; do
  if [[ -f "$lock" ]]; then
    warn "Stale pacman lock: $lock"
  fi
done

section "systemctl (if running)"
if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
  systemctl --no-pager -l status boot.mount local-fs.target 2>/dev/null || true
else
  echo "  systemd not running (ISO / chroot mode)"
fi

section "Journal (last 80 lines)"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -xb --no-pager 2>/dev/null | tail -80 || true
else
  dmesg 2>/dev/null | tail -80 || echo "  (no journal)"
fi

echo ""
ok "Diagnostics complete"
echo "Full log saved to: $LOG"
echo ""
echo "Share $LOG when asking for help."
