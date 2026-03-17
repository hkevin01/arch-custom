# Arch Linux Auto-Installer

Automated Arch Linux installer with Zen kernel, KDE Plasma 6, and LUKS2 full disk encryption.

## Features

- **Kernel:** linux-zen (optimized for desktop performance)
- **Desktop:** KDE Plasma 6 with SDDM login manager
- **Encryption:** LUKS2 full disk encryption on root partition
- **Bootloader:** systemd-boot (UEFI)
- **Audio:** PipeWire
- **Network:** NetworkManager
- **Extras:** Firefox, git, vim, htop, neofetch, fastfetch, p7zip

## Installation

Boot from Arch Linux ISO, connect to internet, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-install.sh | bash
```

Follow the prompts to set:
- Hostname
- Username and password
- Disk encryption password
- Timezone and locale

Type **INSTALL** when prompted to begin the automated installation.

## What it does

1.  Partitions disk (512MB EFI + rest for LUKS root)
2.  Sets up LUKS2 encryption
3.  Installs base system with linux-zen
4.  Installs and configures KDE Plasma 6
5.  Configures systemd-boot with encryption support
6.  Creates user with sudo access
7.  Enables NetworkManager and SDDM

## Requirements

- UEFI system (not BIOS)
- Internet connection
- At least 16GB disk space (32GB+ recommended)

## After Installation

Remove the USB drive and reboot:

```bash
umount -R /mnt
cryptsetup close cryptroot
reboot
```

On first boot:
1. Enter your LUKS encryption password
2. Log in at SDDM with your username
3. Enjoy KDE Plasma!