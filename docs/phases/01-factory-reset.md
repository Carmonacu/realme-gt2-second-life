# Phase 1 — Factory reset (clean start)

**Goal:** Wipe the phone to a known-clean state before Deep Testing / unlock.

## Checklist

- [ ] Back up personal data (photos, accounts, 2FA backup codes) to cloud or PC.
- [ ] Export anything needed from internal storage via USB or cloud sync.
- [ ] Settings → System settings → Backup & reset → **Erase all data** (factory reset).
- [ ] Complete setup wizard minimally (Wi-Fi, skip heavy restore if possible).
- [ ] Re-verify **About phone** build still matches the OTA you downloaded in Phase 0.

## Repo helpers

No automated wipe — personal backup only. Before Phase 2, confirm [PHASE-GATES.md](../PHASE-GATES.md) **0 → 1**.

```powershell
.\scripts\windows\verify-downloads.ps1
.\scripts\windows\check-adb-device.ps1
```

## Notes

- Unlock in Phase 2 will wipe again — this reset is for a clean baseline you requested before recovery work.
- Do not flash CN/IN OTAs during or after this phase.
