# Project status (execution)

Last verified: **2026-10-31** (Termux LLM + SSH on **YOUR_ADB_SERIAL**; **Termux:Boot + reboot test OK** — `sshd` sin abrir Termux; Tailscale no auto-arrancó tras reboot — ver abajo).

## Plan B on device (audit 2026-10-31)

SSH read-only audit via ADB + forward **8022**. Repo docs vs **this phone**:

| Item | Repo | Device |
|------|------|--------|
| LLM + SSH + Tailscale + tuning § A | Documented / verified earlier | **OK** — `sshd` **al reboot** (Termux:Boot); **Tailscale app** hay que **conectarla tras reboot** (el check `phone-check` mira `tun*` en Termux; la VPN oficial es la **app Android**) |
| **Termux:Boot + runit** | [termux-boot-services.md](termux-boot-services.md), scripts in repo | **OK (2026-10-31)** — `com.termux.boot` instalado; post-reboot **sshd** activo (~12 min uptime) vía SSH/adb **sin** abrir Termux; `~/.termux/boot/start-services` presente |
| **Always-on / § E rol principal** | [always-on-battery.md](always-on-battery.md), [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa) | **`~/bin/mode` v1** — boot `idle`; log `~/storage/shared/mode-transitions.log` |
| Jellyfin / Node-RED / Mosquitto / udocker | [service-modes-design.md](service-modes-design.md) · [jellyfin-media.md](jellyfin-media.md) | **Instalados**; runit **`services/jellyfin/run`** (`DOTNET_ROOT=$PREFIX/lib/dotnet`); **HTTP 302/200** en :8096; **`mode media`** activo; **media de prueba** en `~/storage/shared/Movies`: `BigBuckBunny_320x180.mp4` (~62 MiB), `sintel_trailer-1080p.mp4` (~14 MiB); **asistente Jellyfin pendiente** |
| **Control `mode`** | [termux-llm-guide.md](termux-llm-guide.md) | Operativo en teléfono |
| **LLM router + KV q8_0 + especulativa + métricas** (b12017) | [termux-llm-guide.md § Router](termux-llm-guide.md#router-kv-q8_0-especulativa-y-métricas-b12017) · bench `scripts/bench/run-llm-variants.sh` | **Solo repo** — flags verificados en código b12017 y probados con binario b12017 x86_64; **pendiente** en teléfono + benchmark SD888 |
| **charge-limiter + thermal-guard** (opt-in) | [always-on-battery.md § 9](always-on-battery.md#9-limitador-de-carga-y-guardián-térmico-opt-in) | **Solo repo** — falta Termux:API en el teléfono, importar flujo Node-RED y elegir enchufe |

**Next on device (order):** **Tailscale (app Android):** tras reboot abrir la app o activar VPN always-on (no usar solo `tailscaled` de Termux). **Jellyfin:** completar asistente en `http://<tailscale-ip>:8096/web/` y añadir biblioteca `…/storage/shared/Movies` ([jellyfin-media.md](jellyfin-media.md)). Reinstalar runit Jellyfin: `bash install-optional-services.sh` o copiar `services/jellyfin/run`.

## BLOCKED: bootloader unlock (Phase 2) — 2026-10-31

- Bootloader reached via `adb reboot fastboot` → `fastboot reboot bootloader`; `fastboot getvar`: `unlocked: no`, `secure: yes`, `product: lahaina`. OEM unlocking toggle is **ON**.
- Deep Testing **v1.0.1**: blank disclaimer, then *"Failed to submit application. This phone model does not support deep testing."* No prior requests; HeyTap region believed EU.
- Research ([unlock-research.md](unlock-research.md)): **0 verified unlocks** of RMX3311 EU on Android 14/15 stock. Rollback + CN/IN region path conflicts with the project rule (no CN/IN) and risks IMEI/brick; exact 1650 Full OTA is not downloadable (CDN 404).
- **Decision:** pause Phase 2+ on this phone (PLAN stop condition). Phone stays on stock. Resume only with new primary evidence, or switch device. Do not attempt rollback without explicit written acceptance of the risk.
- Open PC items: Windows driver for bootloader-mode fastboot (`SM8350-MTP`, `VID_22D9&PID_2769` → Android Bootloader Interface).

## Plan B (rootless, stock phone)

Bootloader work is **paused**, but you can still pursue **(a) local LLM** and **(b) rootless Kali** on the current RMX3311 without unlock or root.

| Track | Doc | Status |
|-------|-----|--------|
| Local AI (llama.cpp / GGUF, Termux) | [phases/08-ai-local.md](phases/08-ai-local.md) · **[termux-llm-guide.md](termux-llm-guide.md)** · **[phone-tuning.md](phone-tuning.md)** · **[termux-boot-services.md](termux-boot-services.md)** | **Operativo:** `llm smol`, **SSH** (:8022) **al reboot** (Termux:Boot OK), Tailscale **manual post-reboot**, API remota, **20 apps** desactivadas (2026-10-31) |
| Servicios opcionales + `mode` | [termux-llm-guide.md](termux-llm-guide.md) § Modos · [service-modes-design.md](service-modes-design.md) | **v1 en repo y teléfono** — Jellyfin/Mosquitto/udocker/Node-RED instalados; ver `mode status` |
| **Portal :8081** | [portal-homepage.md](portal-homepage.md) | Script `install-portal.sh` en repo; desplegar con push + install en Termux |
| Kali NetHunter Rootless + ColorOS stability | [rootless-kali.md](rootless-kali.md) | **Operativo (verificado 2026-10-31):** minimal arm64, rootfs **~5,9 GiB**, `kali`/`kali-update`, Metasploit **6.5.7** (`msfconsole -n`); usar **`mode pentest`** (sin `--force` silencioso) |
| Full NetHunter (kernel / injection) on another phone | [alternative-devices.md](alternative-devices.md) | Planning / hardware swap |

**Limits on Plan B:** no **802.11 monitor mode**, no **USB HID**, no **Docker-in-proot**; Metasploit **without DB** in rootless ([Kali rootless doc](https://www.kali.org/docs/nethunter/nethunter-rootless/)). Pair AI + pentest docs above before re-opening Phase 2.

## Where you are

| Phase | Status | Notes |
|-------|--------|--------|
| **0 – Prep** | **In progress (~85% automatable)** | Platform-tools ✓; WSL2 + disk ✓; **WSL build packages installed** (root apt, 2026-10-31); adb ✓ (last check 2026-10-30); **Full OTA not in `downloads/`** (CDN keys gone); fastboot **not detected** on PC; drivers zip present, fastboot not confirmed |
| **1–7** (kernel / ROM) | Not started | Blocked on Phase 2 unlock |
| **8 – Local AI (Plan B)** | **En uso (Termux + LLM)** | [08-ai-local.md](phases/08-ai-local.md) + [termux-llm-guide.md](termux-llm-guide.md) + [phone-tuning.md](phone-tuning.md) + [always-on-battery.md](always-on-battery.md) + [rmx3311-llm.md](benchmarks/rmx3311-llm.md) + [rmx3311-llm-opencl-vulkan.md](benchmarks/rmx3311-llm-opencl-vulkan.md) (GPU no viable) |
| **Rootless Kali (Plan B)** | **En uso (Termux + Kali proot)** | [rootless-kali.md](rootless-kali.md) — ver sección *Instalación verificada* |

**Active phase:** [00 – Prep](phases/00-prep.md)  
**Gate reference:** [PHASE-GATES.md](PHASE-GATES.md)

## Repo vs device

Phase 5 **scripts and docs** are scaffolding. Kernel builds need **Phase 4** ROM on device + matching sources + WSL toolchain.

## Done automatically (PC)

- [x] `check-platform-tools.ps1` — adb/fastboot **37.0.1**
- [x] `verify-wsl.sh` — WSL2, Ubuntu **24.04.3**, ~951 GB free on `/`
- [x] WSL build deps — `apt-get install` as **root** (2026-10-31): gcc, clang, lld, make, repo, ccache, etc. (all packages already present / confirmed)
- [x] `clone-kernel-tree.sh` dry-run — URLs/branches documented (no clone without `CONFIRM=1`)
- [x] Phase 0 helpers: `verify-downloads.ps1`, `check-adb-device.ps1`, `start-wsl-build-setup.ps1`, [drivers-windows.md](drivers-windows.md), [downloads/README.md](../downloads/README.md)
- [x] `check-adb-device.ps1` — **RMX3311** / RE58B2L1, build **RMX3311_15.0.0.1650(EX01)**, battery 100% — [device-record.md](device-record.md)
- [x] Full OTA **metadata** for **1650 (EX01)** — links + MD5 in [downloads/README.md](../downloads/README.md) (zip **not** downloadable from documented CDN as of 2026-10-31)

## Blockers (Phase 0 — user action)

1. **Full OTA zip** — documented EU CDN URLs return **HTTP 404 NoSuchKey** (object removed from Aliyun OSS). Use [OTA-Pulse](https://0x8008.github.io/otapulse-web/) (RMX3311 → **EU** → Android 15) or XDA mirror; save as `downloads/RMX3311_11.H.29_EUEX_202603191634_full_ota.zip`; then `verify-downloads.ps1` + `verify-ota-md5.ps1` (MD5 `efb2705f94cffb79a6ff8527ffb40b18`). **Do not** use `RMX3311_11.A.22_…` (MD5 `5777f997…`).
2. **Fastboot visibility** — `fastboot devices` empty; `getvar product` / `unlocked` blocked on “waiting for device”. Re-check USB cable/port, **Android Bootloader Interface** driver ([drivers-windows.md](drivers-windows.md)); `Realme-Driver-Setup-v2.0.zip` is in `downloads/` but fastboot not verified.
3. Skim [PLAN.md](PLAN.md) EU/unlock warnings (checkbox in [00-prep.md](phases/00-prep.md)).

## Next actions (in order)

**Windows (repo root):**

```powershell
.\scripts\windows\check-platform-tools.ps1
.\scripts\windows\verify-downloads.ps1
.\scripts\windows\verify-ota-md5.ps1
.\scripts\windows\list-fastboot-devices.ps1
```

**WSL (toolchain already installed):**

```bash
bash /mnt/c/Users/<you>/Desktop/Proyects/realme-gt2-second-life/scripts/wsl/verify-wsl.sh --require-toolchain
```

Note: `--require-toolchain` may exit early on `lld --version` (non-zero on Ubuntu); tools `ld.lld`, gcc, clang, make, repo are installed — confirm with `command -v gcc clang make repo ld.lld`.

When [PHASE-GATES.md](PHASE-GATES.md) **0 → 1** passes, continue with [01 – Factory reset](phases/01-factory-reset.md) (**do not** reset until you explicitly confirm).

**Plan B (opcional, teléfono ya operativo):** Termux:Boot + sshd al reboot — [termux-boot-services.md](termux-boot-services.md): `push-termux-boot.ps1` → `install-boot-services.sh` → reboot → `phone-check.ps1`.

## Do not skip

- Full OTA **before** unlock/flash ([PLAN.md](PLAN.md)).
- Phase 2 stop condition if Deep Testing / unlock fails on EU.
- Destructive restore: `CONFIRM=1` only ([restore-critical-partitions.sh](../scripts/backup/restore-critical-partitions.sh)).
