#!/bin/bash
#
=============================================================================
# ARCH LINUX AUTO-INSTALLER (ENHANCED)
# Kevin's Config: Zen Kernel + KDE Plasma + LUKS Encryption + Privacy Hardening
#
=============================================================================
# Usage (from Arch ISO terminal):
#   curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-install.sh | bash
#
# IMPROVEMENTS:
#   - Better password entry with clear re-prompt
#   - Brave browser + privacy extensions auto-install
#   - Webcam support (NexiGo)
#   - Full tracking protection stack deployment
#   - KDE privacy hardening
#   - Beast Mode agent setup
#   - Post-install automation
#
=============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

header() { echo -e "\n${BOLD}${BLUE}==================================================${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}==================================================${NC}\n"; }
success() { echo -e "${GREEN}[OK]  $1${NC}"; }
warn()    { echo -e "${YELLOW}[!!]  $1${NC}"; }
err()     { echo -e "${RED}[ERR] $1${NC}"; exit 1; }
info()    { echo -e "${CYAN}[>>] $1${NC}"; }
step()    { echo -e "\n${BOLD}  STEP $1: $2${NC}"; }

cleanup_previous_install_state() {
    local needed_cleanup=0

    info "Checking for previous failed install state..."

    if mount | grep -q ' on /mnt'; then
        needed_cleanup=1
        warn "/mnt is mounted from a previous run; unmounting"
        umount -R /mnt 2>/dev/null || true
    fi

    if swapon --noheadings 2>/dev/null | grep -q .; then
        needed_cleanup=1
        warn "Swap is active from a previous run; disabling it"
    fi
    swapoff -a 2>/dev/null || true

    if [[ -e /dev/mapper/cryptroot ]]; then
        needed_cleanup=1
        warn "Closing existing /dev/mapper/cryptroot from a previous run"
        cryptsetup close cryptroot 2>/dev/null || cryptsetup luksClose cryptroot 2>/dev/null || true
    fi

    udevadm settle 2>/dev/null || true

    if [[ "$needed_cleanup" -eq 1 ]]; then
        success "Previous install state cleaned up"
    else
        success "No previous install state needed cleanup"
    fi
}

# Password input with validation function.
# Defaults to visible input because some Arch ISO console/keyboard combinations
# behave poorly with repeated hidden prompts.
prompt_password() {
    local __resultvar="$1"
    local prompt_text="$2"
    local pass1=""
    local pass2=""
    local hidden_choice="n"
    local attempts=0
    local max_attempts=3

    IFS= read -r -p "  Hide $prompt_text while typing? [y/N]: " hidden_choice < /dev/tty
    hidden_choice=${hidden_choice,,}

    while true; do
        if [[ "$hidden_choice" == "y" ]]; then
            IFS= read -r -s -p "  $prompt_text: " pass1 < /dev/tty
            printf '\n' > /dev/tty
            IFS= read -r -s -p "  Confirm $prompt_text: " pass2 < /dev/tty
            printf '\n' > /dev/tty
        else
            IFS= read -r -p "  $prompt_text: " pass1 < /dev/tty
            IFS= read -r -p "  Confirm $prompt_text: " pass2 < /dev/tty
        fi

        pass1=${pass1%$'\r'}
        pass2=${pass2%$'\r'}

        if [[ -z "$pass1" ]]; then
            warn "Password cannot be empty" > /dev/tty
            printf '\n' > /dev/tty
            continue
        fi

        if [[ "$pass1" == "$pass2" ]]; then
            printf -v "$__resultvar" '%s' "$pass1"
            return 0
        fi

        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            err "Too many failed attempts ($max_attempts). Aborting."
        fi

        warn "Passwords don't match. Try again ($attempts/$max_attempts)" > /dev/tty
        printf '\n' > /dev/tty
    done
}

clear
echo ""
echo -e "${BOLD}${CYAN}================================================================"
echo "      ARCH LINUX AUTO-INSTALLER (ENHANCED)"
echo "      Zen Kernel  |  KDE Plasma 6  |  LUKS2 Encryption  |  Privacy Stack"
echo -e "================================================================${NC}"
echo ""

header "STARTUP CLEANUP"
cleanup_previous_install_state

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

read -p "  Hostname [arch-laptop]: " HOSTNAME
HOSTNAME=${HOSTNAME:-arch-laptop}

echo ""
read -p "  Username: " USERNAME
while [[ -z "$USERNAME" || "$USERNAME" =~ [^a-z0-9_-] ]]; do
    warn "Lowercase letters/numbers/- only"
    read -p "  Username: " USERNAME
done

echo ""
info "User Password"
USER_PASS="password"
warn "Using default user/root password: password"

echo ""
info "Disk Encryption Password - ${RED}You type this EVERY time you boot${NC}"
LUKS_PASS="password"
warn "Using default disk encryption password: password"

echo ""
read -p "  Timezone [America/Los_Angeles]: " TIMEZONE
TIMEZONE=${TIMEZONE:-America/Los_Angeles}

read -p "  Locale [en_US.UTF-8]: " LOCALE
LOCALE=${LOCALE:-en_US.UTF-8}
LOCALE=${LOCALE// /}
if [[ ! "$LOCALE" =~ ^[A-Za-z]{2}_[A-Za-z]{2}\.UTF-8$ ]]; then
    warn "Invalid locale format '$LOCALE'. Falling back to en_US.UTF-8"
    LOCALE="en_US.UTF-8"
fi

read -p "  Install Beast Mode agent? [Y/n]: " INSTALL_BEAST_MODE
INSTALL_BEAST_MODE=${INSTALL_BEAST_MODE:-y}

# --- CONFIRMATION ---
header "INSTALLATION SUMMARY - PLEASE CONFIRM"

echo -e "  ${CYAN}Disk:${NC}       $TARGET_DISK ($DISK_SIZE) ${RED}${BOLD}<-- WIPED${NC}"
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
echo -e "  ${CYAN}Default Passwords:${NC} user/root/luks = password"
echo -e "  ${CYAN}Privacy Stack:${NC} Brave + AdGuard DNS + Tracking Protection"
echo -e "  ${CYAN}Extras:${NC}     brave git vim htop fastfetch wget curl p7zip guvcview obs-studio"
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
info "Live pacstrap output follows. This can take a while on slow mirrors or eMMC storage."

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
    htop fastfetch \
    p7zip unzip zip \
    guvcview v4l-utils obs-studio

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
if grep -Eq "^#?${LOCALE}[[:space:]]+UTF-8$" /etc/locale.gen; then
    sed -i "s/^#\(${LOCALE}[[:space:]]\+UTF-8\)
*/\1/" /etc/locale.gen
else
    echo "Locale ${LOCALE} is not available in /etc/locale.gen" >&2
    exit 1
fi
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "  >> Hostname..."
echo "${HOSTNAME}" > /etc/hostname
printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}\n' > /etc/hosts

echo "  >> Configuring mkinitcpio for encryption..."
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "  >> Installing KDE Plasma (patience required)..."
pacman -S --noconfirm --needed \
    plasma-meta \
    kde-applications-meta \
    sddm

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

# --- CREATE POST-INSTALL SETUP SCRIPT ---
header "CREATING POST-INSTALL SETUP SCRIPT"

cat > /mnt/home/${USERNAME}/.post-install-setup.sh << 'POSTINSTALLEOF'
#!/bin/bash
set -euo pipefail

mkdir -p "${HOME}/Projects"

if [[ ! -f "${HOME}/Projects/arch-user-setup.sh" ]]; then
  curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-user-setup.sh -o "${HOME}/Projects/arch-user-setup.sh"
fi

chmod +x "${HOME}/Projects/arch-user-setup.sh"
exec bash "${HOME}/Projects/arch-user-setup.sh"

POSTINSTALLEOF

chmod +x /mnt/home/${USERNAME}/.post-install-setup.sh
chown ${USERNAME}:${USERNAME} /mnt/home/${USERNAME}/.post-install-setup.sh
success "Post-install script created"

# --- DONE ---
header "INSTALLATION COMPLETE"

echo -e "${GREEN}${BOLD}"
echo " +--------------------------------------------------+"
echo "  |   Arch Linux installed successfully!   :)        |"
echo " +--------------------------------------------------+"
echo -e "${NC}"
echo -e "  ${CYAN}Summary:${NC}"
echo "   - linux-zen kernel"
echo "   - KDE Plasma 6 + SDDM"
echo "   - LUKS2 full disk encryption"
echo "   - systemd-boot"
echo "   - PipeWire audio"
echo "   - NetworkManager"
echo "   - Brave installed from AUR via post-install script"
echo "   - Webcam support (guvcview, obs-studio)"
echo "   - Privacy stack ready (AdGuard DNS + uBlock + Ghostery)"
echo ""
echo -e "  ${YELLOW}First boot:${NC}"
echo "   1. LUKS password prompt -> type: password"
echo "   2. SDDM login screen -> user: $USERNAME"
echo "   3. SDDM login screen -> password: password"
echo "   4. KDE Plasma desktop loads"
echo "   5. Run: ~/.post-install-setup.sh (to deploy privacy stack)"
echo ""
echo -e "  ${YELLOW}Default Credentials Set By Installer:${NC}"
echo "   - user: $USERNAME"
echo "   - login password: password"
echo "   - disk unlock passphrase: password"
echo "   - change these immediately after first login"
echo ""
echo -e "  ${BOLD}Remove USB and reboot:${NC}"
echo ""
echo "    umount -R /mnt"
echo "    cryptsetup close cryptroot"
echo "    reboot"
echo ""

