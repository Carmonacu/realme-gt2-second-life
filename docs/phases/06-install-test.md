# Phase 6 — Install NetHunter and test

**Goal:** NetHunter rootfs + custom kernel; validate features in order (HID → Wi-Fi inject → Docker).

## Checklist

- [ ] Install **NetHunter** per [official guide](https://www.kali.org/docs/nethunter/installing-nethunter/) (Magisk module method).
- [ ] Flash **AnyKernel zip** via NetHunter app or Magisk (2026.2+ standalone kernel flash).
- [ ] Reboot; open NetHunter app; confirm chroot deploys.
- [ ] **HID / BadUSB / OTG:** test keyboard emulation and USB OTG attach.
- [ ] **Chroot:** run basic Kali tools inside chroot.
- [ ] **Wi-Fi internal:** `airmon-ng`, monitor mode on `wlan0`, `aireplay-ng --test` — record pass/fail for WCN6856.
- [ ] **Docker:** install in chroot (or Termux+root); `docker run --rm hello-world`.
- [ ] **Docker network:** `docker run --rm alpine ping -c1 1.1.1.1`.
- [ ] Document results in personal notes; if injection fails → Phase 7.

## Notes

- Test HID/OTG before spending time debugging Wi-Fi injection.
- Keep stock boot images on PC before first kernel flash.
