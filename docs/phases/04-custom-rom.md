# Phase 4 — Custom ROM (NetHunter base)

**Goal:** Install PixelOS 16 or LineageOS 23 for porsche (kernel 5.4), verify radio/Wi-Fi, re-root.

## Checklist

- [ ] Download ROM zip to `downloads/` ([PixelOS porsche](https://www.pixelos.net/download/porsche) or [pjgowtham device tree](https://github.com/pjgowtham/android_device_realme_porsche)).
- [ ] Boot to fastboot; flash `vendor_boot`, `dtbo`, `boot` per ROM instructions.
- [ ] `fastboot reboot recovery` → **adb sideload** ROM zip → format data if required.
- [ ] First boot: verify **SIM, IMEI, Wi-Fi, VoLTE** as needed.
- [ ] If IMEI broken: flash **`modem.img` from EU Full OTA** via fastboot (documented PixelOS/XDA fix).
- [ ] Install Magisk on custom ROM boot image; confirm root.
- [ ] Snapshot current ROM + kernel version in this repo (notes or issue).

## Repo helpers

```powershell
# ROM zip under downloads/ before sideload
.\scripts\windows\verify-downloads.ps1
.\scripts\windows\list-fastboot-devices.ps1
```

```powershell
# Recovery sideload (device in sideload mode)
adb sideload downloads\<your-rom>.zip
```

After ROM stable, note **lineage** vs **pixelos** for Phase 5 clone script.

Gate to Phase 5: [PHASE-GATES.md](../PHASE-GATES.md) **4 → 5**.

## Notes

- PixelOS builds may ship modem firmware from other regions — EU `modem.img` is the standard fix.
- No stable OrangeFox/TWRP for A14/A15 on this device; sideload/fastboot workflow only.
