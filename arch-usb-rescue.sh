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

if [[ "${EUID}" -ne 0 ]]; then
  die "Run as root from Arch USB."
fi

echo -e "\n${BOLD}${CYAN}=== Arch USB Rescue (Boot + Wi-Fi + RTL8821CE) ===${NC}\n"
echo "This script assumes Wi-Fi is already connected from USB environment (e.g. iwctl)."
echo ""

[[ -d /sys/firmware/efi ]] || die "UEFI not detected. Reboot USB in UEFI mode."

if ! ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
  warn "No internet detected. Connect first, then re-run."
  echo "Quick Wi-Fi from Arch ISO:"
  echo "  iwctl"
  echo "  device list"
  echo "  station wlan0 scan"
  echo "  station wlan0 get-networks"
  echo "  station wlan0 connect YOUR_SSID"
  echo "  exit"
  die "Internet is required for package repair."
fi

cleanup_mounts() {
  swapoff -a 2>/dev/null || true
  umount -R /mnt 2>/dev/null || true
}

open_luks() {
  if [[ -e "${MAPPER_PATH}" ]]; then
    ok "LUKS mapping already open at ${MAPPER_PATH}"
    return 0
  fi

  [[ -b "${ROOT_PART}" ]] || die "Missing root partition ${ROOT_PART}"

  info "Opening LUKS root ${ROOT_PART} as ${CRYPT_NAME}"
  if ! echo -n "${DEFAULT_PASS}" | cryptsetup open "${ROOT_PART}" "${CRYPT_NAME}" -; then
    warn "Default passphrase failed. Enter passphrase manually."
    cryptsetup open "${ROOT_PART}" "${CRYPT_NAME}" || die "Could not open LUKS root"
  fi
  ok "LUKS root opened"
}

mount_target() {
  [[ -b "${EFI_PART}" ]] || die "Missing EFI partition ${EFI_PART}"

  info "Mounting target system"
  mkdir -p /mnt /mnt/boot
  mount "${MAPPER_PATH}" /mnt
  mount "${EFI_PART}" /mnt/boot
  ok "Mounted ${MAPPER_PATH} -> /mnt and ${EFI_PART} -> /mnt/boot"
}

chroot_repair() {
  info "Running repair operations inside chroot"

  arch-chroot /mnt /bin/bash -s <<'CHROOTEOF'
set -euo pipefail

log() { echo "[chroot] $*"; }

log "Refreshing package database"
pacman -Sy --noconfirm

log "Installing core repair and Wi-Fi packages"
pacman -S --noconfirm --needed \
  networkmanager iwd wpa_supplicant iw wireless_tools rfkill \
  linux-firmware linux-firmware-realtek \
  base-devel git dkms efibootmgr

for k in linux linux-zen linux-lts; do
  if pacman -Q "$k" >/dev/null 2>&1; then
    pacman -S --noconfirm --needed "${k}-headers"
  fi
done

log "Ensuring locale"
if grep -Eq '^#?en_US.UTF-8 UTF-8' /etc/locale.gen; then
  sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen || true
fi
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

log "Rebuilding initramfs"
if grep -q '^HOOKS=' /etc/mkinitcpio.conf; then
  sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
fi
mkinitcpio -P

if [[ -d /sys/firmware/efi/efivars ]]; then
  mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true
fi

if [[ -d /boot/loader ]]; then
  log "Detected systemd-boot installation, repairing bootctl"
  bootctl --path=/boot install || true
fi

if [[ -d /boot/grub || -f /etc/default/grub ]]; then
  if pacman -Q grub >/dev/null 2>&1; then
    log "Detected GRUB installation, reinstalling GRUB"
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || true
    grub-mkconfig -o /boot/grub/grub.cfg || true
  fi
fi

log "Enabling NetworkManager"
systemctl enable NetworkManager || true

if lspci -nn | grep -Eqi '10ec:c821|rtl8821ce'; then
  log "RTL8821CE detected; preparing AUR helper for optional dkms driver"
  username="$(awk -F: '$3 == 1000 {print $1; exit}' /etc/passwd || true)"
  if [[ -n "$username" ]]; then
    homedir="/home/${username}"
    install -d -m 755 "$homedir/Projects" "$homedir/.cache"
    chown -R "$username:$username" "$homedir/Projects" "$homedir/.cache"

    if ! command -v yay >/dev/null 2>&1; then
      su - "$username" -c 'cd ~/Projects && rm -rf yay && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm' || true
    fi

    cat > /usr/local/sbin/install-rtl8821ce-aur.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this as normal user, not root." >&2
  exit 1
fi
sudo pacman -S --noconfirm --needed dkms base-devel git linux-headers linux-zen-headers linux-lts-headers
if ! command -v yay >/dev/null 2>&1; then
  cd ~/Projects
  rm -rf yay
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
fi
yay -S --noconfirm rtl8821ce-dkms-git
echo 'blacklist rtw88_8821ce' | sudo tee /etc/modprobe.d/blacklist-rtw88-8821ce.conf >/dev/null
sudo mkinitcpio -P
echo "Done. Reboot recommended."
EOS
    chmod +x /usr/local/sbin/install-rtl8821ce-aur.sh
  fi
fi

log "Repair operations completed"
CHROOTEOF

  ok "Chroot repair completed"
}

finalize() {
  info "Cleaning up mounts"
  umount -R /mnt 2>/dev/null || true
  cryptsetup close "${CRYPT_NAME}" 2>/dev/null || true
  ok "Cleanup done"
}

cleanup_mounts
open_luks
mount_target
chroot_repair
finalize

echo ""
ok "Rescue complete"
echo "Next: reboot and test boot + Wi-Fi."
echo "If rtl8821ce is still unstable after reboot, run as your normal user:"
echo "  /usr/local/sbin/install-rtl8821ce-aur.sh"