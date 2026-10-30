# Phase 2 — Bootloader unlock (Deep Testing)

**Goal:** Obtain working unlocked bootloader via Realme Deep Testing. **Stop here if unlock fails.**

## Checklist

- [ ] Developer options → enable **OEM unlocking** and **USB debugging**.
- [ ] Install current **Deep Testing APK** (old APKs can cause long penalties — use community guide for RMX3312/porsche thread).
- [ ] Submit in-depth test request; **wait for approval** (days possible).
- [ ] If "device not supported", research EU-specific workarounds; **do not change region to IN/CN**.
- [ ] After approval: `adb reboot bootloader`
- [ ] Run `fastboot flashing unlock` (confirm with Vol+). **Full data wipe.**
- [ ] Verify: `fastboot getvar unlocked` (or device UI shows unlocked state).
- [ ] **Decision:** if fastboot unlock fails or fastboot mode unavailable → **stop project**.

## References

- [XDA unlock test RMX3311](https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/)
- [PixelOS full guide (Deep Testing APK notes)](https://xdaforums.com/t/realme-gt-2-rmx3312-pixelos-android-14-full-guide.4663480/)

## Notes

- EU RMX3311 unlock success is **not guaranteed** in 2026 reports.
- Windows: use repo fastboot helpers; fix drivers if device not detected.
