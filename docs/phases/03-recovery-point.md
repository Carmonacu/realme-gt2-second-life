# Phase 3 — Magisk root + recovery point

**Goal:** Root on **stock EU**, then save critical partitions and stock boot images to `backup_porsche/` on PC.

## Checklist

- [ ] Extract `boot.img` / `init_boot.img` from your **Full OTA EU** (payload dumper).
- [ ] Patch boot with **Magisk** app → `magisk_patched-*.img`.
- [ ] `fastboot flash boot magisk_patched.img` (and `init_boot` if applicable for your Android version).
- [ ] Boot and confirm Magisk root (`adb shell su -c id`).
- [ ] Run partition backup script (edit paths): `scripts/backup/backup-critical-partitions.sh`
- [ ] Pull dumps to PC: `scripts/backup/pull-backups-to-pc.sh`
- [ ] Copy stock **`boot.img`**, **`vendor_boot.img`**, **`dtbo.img`** from OTA into `backup_porsche/stock_boot/`.
- [ ] Verify file sizes non-zero; store checksums (optional).
- [ ] Label backup folder with firmware build string and date.

## Partitions to backup (by-name)

`persist`, `modemst1`, `modemst2`, `fsg`, `fsc`, `oplusreserve`

## Notes

- Always use `/dev/block/by-name/<part>`, never raw `mmcblk` indices.
- This folder + Full OTA EU = **recovery point** for Phase 7.
- Images stay **gitignored** — never commit `.img` files.
