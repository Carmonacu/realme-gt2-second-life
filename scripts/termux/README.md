# Termux LLM — referencia rápida (RMX3311)

Seis comandos para el día a día (en **Termux**, salvo el check desde el PC).

## 1. Arrancar chat local (recomendado)

```bash
llm smol
```

UI en el navegador del teléfono: **http://127.0.0.1:8080** · Parar: **Ctrl+C** o `pkill -f llama-server`

## 2. Chat accesible desde la tailnet (Tailscale + API key)

```bash
llm smol --remote
```

Escucha en la **IP Tailscale** (`100.x`, interfaz `tun*`), no en toda la Wi‑Fi. Clave: `cat ~/.llm-api-key` (solo en el teléfono).

## 3. Actualizar scripts desde Descargas

Tras `adb push` del repo a `/sdcard/Download/llm-setup/`:

```bash
cp -f ~/storage/shared/Download/llm-setup/{llm,llm-common.sh,run-smol.sh,ssh-setup.sh,kali,kali-common.sh,kali-update,kali-uninstall,mode,mode-lib.sh,portal-status.sh} ~/bin/
chmod +x ~/bin/*
```

## 4. Comprobar RAM antes de un modelo grande

```bash
grep MemAvailable /proc/meminfo
```

Objetivo: **≥ 3,5 GiB** antes de `llm smol`; más para `llm phi`.

## 5. Estado completo desde el PC (USB + SSH)

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
.\scripts\termux\phone-check.ps1
```

## 6. SSH manual (mantenimiento)

```powershell
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1
```

**Una vez en Termux (si cambias de clave):** `bash ~/storage/shared/Download/llm-setup/ssh-setup.sh`

## 7. SSH / servicios tras reboot (Termux:Boot)

```powershell
.\scripts\windows\push-termux-boot.ps1
```

```bash
bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
```

Guía: [`docs/termux-boot-services.md`](../../docs/termux-boot-services.md).

## 8. Kali rootless (NetHunter en proot)

```bash
termux-wake-lock
kali              # entrar al chroot (bloquea si llama-server está activo)
kali-update       # apt en Kali
```

No ejecutar **`llm smol`** y escaneos pesados a la vez. Usa **`mode pentest`** (para el LLM antes de Kali). Detalle: [`docs/rootless-kali.md`](../../docs/rootless-kali.md).

## 10. Modos de servicio (`mode`)

Perfiles mutuamente excluyentes (LLM ↔ Jellyfin ↔ Kali). Tras copiar scripts:

```bash
mode status
mode llm              # chat local (SmolLM3)
mode idle             # todo pesado off
mode pentest --shell  # para LLM + entra a Kali (sin kali --force)
mode media            # Jellyfin (requiere install-optional-services.sh)
mode light-stack      # Mosquitto + Node-RED
mode lab              # udocker, LLM off
```

Al **boot** el teléfono aplica **`idle`** por defecto (`TERMUX_DEFAULT_MODE`); arranca LLM manualmente con `mode llm`. Diseño: [`docs/service-modes-design.md`](../../docs/service-modes-design.md).

Jellyfin: runit del repo [`services/jellyfin/run`](services/jellyfin/run) exporta **`DOTNET_ROOT=$PREFIX/lib/dotnet`** (sin él: «You must install .NET»). Media de prueba legal y rutas: [`docs/jellyfin-media.md`](../../docs/jellyfin-media.md).

```bash
bash ~/storage/shared/Download/llm-setup/install-optional-services.sh
```

## 8b. Pila *Arr* en el móvil (experimento)

qBittorrent-nox (Termux) + Radarr/Sonarr/Prowlarr + **FlareSolverr** (proot Ubuntu). `install-media-arr-stack.sh` instala *Arr* + FlareSolverr (Python/Chromium) y descarga **`~/media-arr/config/prowlarr/torrentio.yml`**; la **importación en Prowlarr** y Real-Debrid siguen siendo manuales → [`docs/media-stack-phone.md`](../../docs/media-stack-phone.md).

```bash
bash ~/storage/shared/Download/llm-setup/install-media-arr-stack.sh
mode media
media-stack start
media-stack status
```

Solo reinstalar FlareSolverr en proot: `proot-distro login ubuntu -- bash ~/media-arr/install-flaresolverr-inside-ubuntu.sh`  
Omitir FlareSolverr al instalar: `install-media-arr-stack.sh --no-flaresolverr`  
No arrancar FlareSolverr con la pila: `MEDIA_FLARESOLVERR=0 media-stack start`

Rollback: `uninstall-media-arr-stack.sh` (conserva `~/storage/shared/Movies` y `TV`).

## 11. Portal homepage (puerto 8081)

Una página con enlaces, modos, modelos y `status.json` en vivo (~5 MiB nginx).

```bash
bash ~/storage/shared/Download/llm-setup/install-portal.sh
```

Guía: [`docs/portal-homepage.md`](../../docs/portal-homepage.md). Tras `mode …`, el JSON se actualiza solo.

---

## 9. Copiar scripts Kali desde el repo (PC → teléfono)

```powershell
scp -P 8022 -i $env:USERPROFILE\.ssh\realme_gt2_termux `
  scripts/termux/kali* u0_aNNN@127.0.0.1:~/bin/
```

---

Más detalle: [`docs/termux-llm-guide.md`](../../docs/termux-llm-guide.md) · [`docs/phone-tuning.md`](../../docs/phone-tuning.md) · [`docs/rootless-kali.md`](../../docs/rootless-kali.md)
