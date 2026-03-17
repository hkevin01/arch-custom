#!/bin/bash
# =============================================================================
# ARCH LINUX AUTO-INSTALLER
# Kevin's Config: Zen Kernel + KDE Plasma + LUKS Encryption + systemd-boot
# =============================================================================
# Usage (from Arch ISO terminal):
#   curl -fsSL https://raw.githubusercontent.com/hkevin01/ubuntu-fix/main/arch-install.sh | bash
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

header()  { echo -e "\n${BOLD}${BLUE}==================================================${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}==================================================${NC}\n"; }
success() { echo -e "${GREEN}  [OK]  $1${NC}"; }
warn()    { echo -e "${YELLOW}  [!!]  $1${NC}"; }
err()     { echo -e "${RED}  [ERR] $1${NC}"; exit 1; }
info()    { echo -e "${CYAN}  [>>]  $1${NC}"; }
step()    { echo -e "\n${BOLD}  STEP $1: $2${NC}"; }

clear
echo ""
echo -e "${BOLD}${CYAN}  ================================================================"
echo "      ARCH LINUX AUTO-INSTALLER"
echo "      Zen Kernel  |  KDE Plasma 6  |  LUKS2 Encryption"
echo -e "  ================================================================${NC}"
echo ""

# --- PRE-CHECKS ---
header "PRE-FLIGHT CHECKS"

step "1/4" "Boot mode"
[[ -d /sys/firmware/efi ]] && success "UEFI mode confirmed" || err "BIOS mode - UEFI required"

step "2/4" "Internet connection"
if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
    warn "No internet! Connect to WiFi first:"
    echo "    iwctl"
    echo "    station wlan0 scan"
    echo "    station wlan0 get-networks"
    echo "    station wlan0 connect \"YourWiFi\""
    echo ""
    read -p "  Press Enter once connected..."
    ping -c 1 -W 5 archlinux.org &>/dev/null || err "No internet. Aborting."
fi
success "Internet OK"

step "3/4" "System clock"
timedatectl set-ntp true
success "NTP sync enabled"

step "4/4" "Keyring update"
pacman -Sy --noconfirm archlinux-keyring 2>/dev/null && success "Keyring updated" || warn "Keyring update failed (non-fatal)"

# --- DISK DETECTION ---
header "DISK DETECTION"

echo "  Detected block devices:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v loop
echo ""

TARGET_DISK=""
for dev in mmcblk0 nvme0n1 sda sdb vda; do
    if [[ -b "/dev/$dev" ]]; then
        REMOVABLE=$(cat /sys/block/$dev/removable 2>/dev/null || echo "1")
        if [[ "$REMOVABLE" == "0" ]]; then
            TARGET_DISK="/dev/$dev"
            break
        fi
    fi
done

if [[ -n "$TARGET_DISK" ]]; then
    DISK_SIZE=$(lsblk -d -o SIZE "$TARGET_DISK" | tail -1 | xargs)
    info "Auto-detected: $TARGET_DISK ($DISK_SIZE)"
    read -p "  Use $TARGET_DISK? [Y/n]: " USE_AUTO
    [[ "${USE_AUTO,,}" == "n" ]] && TARGET_DISK=""
fi

if [[ -z "$TARGET_DISK" ]]; then
    lsblk -d -o NAME,SIZE,TYPE,MODEL
    read -p "  Enter disk (e.g. /dev/sda or /dev/mmcblk0): " TARGET_DISK
    [[ -b "$TARGET_DISK" ]] || err "Device $TARGET_DISK not found"
fi

DISK_SIZE=$(lsblk -d -o SIZE "$TARGET_DISK" | tail -1 | xargs)

# Partition naming: mmcblk0 -> mmcblk0p1, sda -> sda1
if [[ "$TARGET_DISK" =~ mmcblk|nvme ]]; then
    EFI_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

success "Disk: $TARGET_DISK ($DISK_SIZE)"
info "EFI partition:  $EFI_PART (512MB, FAT32)"
info "Root partition: $ROOT_PART (rest, LUKS2 -> ext4)"

# --- CREDENTIALS ---
header "SETUP CREDENTIALS"

read -p "  Hostname [archlinux]: " HOSTNAME
HOSTNAME=${HOSTNAME:-archlinux}

echo ""
read -p "  Username: " USERNAME
while [[ -z "$USERNAME" || "$USERNAME" =~ [^a-z0-9_-] ]]; do
    warn "Lowercase letters/numbers/- only"
    read -p "  Username: " USERNAME
done

echo ""
while true; do
    read -s -p "  User password: " USER_PASS; echo ""
    read -s -p "  Confirm password: " USER_PASS2; echo ""
    [[ "$USER_PASS" == "$USER_PASS2" ]] && break
    warn "Passwords don't match"
done

echo ""
info "Encryption password - you type this EVERY time you boot:"
while true; do
    read -s -p "  Encryption password: " LUKS_PASS; echo ""
    read -s -p "  Confirm: " LUKS_PASS2; echo ""
    [[ "$LUKS_PASS" == "$LUKS_PASS2" ]] && break
    warn "Passwords don't match"
done

echo ""
read -p "  Timezone [America/Chicago]: " TIMEZONE
TIMEZONE=${TIMEZONE:-America/Chicago}

read -p "  Locale [en_US.UTF-8]: " LOCALE
LOCALE=${LOCALE:-en_US.UTF-8}

# --- CONFIRMATION ---
header "INSTALLATION SUMMARY - PLEASE CONFIRM"

echo -e "  ${CYAN}Disk:${NC}       $TARGET_DISK ($DISK_SIZE)  ${RED}${BOLD}<-- WIPED${NC}"
echo -e "  ${CYAN}Hostname:${NC}   $HOSTNAME"
echo -e "  ${CYAN}Username:${NC}   $USERNAME (sudo)"
echo -e "  ${CYAN}Kernel:${NC}     linux-zen"
echo -e "  ${CYAN}Desktop:${NC}    KDE Plasma 6 (SDDM)"
echo -e "  ${CYAN}Audio:${NC}      PipeWire"
echo -e "  ${CYAN}Boot:${NC}       systemd-boot (UEFI)"
echo -e "  ${CYAN}Encrypt:${NC}    LUKS2 on root"
echo -e "  ${CYAN}FS:${NC}         ext4"
echo -e "  ${CYAN}Timezone:${NC}   $TIMEZONE"
echo -e "  ${CYAN}Locale:${NC}     $LOCALE"
echo -e "  ${CYAN}Extras:${NC}     firefox git vim htop neofetch wget curl p7zip"
echo ""
echo -e "  ${RED}${BOLD}ALL DATA ON $TARGET_DISK WILL BE DESTROYED PERMANENTLY${NC}"
echo ""
read -p "  Type INSTALL to continue or anything else to abort: " GO
[[ "$GO" == "INSTALL" ]] || { echo "Aborted."; exit 0; }

# --- PARTITIONING ---
header "PARTITIONING"

info "Wiping $TARGET_DISK..."
sgdisk --zap-all "$TARGET_DISK" &>/dev/null
success "Old partitions wiped"

info "Creating GPT layout..."
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" \
       -n 2:0:0     -t 2:8309 -c 2:"LUKS Root" \
       "$TARGET_DISK"
partprobe "$TARGET_DISK"
sleep 2

lsblk "$TARGET_DISK"
[[ -b "$EFI_PART" && -b "$ROOT_PART" ]] || err "Partitions missing after create"
success "Partitions: $EFI_PART (EFI) and $ROOT_PART (LUKS)"

# --- LUKS ENCRYPTION ---
header "LUKS2 ENCRYPTION SETUP"

info "Formatting $ROOT_PART with LUKS2..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --hash sha512 \
    --key-size 512 \
    --iter-time 3000 \
    --batch-mode \
    "$ROOT_PART" -
success "LUKS2 container created on $ROOT_PART"

info "Opening LUKS container..."
echo -n "$LUKS_PASS" | cryptsetup open "$ROOT_PART" cryptroot -
success "Opened as /dev/mapper/cryptroot"

# --- FORMAT ---
header "FORMATTING FILESYSTEMS"

mkfs.fat -F32 -n "EFI" "$EFI_PART"
success "EFI: FAT32"

mkfs.ext4 -L "arch-root" /dev/mapper/cryptroot
success "Root: ext4"

# --- MOUNT ---
header "MOUNTING"

mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot
success "/ mounted from /dev/mapper/cryptroot"
success "/boot mounted from $EFI_PART"

# --- BASE INSTALL ---
header "BASE SYSTEM INSTALL (pacstrap)"
info "Installing base packages - this takes a few minutes..."

LUKS_UUID=$(blkid -s UUID -o value "$ROOT_PART")
info "LUKS partition UUID: $LUKS_UUID"

pacstrap -K /mnt \
    base base-devel \
    linux-zen linux-zen-headers linux-firmware \
    intel-ucode amd-ucode \
    networkmanager \
    vim nano git wget curl sudo \
    cryptsetup e2fsprogs dosfstools \
    efibootmgr \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    2>&1 | tail -5

success "Base system installed to /mnt"

# --- FSTAB ---
header "FSTAB"
genfstab -U /mnt >> /mnt/etc/fstab
success "fstab generated"

# --- CHROOT CONFIG ---
header "SYSTEM CONFIGURATION (chroot)"

arch-chroot /mnt /bin/bash <<CHROOTEOF
set -euo pipefail

echo "  >> Timezone..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

echo "  >> Locale..."
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "  >> Hostname..."
echo "${HOSTNAME}" > /etc/hostname
printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}\n' > /etc/hosts

echo "  >> Configuring mkinitcpio for encryption..."
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P 2>&1 | tail -3

echo "  >> Installing KDE Plasma (patience required)..."
pacman -S --noconfirm --needed \
    plasma \
    plasma-wayland-session \
    kde-applications \
    sddm \
    firefox \
    htop neofetch fastfetch \
    p7zip unzip zip \
    2>&1 | tail -5

echo "  >> Enabling services..."
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable fstrim.timer

echo "  >> Creating user: ${USERNAME}..."
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd
echo "root:${USER_PASS}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "  >> Installing systemd-boot..."
bootctl install

mkdir -p /boot/loader/entries

cat > /boot/loader/loader.conf <<LOADER
default arch-zen.conf
timeout 5
console-mode max
editor no
LOADER

cat > /boot/loader/entries/arch-zen.conf <<ENTRY
title   Arch Linux (zen)
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen.img
options cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rw quiet splash
ENTRY

cat > /boot/loader/entries/arch-zen-fallback.conf <<ENTRYFB
title   Arch Linux (zen, fallback initramfs)
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux-zen-fallback.img
options cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rw
ENTRYFB

echo ""
echo "  [OK] Boot entries written for linux-zen"
echo "  [OK] cryptdevice UUID = ${LUKS_UUID}"
echo ""
CHROOTEOF

success "Chroot configuration complete"

# --- DONE ---
header "INSTALLATION COMPLETE"

echo -e "${GREEN}${BOLD}"
echo "  +--------------------------------------------------+"
echo "  |   Arch Linux installed successfully!   :)        |"
echo "  +--------------------------------------------------+"
echo -e "${NC}"
echo -e "  ${CYAN}Summary:${NC}"
echo "   - linux-zen kernel"
echo "   - KDE Plasma 6 + SDDM"
echo "   - LUKS2 full disk encryption"
echo "   - systemd-boot"
echo "   - PipeWire audio"
echo "   - NetworkManager"
echo ""
echo -e "  ${YELLOW}First boot:${NC}"
echo "   1. LUKS password prompt -> type your encryption password"
echo "   2. SDDM login screen -> log in as: $USERNAME"
echo "   3. KDE Plasma desktop"
echo ""
echo -e "  ${BOLD}Remove USB and reboot:${NC}"
echo ""
echo "    umount -R /mnt"
echo "    cryptsetup close cryptroot"
echo "    reboot"
echo ""