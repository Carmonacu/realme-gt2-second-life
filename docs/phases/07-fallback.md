# Phase 7 — Fallback (no internal injection or full restore)

**Goal:** Stay productive with external Wi-Fi **or** return to stock EU using Phase 3 backups.

## Option A — USB Wi-Fi (recommended if injection fails)

- [ ] Obtain supported OTG adapter (e.g. Alfa AWUS036ACH / AWUS036NHA, RTL8812AU class).
- [ ] Test monitor mode + injection on **usb interface** in NetHunter chroot.
- [ ] Keep HID/OTG/chroot/Docker as-is.

## Option B — Restore stock EU

- [ ] Flash **stock** `boot`, `vendor_boot`, `dtbo` from `backup_porsche/stock_boot/`.
- [ ] Restore partitions from backups: `persist`, `modemst1`, `modemst2`, `fsg`, `fsc`, `oplusreserve` (see `scripts/backup/restore-critical-partitions.sh` template).
- [ ] Or reinstall **Full OTA EU** matching original build.
- [ ] Verify IMEI/SIM and Wi-Fi on stock.
- [ ] **Brick / EDL:** MSM Download Tool or Oplus tool with **EU OFP** (auth may be required).
- [ ] Optional: `fastboot flashing lock` **only** after confirmed stable stock ROM.

## Notes

- Relocking with wrong images risks permanent brick.
- Keep `backup_porsche/` and OTA on PC until project is abandoned.
