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

## Repo helpers (Windows)

```powershell
.\scripts\windows\check-adb-device.ps1
adb reboot bootloader
.\scripts\windows\list-fastboot-devices.ps1
fastboot flashing unlock
fastboot getvar unlocked
```

Gate to Phase 3: unlock verified — [PHASE-GATES.md](../PHASE-GATES.md).

## References

- [XDA unlock test RMX3311](https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/)
- [PixelOS full guide (Deep Testing APK notes)](https://xdaforums.com/t/realme-gt-2-rmx3312-pixelos-android-14-full-guide.4663480/)

## Notes

- EU RMX3311 unlock success is **not guaranteed** in 2026 reports.
- Windows: use repo fastboot helpers; fix drivers if device not detected.

### 2026 status / known blockers

**Updated:** 2026-10-31 — see **[unlock-research.md](../unlock-research.md)** (sourced web review).

| Blocker | Impact |
|---------|--------|
| Deep Testing **“model not supported”** on stock **A15 1650 (EX01)** | Matches EU RMX3311 pattern; no verified on-device unlock path on current firmware |
| Stano36 **Oct 2024** RMX3311 test: approval but **no fastboot** after Deep Test | Last structured EU test **failed** at unlock step |
| `deeptesting-junk.pl` / EU script guides | Marked **NOT WORK ANYMORE** on XDA |
| Rollback → unlock → restore | Documented on XDA (Stano36) but **high IMEI/brick risk**; **CN/IN packages** in some flows — **conflicts with project rule**; **1650 Full OTA restore zip missing** in repo |
| LineageOS **porsche** | **Not** on official wiki; PixelOS assumes unlock + **RMX3311 modem** care |

**Gate:** If Deep Testing cannot accept an application on stock EU firmware, treat Phase 2 as **blocked** unless you explicitly accept rollback risk **and** have a verified **1650 EU** restore image first.
