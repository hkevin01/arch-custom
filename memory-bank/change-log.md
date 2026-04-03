# Change Log

## April 2026

| Date | Component | Change |
|------|-----------|--------|
| 2026-04-03 | arch-install.sh | Fix broken multiline locale.gen sed command |
| 2026-04-03 | arch-install.sh | Change default timezone to America/New_York |
| 2026-04-03 | arch-install.sh | Add fwupd, nmap, net-tools to pacstrap |
| 2026-04-03 | arch-user-setup.sh | Fix setup_beastmode() crash when utility-scripts repo 404s |
| 2026-04-03 | arch-user-setup.sh | Add copilot autopilot setup step after VS Code install |
| 2026-04-03 | README.md | Add Troubleshooting and Known Issues section (18 issues) |
| 2026-04-03 | README.md | Fix Mermaid rendering errors (emoji, em-dashes, ampersands) |
| 2026-04-03 | README.md | Expand OS configuration sections (systemd-boot, GRUB, GPU, zram, fwupd, AUR) |
| 2026-04-03 | README.md | Upgrade to showcase-grade with Mermaid diagrams and badges |

## March 2026

| Date | Component | Change |
|------|-----------|--------|
| 2026-03-17 | fix-grub-from-usb.sh | Add GRUB reinstall from USB rescue with trap cleanup |
| 2026-03-17 | fix-vfat-from-usb.sh | Support LUKS_PASSPHRASE env var |
| 2026-03-17 | fix-vfat-from-usb.sh | Read LUKS passphrase from /dev/tty for curl-piped execution |
| 2026-03-17 | fix-vfat-from-usb.sh | Auto-detect LUKS root partition; retry passphrase |
| 2026-03-17 | fix-vfat-from-usb.sh | Add USB script to repair vfat module and boot mount failures |
| 2026-03-17 | arch-usb-repair-all.sh | Propagate DEFAULT_PASS; skip failing post-validation reopen |
| 2026-03-17 | arch-usb-repair-all.sh | Handle non-default LUKS passphrase in post-validation |
| 2026-03-17 | arch-usb-repair-all.sh | Add all-in-one USB repair and validation script |
| 2026-03-17 | fix-boot-mount-debug.sh | Add debug-heavy emergency /boot mount repair script |
| 2026-03-17 | fix-boot-mount-emergency.sh | Add emergency /boot mount repair script |
| 2026-03-17 | arch-usb-rescue.sh | Stop auto-blacklisting rtw88; keep install helper zen-only |
| 2026-03-17 | arch-usb-rescue.sh | Harden boot seed permissions; reduce QAT firmware warnings |
| 2026-03-17 | arch-usb-rescue.sh | Add startup diagnostics and stronger pacman lock debugging |
| 2026-03-17 | arch-usb-rescue.sh | Enforce linux-zen-only across install and recovery scripts |
| 2026-03-17 | arch-usb-rescue.sh | Harden pacman sync; enforce linux-zen-only in USB rescue |
| 2026-03-17 | arch-usb-rescue.sh | Handle pacman db lock in USB rescue script |
| 2026-03-17 | arch-usb-rescue.sh | Add Arch USB rescue script for boot and Wi-Fi repair |
| 2026-03-17 | arch-install.sh | Remove consolefont hook to avoid no-font warning |
| 2026-03-17 | arch-install.sh | Run stale install cleanup at startup |
| 2026-03-17 | arch-install.sh | Fix locale validation and locale.gen handling |
| 2026-03-17 | arch-install.sh | Print explicit first-boot default credentials |
| 2026-03-17 | arch-install.sh | Remove Firefox; Brave-only browser path |
| 2026-03-17 | arch-install.sh | Show live pacstrap and package install output |
| 2026-03-17 | arch-install.sh | Use fixed default passwords (reliable on Arch ISO console) |
| 2026-03-17 | arch-install.sh | Make installer password entry reliable on Arch ISO |
| 2026-03-17 | arch-install.sh | Fix password prompt handling in installer |
| 2026-03-17 | arch-install.sh | Fix invalid Arch package names |
| 2026-03-17 | arch-install.sh | Add password validation, Brave browser, privacy stack, webcam support |
| 2026-03-17 | arch-config.sh | Add chroot recovery script; restore post-login setup flow |
| 2026-03-17 | kde-dark-theme-fix.sh | Add KDE dark theme fix script for GTK/Qt integration |
| 2026-03-17 | arch-user-setup.sh | Add user setup: Brave, VS Code, Beastmode, Konsole |
| 2026-03-17 | arch-user-setup.sh | Run Konsole customization before credential-prompting steps |
| 2026-03-17 | arch-user-setup.sh | Add automatic timezone and locale correction |
| 2026-03-17 | arch-user-setup.sh | Set default timezone to America/New_York |
| 2026-03-17 | enable-copilot-autopilot.sh | Auto-install jq if missing |
| 2026-03-17 | enable-copilot-autopilot.sh | Add VS Code Copilot autopilot settings script |
| 2026-03-17 | enable-beastmode.sh | Add curlable Beastmode agent/chatmode installer |
| 2026-03-17 | project-bootstrap.sh | Add project-bootstrap.sh and full repo scaffold |
