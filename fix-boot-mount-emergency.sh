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

if [[ "${EUID}" -ne 0 ]]; then
  die "Run as root from emergency shell."
fi

BOOT_PART="${BOOT_PART:-/dev/mmcblk0p1}"
FSTAB_FILE="/etc/fstab"

echo ""
info "Emergency /boot mount repair starting"

[[ -b "$BOOT_PART" ]] || die "Boot partition $BOOT_PART not found. Set BOOT_PART=/dev/yourbootpart and retry."
[[ -f "$FSTAB_FILE" ]] || die "Missing $FSTAB_FILE"

if ! mountpoint -q /; then
  die "Root filesystem is not mounted."
fi

info "Remounting / as read-write"
mount -o remount,rw / || die "Could not remount root read-write"

info "Collecting boot partition UUID"
BOOT_UUID="$(blkid -s UUID -o value "$BOOT_PART" || true)"
[[ -n "$BOOT_UUID" ]] || die "Could not read UUID from $BOOT_PART"
ok "Boot UUID: $BOOT_UUID"

info "Backing up fstab"
cp -a "$FSTAB_FILE" "${FSTAB_FILE}.bak.$(date +%Y%m%d-%H%M%S)"

info "Repairing FAT filesystem on $BOOT_PART"
fsck.vfat -a "$BOOT_PART" || true

info "Ensuring /boot entry exists and points to current UUID"
if grep -Eq '^[^#].+[[:space:]]+/boot[[:space:]]+vfat' "$FSTAB_FILE"; then
  sed -i -E "s|^[^#]+([[:space:]]+/boot[[:space:]]+vfat[[:space:]]+).*$|UUID=${BOOT_UUID}\1rw,nofail,x-systemd.device-timeout=10,umask=0077 0 2|" "$FSTAB_FILE"
else
  echo "UUID=${BOOT_UUID}  /boot  vfat  rw,nofail,x-systemd.device-timeout=10,umask=0077  0  2" >> "$FSTAB_FILE"
fi

mkdir -p /boot

if mountpoint -q /boot; then
  umount /boot || true
fi

info "Testing /boot mount"
mount /boot || die "Mount /boot failed even after repair. Check: journalctl -xb"
ok "/boot mounted successfully"

if [[ -f /boot/loader/random-seed ]]; then
  chmod 600 /boot/loader/random-seed || true
  chown root:root /boot/loader/random-seed || true
  ok "Hardened /boot/loader/random-seed permissions"
fi

echo ""
ok "Repair complete"
echo "Run these now:"
echo "  systemctl daemon-reload"
echo "  systemctl restart local-fs.target"
echo "If no errors, reboot:"
echo "  reboot"
