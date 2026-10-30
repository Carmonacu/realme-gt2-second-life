# Phase 0 — Preparation

**Goal:** PC ready, firmware documented, EU OTA saved, WSL build env planned.

## Checklist

- [ ] Confirm device is **RMX3311 (EU)** — Settings → About phone (not RMX3310/3312).
- [ ] Record full build string (e.g. `RMX3311_11.F.24_EUEX_...` or `RMX3311_11.H.xx_EUEX_...`).
- [ ] Download matching **Full OTA EUEX** to `downloads/` ([XDA OTA collection](https://xdaforums.com/t/collection-of-ota-packages.4542941/)).
- [x] Install **Android platform-tools** on Windows (adb/fastboot **37.0.1** on PATH).
- [ ] Install **Oppo/Realme USB drivers** and **Qualcomm QDLoader** drivers (EDL rescue).
- [ ] Charge phone **> 60%**.
- [x] Enable WSL2; Ubuntu **24.04.3 LTS** on WSL **2** (`scripts/wsl/verify-wsl.sh`).
- [x] Ensure **~40–60 GB** free in WSL for kernel trees (~952 GB free verified).
- [ ] Run `scripts/wsl/setup-build-env.sh` in an **interactive** Ubuntu WSL shell (needs `sudo`; non-interactive runs may hang on password).
- [ ] Skim [docs/PLAN.md](../PLAN.md) warnings (EU firmware, unlock risk).

## Notes

- Full OTA is the lowest-level safety net before partition dumps exist.
- Do not start unlock until personal data strategy for Phase 1 is clear.
