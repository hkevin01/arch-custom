# Project Plan: arch-custom

## Phase 1: Arch Linux Base Installation
- [ ] Validate UEFI environment and auto-detect target disk (/dev/mmcblk0)
- [ ] Stale-state cleanup — unmount /mnt, close cryptroot, disable swap
- [ ] Full-disk LUKS2 encryption with systemd-boot EFI bootloader
- [ ] Bootstrap base system: linux-zen, base, base-devel, essential packages
- [ ] Configure locale (en_US.UTF-8), hostname, and America/New_York timezone

## Phase 2: Desktop Environment
- [ ] Install KDE Plasma 6, SDDM, PipeWire, NetworkManager
- [ ] Apply GTK/QT dark-theme fix via kde-dark-theme-fix.sh
- [ ] Configure Konsole transparency and custom color profile
- [ ] Set up user account with sudo and first-login setup launcher
- [ ] Enable SDDM and NetworkManager systemd services

## Phase 3: Developer Environment
- [ ] Install official VS Code (visual-studio-code-bin via AUR; remove code-oss)
- [ ] Apply Copilot autopilot settings (enable-copilot-autopilot.sh)
- [ ] Install Beastmode agent and chatmode (enable-beastmode.sh)
- [ ] Install base-devel, git, curl, and yay for AUR builds
- [ ] Install Brave browser via pacman; AUR fallback if not in repos

## Phase 4: Privacy and Security Hardening
- [ ] Run deploy_tracking_protection.sh from utility-scripts
- [ ] Run harden_kde_lockscreen_privacy.sh
- [ ] Verify no hardcoded credentials in any script (OWASP A02)
- [ ] Confirm .gitignore covers .env and secrets patterns
- [ ] ShellCheck all scripts clean — zero warnings in CI

## Phase 5: Automation and Maintenance
- [ ] ShellCheck CI passing on every push via GitHub Actions
- [ ] 500-line cap lint check enforced in CI (lint.yml)
- [ ] Tag stable releases and add entries to memory-bank/change-log.md
- [ ] Validate all curl one-liners in a clean Arch ISO VM
- [ ] Expand memory-bank with each new feature or architecture decision
