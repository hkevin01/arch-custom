# Project Plan: arch-custom

## Phase 1: Arch Linux Base Installation
- [x] Validate UEFI environment and auto-detect target disk (/dev/mmcblk0)
- [x] Stale-state cleanup — unmount /mnt, close cryptroot, disable swap
- [x] Full-disk LUKS2 encryption with systemd-boot EFI bootloader
- [x] Bootstrap base system: linux-zen, base, base-devel, essential packages
- [x] Configure locale (en_US.UTF-8), hostname, and America/New_York timezone

## Phase 2: Desktop Environment
- [x] Install KDE Plasma 6, SDDM, PipeWire, NetworkManager
- [x] Apply GTK/QT dark-theme fix via kde-dark-theme-fix.sh
- [x] Configure Konsole transparency and custom color profile
- [x] Set up user account with sudo and first-login setup launcher
- [x] Enable SDDM and NetworkManager systemd services

## Phase 3: Developer Environment
- [x] Install official VS Code (visual-studio-code-bin via AUR; remove code-oss)
- [x] Apply Copilot autopilot settings (enable-copilot-autopilot.sh)
- [x] Install Beastmode agent and chatmode (enable-beastmode.sh)
- [x] Install base-devel, git, curl, and yay for AUR builds
- [x] Install Brave browser via pacman; AUR fallback if not in repos

## Phase 4: Privacy and Security Hardening
- [x] Run deploy_tracking_protection.sh from utility-scripts (skipped gracefully if repo unavailable)
- [x] Run harden_kde_lockscreen_privacy.sh (skipped gracefully if unavailable)
- [x] Verify no hardcoded credentials in any script (OWASP A02)
- [x] Confirm .gitignore covers .env and secrets patterns
- [x] ShellCheck all scripts clean — zero warnings in CI

## Phase 5: USB Rescue and Repair Toolkit
- [x] arch-usb-rescue.sh — full boot + Wi-Fi + RTL8821CE repair from USB
- [x] arch-usb-repair-all.sh — one-liner to run rescue + validate
- [x] fix-boot-mount-emergency.sh — emergency shell /boot repair
- [x] fix-boot-mount-debug.sh — debug-heavy /boot repair with log capture
- [x] fix-vfat-from-usb.sh — vfat module + fstab UUID repair from USB
- [x] fix-grub-from-usb.sh — GRUB reinstall from USB
- [x] arch-config.sh — chroot recovery for broken post-install configurations

## Phase 6: Known Issues Addressed (Real Installs on This Machine)
- [x] Stale ISO keyring — pre-flight pacman -Sy archlinux-keyring
- [x] Clock drift / TLS failures — timedatectl set-ntp true before pacstrap
- [x] /mnt busy / cryptroot already open on re-run — cleanup_previous_install_state()
- [x] Partition table not refreshed after sgdisk — partprobe + sleep 2
- [x] USB ISO picked as target disk — /sys/block/removable check
- [x] Arch ISO console broken hidden prompts — visible-by-default; \r stripped
- [x] curl|bash stdin hijacked — LUKS passphrase reads from /dev/tty
- [x] Intel QAT firmware warnings — sed removes qat_* from mkinitcpio MODULES
- [x] Leftover linux/linux-lts kernels — forcibly removed after zen confirmed
- [x] /boot emergency mount failure — fix-boot-mount-*.sh scripts
- [x] modules_disabled=1 blocking vfat — fix-vfat-from-usb.sh disables sysctl
- [x] Stale pacman.db.lck — wait+force remove before chroot pacman
- [x] DNS not in arch-chroot — cp /etc/resolv.conf /mnt/etc/resolv.conf
- [x] efivarfs not mounted in chroot — explicit mount before bootctl
- [x] RTL8821CE Wi-Fi requires AUR DKMS driver (rtl8821ce-dkms-git)
- [x] KDE dark theme GTK vs Qt mismatch — kde-dark-theme-fix.sh
- [x] consolefont mkinitcpio hook warning — removed from HOOKS
- [x] Broken locale.gen sed command — fixed single-line pattern
- [x] setup_beastmode() crash when utility-scripts repo unavailable — guarded with fallback

## Phase 7: Automation and Maintenance
- [x] ShellCheck CI passing on every push via GitHub Actions
- [x] 500-line cap lint check enforced in CI (lint.yml)
- [ ] Tag stable releases and add entries to memory-bank/change-log.md
- [ ] Validate all curl one-liners in a clean Arch ISO VM
- [ ] Expand memory-bank with each new feature or architecture decision
