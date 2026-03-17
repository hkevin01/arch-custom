# Install Flow Plan

## Phase 1 – Disk & Encryption
- [ ] UEFI check and stale-state cleanup (unmount, swapoff, cryptsetup close)
- [ ] Partition disk: 512MB EFI + LUKS2 root
- [ ] Format EFI (FAT32) and root (ext4)
- [ ] Mount partitions to /mnt

## Phase 2 – Base System
- [ ] pacstrap linux-zen, base, base-devel, essential packages
- [ ] Generate fstab, configure locale, hostname, timezone

## Phase 3 – Boot & Desktop
- [ ] systemd-boot entries with encrypt + resume hooks
- [ ] KDE Plasma 6, SDDM, PipeWire, NetworkManager

## Phase 4 – Post-Login
- [ ] arch-user-setup.sh: Brave, VS Code, Beastmode, privacy scripts
