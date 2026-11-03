# Phase 0 — Preparation

**Goal:** PC ready, firmware documented, EU OTA saved, WSL build env planned.

See [STATUS.md](../STATUS.md) for what is already done vs blocked.

## Checklist

- [x] Confirm device is **RMX3311 (EU)** — adb: **RMX3311** (see [device-record.md](../device-record.md)).
- [x] Record full build string — **`RMX3311_15.0.0.1650(EX01)`** (suffix **EX01**, not legacy `EUEX`).
- [ ] Download matching **Full OTA** (same build / **EX01** suffix) to `downloads/` — verified EU package **`RMX3311_11.H.29_EUEX_202603191634`** / MD5 in [downloads/README.md](../../downloads/README.md); **CDN links 404 as of 2026-10-31** — use OTA-Pulse; verify with `.\scripts\windows\verify-downloads.ps1` + `verify-ota-md5.ps1`.
- [x] Install **Android platform-tools** on Windows (adb/fastboot **37.0.1** on PATH).
- [ ] Install **Oppo/Realme USB drivers** and **Qualcomm QDLoader** drivers (EDL rescue) — [drivers-windows.md](../drivers-windows.md). (`Realme-Driver-Setup-v2.0.zip` in `downloads/`; **fastboot still not listed** by `list-fastboot-devices.ps1` on 2026-10-31.)
- [x] Charge phone **> 60%** — last adb check: **100%** (`check-adb-device.ps1`; phone may now be in fastboot only).
- [x] Enable WSL2; Ubuntu **24.04.3 LTS** on WSL **2** (`scripts/wsl/verify-wsl.sh`).
- [x] Ensure **~40–60 GB** free in WSL for kernel trees (~951 GB free verified).
- [x] Run `scripts/wsl/setup-build-env.sh` packages — installed via **`wsl -d Ubuntu -u root`** + `apt-get` (2026-10-31; all deps present).
- [ ] After setup: `scripts/wsl/verify-wsl.sh --require-toolchain` — **script exits on `lld --version`**; gcc/clang/make/repo/ld.lld confirmed manually as root.
- [ ] Skim [docs/PLAN.md](../PLAN.md) warnings (EU firmware, unlock risk).

## Repo commands (Phase 0)

```powershell
# Windows — repo root
.\scripts\windows\check-platform-tools.ps1
.\scripts\windows\verify-downloads.ps1
.\scripts\windows\verify-ota-md5.ps1
.\scripts\windows\check-adb-device.ps1
.\scripts\windows\list-fastboot-devices.ps1
```

```bash
# WSL — toolchain installed (root apt, 2026-10-31)
bash /mnt/c/Users/<you>/Desktop/Proyects/realme-gt2-second-life/scripts/wsl/verify-wsl.sh --require-toolchain
```

Gate to Phase 1: [PHASE-GATES.md](../PHASE-GATES.md).

## Notes

- Full OTA is the lowest-level safety net before partition dumps exist.
- Do not start unlock until personal data strategy for Phase 1 is clear.
