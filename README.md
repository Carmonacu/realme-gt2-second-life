# NetHunter on Realme GT 2 (porsche / RMX3311)

Project to port **Kali NetHunter** to the **Realme GT 2** European variant (**RMX3311**, codename **porsche**), using a custom ROM with the shared **SM8350** kernel tree and a self-built NetHunter kernel (HID/OTG, optional **qcacld-3.0** Wi-Fi injection, Docker, local AI later).

## Hardware summary

| Item | Detail |
|------|--------|
| Model | Realme GT 2 **RMX3311** (EU — not RMX3310 CN / RMX3312 IN) |
| Codename | **porsche** |
| SoC | Qualcomm **Snapdragon 888 (SM8350, lahaina)** |
| Kernel (Android) | **Linux 5.4** |
| Wi-Fi / BT | Qualcomm **WCN6856** (qcacld-3.0) |

There is **no official NetHunter device entry** for porsche yet; this repo tracks the porting workflow and backups.

## Plan and phases

- **Condensed roadmap:** [docs/PLAN.md](docs/PLAN.md)
- **Action checklists (Fase 0–8):**
  - [00 – Prep](docs/phases/00-prep.md)
  - [01 – Factory reset](docs/phases/01-factory-reset.md)
  - [02 – Bootloader unlock](docs/phases/02-bootloader-unlock.md)
  - [03 – Root & recovery point](docs/phases/03-recovery-point.md)
  - [04 – Custom ROM](docs/phases/04-custom-rom.md)
  - [05 – Build NetHunter kernel](docs/phases/05-build-kernel.md) — [detailed WSL flow](docs/phases/05-build-kernel-detailed.md), [Docker `CONFIG_*`](docs/docker-kernel-options.md)
  - [06 – Install & test](docs/phases/06-install-test.md)
  - [07 – Fallback](docs/phases/07-fallback.md)
  - [08 – Local AI](docs/phases/08-ai-local.md)

## Repository layout

- `docs/` — plan and phase guides
- `scripts/windows/` — ADB/fastboot helpers (PowerShell)
- `scripts/backup/` — partition backup templates (Phase 3)
- `scripts/wsl/` — WSL build environment (see README there)
- `backup_porsche/` — **local only** critical partition dumps (gitignored except `.gitkeep`)
- `downloads/` — Full OTA EU, OFP, extracted images (gitignored except `.gitkeep`)

## Warnings (read first)

1. **EU firmware only (EUEX).** Do not flash CN or IN packages on RMX3311 — IMEI/baseband risk.
2. **Bootloader unlock is not guaranteed** on EU RMX3311 in 2026 (Deep Testing delays/failures). Validate unlock before investing in kernel work.
3. **Unlock and many flash steps wipe data.** The real “recovery point” is Phase 3 (root + partition dumps + stock boot images + Full OTA EU on disk).
4. **Brick risk** — treat as a learning project on a spare device. Keep EDL/OFP EU recovery options in mind.
5. **Internal Wi-Fi injection** for WCN6856 is experimental; HID/OTG/chroot plus a **USB Wi-Fi adapter** remains the reliable fallback.

## Quick start (Phase 0)

```powershell
# From repo root on Windows
.\scripts\windows\check-platform-tools.ps1
.\scripts\windows\list-fastboot-devices.ps1
```

Prepare WSL2 for kernel builds — [scripts/wsl/README.md](scripts/wsl/README.md) and [docs/wsl-build-environment.md](docs/wsl-build-environment.md) (run `setup-build-env.sh` in an interactive Ubuntu shell; needs `sudo`).

## References

- [Kali NetHunter docs](https://www.kali.org/docs/nethunter/)
- [kali-nethunter-kernel-builder](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder)
- Reference kernel (same SoC, injection): [Sakura_Kernel_OP9Pro](https://github.com/Madara273/Sakura_Kernel_OP9Pro)
