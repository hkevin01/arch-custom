# ADR-001: systemd-boot over GRUB

**Status:** Accepted | **Date:** 2026-03-17

## Decision
Use systemd-boot — UEFI-only, no external packages, simpler entry management.

## Trade-offs
- No BIOS/legacy boot support.
- Boot entries live in /boot/loader/entries/.
- Easy to extend with additional kernels.
