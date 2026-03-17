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

BOOT_PART="${BOOT_PART:-/dev/mmcblk0p1}"
BOOT_MNT="${BOOT_MNT:-/boot}"
FSTAB_FILE="/etc/fstab"
LOG_FILE="/root/boot-fix-debug-$(date +%Y%m%d-%H%M%S).log"

if [[ "${EUID}" -ne 0 ]]; then
  die "Run as root from emergency shell."
fi

exec > >(tee -a "$LOG_FILE") 2>&1

snapshot() {
  echo ""
  info "Debug snapshot"
  echo "date: $(date -Is 2>/dev/null || date)"
  echo "kernel: $(uname -a)"
  echo "cmdline: $(cat /proc/cmdline 2>/dev/null || true)"
  echo ""
  echo "--- lsblk -f ---"
  lsblk -f || true
  echo ""
  echo "--- blkid ---"
  blkid || true
  echo ""
  echo "--- findmnt ---"
  findmnt || true
  echo ""
  echo "--- /etc/fstab ---"
  cat "$FSTAB_FILE" || true
  echo ""
  echo "--- systemctl status boot.mount local-fs.target ---"
  systemctl --no-pager -l status boot.mount local-fs.target || true
  echo ""
  echo "--- journal tail ---"
  journalctl -xb --no-pager | tail -120 || true
}

repair_boot_mount() {
  [[ -b "$BOOT_PART" ]] || die "Boot partition not found: $BOOT_PART"
  [[ -f "$FSTAB_FILE" ]] || die "Missing $FSTAB_FILE"

  info "Remounting / read-write"
  mount -o remount,rw / || die "Could not remount / as read-write"

  info "Running FAT repair on $BOOT_PART"
  fsck.vfat -a "$BOOT_PART" || true

  info "Preparing mountpoint $BOOT_MNT"
  mkdir -p "$BOOT_MNT"
  mountpoint -q "$BOOT_MNT" && umount "$BOOT_MNT" || true

  BOOT_UUID="$(blkid -s UUID -o value "$BOOT_PART" || true)"
  BOOT_TYPE="$(blkid -s TYPE -o value "$BOOT_PART" || true)"
  [[ -n "$BOOT_UUID" ]] || die "Could not resolve UUID for $BOOT_PART"
  [[ -n "$BOOT_TYPE" ]] || BOOT_TYPE="vfat"

  info "Boot UUID detected: $BOOT_UUID"
  info "Boot FS type detected: $BOOT_TYPE"

  cp -a "$FSTAB_FILE" "${FSTAB_FILE}.bak.$(date +%Y%m%d-%H%M%S)"

  info "Rewriting /boot entry in $FSTAB_FILE"
  sed -i '\|[[:space:]]/boot[[:space:]]|d' "$FSTAB_FILE"
  echo "UUID=${BOOT_UUID}  /boot  ${BOOT_TYPE}  rw,nofail,x-systemd.device-timeout=10,umask=0077  0  2" >> "$FSTAB_FILE"

  info "Testing direct mount"
  mount -t "$BOOT_TYPE" -o rw,umask=0077 "$BOOT_PART" "$BOOT_MNT" || return 1
  ok "Direct mount succeeded"

  if [[ -f "$BOOT_MNT/loader/random-seed" ]]; then
    chmod 600 "$BOOT_MNT/loader/random-seed" || true
    chown root:root "$BOOT_MNT/loader/random-seed" || true
    ok "Hardened $BOOT_MNT/loader/random-seed permissions"
  fi

  systemctl daemon-reload || true
  systemctl restart local-fs.target || true
}

echo ""
info "Starting debug-heavy /boot repair"
info "Log file: $LOG_FILE"

snapshot

if ! repair_boot_mount; then
  warn "Primary repair path failed. Capturing post-failure diagnostics."
  snapshot
  die "Repair failed. Inspect $LOG_FILE and journalctl -xb for exact mount error."
fi

echo ""
ok "Repair path completed"
echo "Log saved at: $LOG_FILE"
echo "Now run:"
echo "  findmnt /boot"
echo "  systemctl --no-pager -l status boot.mount local-fs.target"
echo "If both are healthy:"
echo "  reboot"