# Diseño propuesto: modos de servicio (Termux, RMX3311)

**Estado:** **implementado v1** (scripts `mode`, `mode-lib.sh`, runit opcional)  
**Fecha:** 2026-10-31  
**Contexto:** Realme GT 2 (RMX3311), ColorOS 15 / Android 15, **bootloader bloqueado**, 8 GB RAM, ~14 GiB en Termux (modelos LLM + Kali rootless), rol principal **LLM local**, acceso remoto **SSH + Tailscale (app Android)**.  
**Referencias:** [second-life-ecosystem.md](second-life-ecosystem.md) §3, [rootless-kali.md](rootless-kali.md), [termux-llm-guide.md](termux-llm-guide.md), scripts `scripts/termux/kali-common.sh`.

---

## Objetivo

Evitar OOM, cierres por ColorOS (signal 9) y conflictos conocidos (LLM ↔ Kali ↔ media pesada) mediante **perfiles mutuamente excluyentes** para servicios pesados, con servicios ligeros en paralelo cuando tenga sentido.

---

## Principios (alineados con la matriz del repo)

1. **Un solo servicio pesado de CPU/RAM** a la vez: `llama-server`, transcodificación Jellyfin/Plex, Metasploit masivo, QEMU, contenedores udocker grandes.
2. **En paralelo** (bajo impacto): `sshd`, Tailscale (app), Mosquitto pequeño, Syncthing incremental, **portal nginx (:8081)** — ver [portal-homepage.md](portal-homepage.md).
3. **Kali:** respetar guardias existentes; preferir **parar LLM** antes de pentest; `kali --force` solo como escape manual, no como modo por defecto.
4. **Almacenamiento:** ~84 GB útiles; biblioteca media grande compite con ~7,6 GiB de modelos — SD/USB si Jellyfin.

---

## Recomendación (v1 — uso diario)

Tras auditoría dispositivo 2026-10-31 ([STATUS.md](STATUS.md) § Plan B on device):

**Implementar la idea 2** (`~/bin/mode` + `flock` + umbrales `MemAvailable`) como **interfaz única**, con:

- **Idea 1** embebida como tabla de modos (`llm`, `pentest`, `media`, `light-stack`, `idle`, `lab`).
- **Idea 3** (`termux-services` / `sv`) para **ligeros** (sshd, mosquitto, jellyfin cuando exista) — no `llama-server` always-on.
- **Idea 5** en boot: `~/.termux/boot/` → `mode apply "${TERMUX_DEFAULT_MODE:-idle}"` (requiere [termux-boot-services.md](termux-boot-services.md) desplegado).
- **Idea 4** (cola + log) solo si más adelante hace falta automatizar transiciones largas.

**Stack opcional del usuario:** Jellyfin (`mode media`), Node-RED+Mosquitto (`light-stack`), lab **udocker** antes que QEMU+Docker (`lab`, LLM off). Ver [STATUS.md](STATUS.md) — ninguno instalado aún en el teléfono.

---

## Ideas concretas (5 propuestas)

### 1. Perfiles con mutex de servicios pesados

Definir modos nombrados con listas explícitas de procesos permitidos:

| Modo | Pesado activo | Ligeros típicos | Acción al cambiar |
|------|---------------|-----------------|-------------------|
| `llm` (default) | `llama-server` | sshd, Tailscale | — |
| `pentest` | proot Kali (escaneos) | sshd, wake-lock | **Parar** `llama-server` antes de entrar |
| `media` | Jellyfin (Direct Play) | sshd, Syncthing opcional | **Parar** LLM; no transcode concurrente |
| `gaming` *(futuro)* | JVM Minecraft (Paper/Purpur) | sshd, Tailscale | **Parar** LLM; `-Xmx2G`–`-Xmx3G`; wake-lock; puerto 25565 vía tailnet |
| `light-stack` | ninguno | mosquitto, syncthing, sshd | LLM apagado si RAM &lt; umbral |
| `idle` | ninguno | solo sshd + Tailscale | todo lo demás off |
| `maintenance` *(futuro)* | ninguno (LLM off) | sshd, rclone/restic puntual | **Parar** LLM; ventana upgrade/backup; ver [second-life-ecosystem.md §4](second-life-ecosystem.md) |
| `stt` *(futuro)* | whisper.cpp / faster-whisper | sshd | **Parar** LLM; batch transcripción |

Implementación futura: fichero de estado `~/.termux-mode` + funciones `start_heavy` / `stop_heavy` que usen los mismos criterios que `kali-common.sh` (`pgrep llama-server`, `MemAvailable`).

### 2. Script único `mode` con lock y comprobación RAM

Un comando en `~/bin/mode` (o en `scripts/termux/` desplegado al teléfono):

```text
mode status          # modo actual + MemAvailable + procesos pesados
mode llm             # transición segura → arranca llm vía llm smol
mode pentest         # pkill llama-server; termux-wake-lock; kali (sin --force)
mode light-stack     # sv up mosquitto syncthing (si existen)
mode media           # stop llm; sv up jellyfin (futuro)
```

- **Lock:** `flock` en `/data/data/com.termux/files/home/.mode.lock` para evitar dos transiciones a la vez (p. ej. SSH + Termux:Boot).
- **RAM:** leer `MemAvailable` de `/proc/meminfo`; rechazar `llm` si &lt; ~2,5 GiB; rechazar `pentest` si &lt; ~1,5 GiB (coherente con `kali-common.sh`).
- **Integración Kali:** `mode pentest` llama a `kali` normal (no `--force`); si LLM sigue vivo, falla con mensaje claro.

### 3. Capa `runit` / `sv` (paquete `termux-services`)

Registrar servicios ligeros y media como unidades bajo `$PREFIX/var/service/`:

- `sshd`, `mosquitto`, `syncthing`, (futuro) `jellyfin-server`
- **No** registrar `llama-server` como servicio always-on por defecto (consumo y política ColorOS); arrancarlo solo en modo `llm` vía script o unidad `run` bajo demanda.

`mode light-stack` haría `sv up` solo de la lista permitida; `mode llm` haría `sv down` de jellyfin/mosquitto si compiten (opcional: dejar mosquitto si RAM OK).

Termux:Boot ejecutaría **`mode idle`** o **`mode llm`** según preferencia en `~/.termux/boot/mode.sh`, no una docena de `sv up` sueltos.

### 4. Orquestador «stop LLM → acción» (cola de intenciones)

Fichero `~/.termux-mode/want` con una línea (`pentest`, `media`, …). Un bucle ligero (solo cuando el usuario lo pide, no daemon permanente) o hook en `mode`:

1. Si `want=pentest` y `llama-server` activo → avisar / esperar confirmación / `mode pentest --yes` mata LLM y lanza Kali.
2. Registrar en log simple `~/storage/shared/mode-transitions.log` para depurar OOM post-mortem.

Encaja con la regla del repo: **`kali --force` solo con LLM parado** en flujos automatizados; `--force` queda para uso manual en terminal.

### 5. Perfil remoto + Termux:Boot + Tailscale

- **Boot:** `~/.termux/boot/00-mode.sh` → `source ~/bin/mode-lib.sh && mode_apply "${TERMUX_DEFAULT_MODE:-llm}"`.
- **Remoto (SSH):** documentar `ssh phone mode pentest` igual que local.
- **Tailscale:** no sustituye el control de modos; solo transporte. Servicios escuchan en `127.0.0.1` o en la IP tailnet según guía LLM; Jellyfin requeriría decisión explícita de bind (seguridad).
- **Notificación Termux:** opcional `termux-notification` con modo actual tras cada transición (útil en pantalla del teléfono).

---

## Servicios opcionales y modos (referencia rápida)

Ver explicación detallada en el mensaje al usuario (Parte 1). Resumen para diseño:

| Servicio | ¿Modo recomendado? | Mutex con LLM |
|----------|-------------------|---------------|
| Syncthing | `light-stack` o paralelo a `llm` | No (incremental, bajo-medio) |
| Jellyfin / Plex | `media` | **Sí** (transcode); Direct Play parcial OK |
| Node-RED + Mosquitto | `light-stack` | Parcial (apagar LLM si RAM justa) |
| udocker / QEMU+Docker | modo `lab` experimental | **Sí** — solo con LLM apagado |
| Minecraft Java (Paper) | `gaming` *(futuro)* | **Sí** — §3.3 |
| Minetest / OpenTTD | `gaming` *(futuro)* | **Sí** |
| whisper.cpp | `stt` *(futuro)* | **Sí** |
| ntfy / Gotify | `light-stack` | No — hook `~/.config/gt2-power/notify-hook` ya previsto |
| Uptime Kuma / Healthchecks | `light-stack` | No |
| FreshRSS / Linkding | `light-stack` | No |
| Caddy reverse proxy | infra (runit) | No |
| Gitea / Forgejo (minimal) | `light-stack` / `lab` | Parcial |
| Open WebUI | `llm` | No (solo UI) |
| Vaultwarden / n8n | `light-stack` / `lab` | Parcial / **Sí** |
| rclone / Restic / Borg | `maintenance` | Parcial / **Sí** — **§4.2 NAS** |
| Jellyfin / Navidrome / Calibre (biblio NAS) | `media` | **Sí** — **§4.2** |
| Syncthing, PhotoSync, Immich cliente | `light-stack` / app | No / **§4.2** |

Backlog completo (autónomas vs NAS/sync): **[second-life-ecosystem.md §4](second-life-ecosystem.md)**.

---

## Próximos pasos (v2+)

1. ~~Extraer guardias de `kali-common.sh` a `mode-lib.sh` compartido.~~ **Hecho (v1).**
2. ~~Definir tabla de procesos «heavy»~~ **Hecho en `mode-lib.sh`.**
3. Añadir tests en dry-run: `mode status` desde `phone-check-remote.sh` — **parcial (v1).**
4. Enlazado desde [second-life-ecosystem.md](second-life-ecosystem.md) y [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa). Arranque tras reboot: [termux-boot-services.md](termux-boot-services.md) (`install-boot-services.sh` + `mode apply idle`).
5. **Modo `gaming`:** guía mínima + hook en `mode` (OpenJDK + Paper, Geyser opcional); benchmark 2 jugadores en tailnet antes de documentar como «operativo».

---

## Implementación v1 (repo)

| Artefacto | Ruta |
|-----------|------|
| CLI `mode` | [`scripts/termux/mode`](../scripts/termux/mode) → `~/bin/mode` |
| Librería | [`scripts/termux/mode-lib.sh`](../scripts/termux/mode-lib.sh) |
| Servicios runit | [`scripts/termux/services/`](../scripts/termux/services/) (`jellyfin` vía pkg, `mosquitto`, `node-red`) |
| Instalador opcional | [`install-optional-services.sh`](../scripts/termux/install-optional-services.sh) |
| Boot | `start-services` llama `mode apply ${TERMUX_DEFAULT_MODE:-idle}` |

**Boot:** por defecto **`idle`** (solo sshd + runit). Para LLM tras reinicio: `mode llm` manual, o `export TERMUX_DEFAULT_MODE=llm` antes del boot (no recomendado con Kali/media).

**Log de transiciones:** `~/storage/shared/mode-transitions.log`

### v1.1 (repo, 2026-11; sin probar en el teléfono)

| Cambio | Detalle |
|--------|---------|
| `mode llm` → **router** | `run-router.sh`: un `llama-server` en :8080 con todos los modelos como presets, `--models-max 1`, descarga tras `LLM_SLEEP_IDLE` (600 s). El proceso sigue vivo (≈ 40 MiB) pero la RAM del modelo se libera. `LLM_SERVER_MODE=single` en `~/.llm.conf` = comportamiento v1; si el router no da `/health` en 30 s, fallback automático a single (anotado en el log de transiciones). Ver [termux-llm-guide.md § Router](termux-llm-guide.md#router-kv-q8_0-especulativa-y-métricas-b12017). |
| Servicio `llama-smol` | Respeta `LLM_SERVER_MODE` (router por defecto). |
| **thermal-guard** | Nuevo servicio runit opcional; `mode llm` se niega si el estado térmico es `hot`/`critical`; `mode_stop_llama` envía `SIGCONT` antes de matar (por si estaba en `pause`). |
| **charge-limiter** | Si su servicio está habilitado, `idle` / `light-stack` **mantienen Mosquitto + Node-RED** (el enchufe depende de ellos). |
| `mode status` | Muestra modo del LLM (router/single, modelo, KV), estado térmico y batería (caché). |

Detalle de energía: [always-on-battery.md § 9](always-on-battery.md#9-limitador-de-carga-y-guardián-térmico-opt-in).

---

## No objetivos (v1)

- Home Assistant completo, Immich servidor, Metasploit + PostgreSQL en rootless.
- Docker daemon real (requiere root/unlock).
- Cambio automático de modo por horario (posible v2 con `termux-job-scheduler`).
