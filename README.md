# Arch Linux Auto-Installer

Automated Arch Linux installer with Zen kernel, KDE Plasma 6, and LUKS2 full disk encryption.

## Features

- **Kernel:** linux-zen (optimized for desktop performance)
- **Desktop:** KDE Plasma 6 with SDDM login manager
- **Encryption:** LUKS2 full disk encryption on root partition
- **Bootloader:** systemd-boot (UEFI)
- **Audio:** PipeWire
- **Network:** NetworkManager

## Curlable Scripts

| Script | Purpose |
|--------|---------|
| `arch-install.sh` | Full Arch install: LUKS2, linux-zen, KDE Plasma 6 |
| `arch-user-setup.sh` | First-login: VS Code, Brave, Beastmode, privacy tools |
| `enable-beastmode.sh` | VS Code Beastmode agent + chatmode installer |
| `enable-copilot-autopilot.sh` | Copilot agent settings (auto-installs jq) |
| `kde-dark-theme-fix.sh` | GTK/QT dark-theme fix for KDE |
| `project-bootstrap.sh` | Scaffold any project with memory-bank, CI, .vscode |

## Installation

Boot from Arch Linux ISO, connect to internet, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-install.sh | bash
```

## First Login Setup

After rebooting into the new system:

```bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-user-setup.sh | bash
```

## Scaffold Any Project

Run inside any project directory to add memory-bank, CI, .vscode, .github, .copilot, and docs:

```bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/project-bootstrap.sh | bash
```

Or target a specific directory:

```bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/project-bootstrap.sh | bash -s -- /path/to/project
```

## What the installer does

1. Partitions disk (512MB EFI + rest for LUKS root)
2. Sets up LUKS2 encryption
3. Installs base system with linux-zen
4. Installs and configures KDE Plasma 6
5. Configures systemd-boot with encryption support
6. Creates user with sudo access
7. Enables NetworkManager and SDDM

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
3. Run `arch-user-setup.sh` to finish developer environment setup

## License

MIT