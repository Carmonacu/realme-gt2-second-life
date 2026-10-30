# Phase 0 — Preparation

**Goal:** PC ready, firmware documented, EU OTA saved, WSL build env planned.

## Checklist

- [ ] Confirm device is **RMX3311 (EU)** — Settings → About phone (not RMX3310/3312).
- [ ] Record full build string (e.g. `RMX3311_11.F.24_EUEX_...` or `RMX3311_11.H.xx_EUEX_...`).
- [ ] Download matching **Full OTA EUEX** to `downloads/` ([XDA OTA collection](https://xdaforums.com/t/collection-of-ota-packages.4542941/)).
- [ ] Install **Android platform-tools** on Windows; run `scripts/windows/check-platform-tools.ps1`.
- [ ] Install **Oppo/Realme USB drivers** and **Qualcomm QDLoader** drivers (EDL rescue).
- [ ] Charge phone **> 60%**.
- [ ] Enable WSL2; prepare Ubuntu 22.04+ (see `scripts/wsl/README.md` for setup agent).
- [ ] Ensure **~40–60 GB** free in WSL for kernel trees.
- [ ] Skim [docs/PLAN.md](../PLAN.md) warnings (EU firmware, unlock risk).

## Notes

- Full OTA is the lowest-level safety net before partition dumps exist.
- Do not start unlock until personal data strategy for Phase 1 is clear.
