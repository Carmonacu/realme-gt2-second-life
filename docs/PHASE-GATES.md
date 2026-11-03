# Phase gates (“ready when”)

Use with [STATUS.md](STATUS.md). Do not start the next phase until the gate passes.

| Gate | Ready when | Repo check |
|------|------------|------------|
| **0 → 1** | Full OTA matching recorded build in `downloads/` (EX01 or EUEX); platform-tools OK; WSL toolchain installed; drivers installed; phone confirmed RMX3311 + build recorded; battery > 60%; PLAN warnings read | `verify-downloads.ps1`, `verify-wsl.sh --require-toolchain`, `check-adb-device.ps1` |
| **1 → 2** | Personal backup done; factory reset completed; build still matches OTA | Manual |
| **2 → 3** | Bootloader unlocked (`fastboot getvar unlocked`); **stop** if unlock failed | `list-fastboot-devices.ps1` |
| **3 → 4** | Magisk root on stock EU; partition dumps + stock boot images in `backup_porsche/` on PC | `pull-backups-to-pc.sh`, non-empty `backup_porsche/partitions/` |
| **4 → 5** | Custom ROM booting; SIM/IMEI/Wi-Fi OK; Magisk on ROM; ROM choice recorded for kernel branch | Notes in phase doc |
| **5 → 6** | AnyKernel zip built and smoke-tested (boot + HID before injection) | `clone-kernel-tree.sh`, WSL build |
| **6 → 7/8** | NetHunter installed; injection tested or fallback plan chosen | Phase 6 checklist |
| **7** | Restore only with `CONFIRM=1` on restore script | `restore-critical-partitions.sh` |

**Overall progress (automatable in repo):** Phase 0 ~**85%** (adb/battery/WSL apt done 2026-10-31; missing verified OTA file, fastboot device visible, `verify-wsl.sh --require-toolchain` green, PLAN skim). Phases 1–6 require the device. Phase 5 scripts are ready after Phase 4 + WSL deps.

**Gate 0 → 1 (2026-10-31):** **Not ready** — Full OTA not in `downloads/` (CDN 404); fastboot empty; PLAN not skimmed.
