# Afinado Realme GT 2 (RMX3311) — Termux + LLM local

**Fecha:** 2026-10-31  
**Dispositivo:** RMX3311, SD888, 8 GB RAM física + expansión 8 GB, Android 15 / ColorOS 15, stock, sin root  
**ADB:** `YOUR_ADB_SERIAL`  
**Termux:** F-Droid 0.118.3 (`com.termux`)

---

## Resumen ejecutivo

| Tema                                  | Conclusión                                                                                                                                         |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **~35 s en “Hola, qué tal?”**         | Causa principal: **SmolLM3 “extended thinking”** (razonamiento oculto) + carga inicial del modelo. No es un fallo de `-t 2` ni solo de `/sdcard/`. |
| **Opción desarrollador “4 procesos”** | **No** es la que necesitas. Activa **Desactivar restricciones de procesos hijo**. El límite de caché en adb muestra **48** (estándar), no 4.       |
| **Expansión RAM 8 GB**                | **~7,5 GiB de swap** en flash (`SwapTotal`); puede ralentizar KV cache bajo presión.                                                               |
| **Termux adb**                        | Doze whitelist OK; phantom procs **re-aplicado**; standby bucket ColorOS opaco (`5`); wake-lock activo con `llm smol`.                             |
| **Fix aplicado en repo**              | Scripts con `--reasoning off`, bootstrap copia GGUF a `~/models/` (ext4 Termux).                                                                   |

---

## A. Estado Termux (verificado por adb)

### Lista blanca Doze / idle

```
user,com.termux,10334
```

**OK** — Termux en whitelist (`dumpsys deviceidle whitelist`).

### AppOps relevantes (`cmd appops get com.termux`)

| Operación | Modo |
|-----------|------|
| `RUN_ANY_IN_BACKGROUND` | **allow** |
| `START_FOREGROUND` | **allow** (running durante sesión) |
| `WAKE_LOCK` | **allow** (running — `termux:service-wakelock`) |
| `READ/WRITE_EXTERNAL_STORAGE` | **allow** |
| `LEGACY_STORAGE` | allow |

`RUN_IN_BACKGROUND` no aparece como op separada en esta build; el equivalente útil es `RUN_ANY_IN_BACKGROUND`.

### Permisos de paquete

Instalados y concedidos en runtime: almacenamiento, notificaciones, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `FOREGROUND_SERVICE`, `WAKE_LOCK`, `INTERNET`. Coherente con batería “sin restricciones” en UI.

### Standby bucket

```
am get-standby-bucket com.termux → 5
```

Se ejecutó `am set-standby-bucket com.termux active` y `… 10` — la lectura **sigue en 5** (mapeo propio de ColorOS o bucket ya favorable). **Reversible**; no crítico mientras Termux esté en primer plano con notificación.

### Procesos fantasma (Android 12+)

| Clave                                   | Valor sesión                 | Acción                       |
| --------------------------------------- | ---------------------------- | ---------------------------- |
| `device_config … max_phantom_processes` | `null` (OEM había reseteado) | **Re-aplicado** `2147483647` |
| `settings_enable_monitor_phantom_procs` | `false`                      | Ya correcto (sesión previa)  |

Deshacer (como en guía):

```powershell
adb -s YOUR_ADB_SERIAL shell "device_config put activity_manager max_phantom_processes 32"
adb -s YOUR_ADB_SERIAL shell "settings put global settings_enable_monitor_phantom_procs true"
```

### Límite de procesos en segundo plano (developer)

Fragmento `dumpsys activity`:

```
max_cached_processes=1024
mOverrideMaxCachedProcesses=48
CUR_MAX_CACHED_PROCESSES=48
max_phantom_processes=2147483647
```

**Interpretación:** el ajuste **“Límite de procesos en segundo plano → Como máximo 4 procesos”** (*Background process limit*) **no** está reflejado como `4` en estas cifras (48 ≈ comportamiento estándar/ColorOS). Esa opción limita apps **en caché** cuando el sistema reclama RAM; **no** sustituye **Desactivar restricciones de procesos hijo**.

**¿Puede matar Termux con Brave en primer plano?**

- `llama-server` corre como proceso hijo de Termux; con `termux-wake-lock` y `START_FOREGROUND` **allow**, mientras Termux muestre notificación y no entres en ahorro de energía agresivo, **no debería** ser la causa de ~35 s.
- Riesgo real en ColorOS: **matar hijos / congelar app** sin la opción de procesos hijo + batería — no el límite “4 procesos” por sí solo.

**Recomendación:** Opciones de desarrollador → **Desactivar restricciones de procesos hijo** (*Disable child process restrictions*). Deja el límite de segundo plano en **Sin límite / Estándar** (no en 4).

### ColorOS — batería / autostart

No hay clave adb única tipo `app_quick_freeze` para Termux. Revisar manualmente:

- **Ajustes → Batería → Gestión de batería de apps → Termux** → autoarranque, segundo plano, sin optimización estricta.
- Evitar **congelar** Termux en multitarea / asistente inteligente.

`settings list global` relevante: `zram_enabled=1`, `settings_enable_monitor_phantom_procs=false`.

### RAM, zram y “Expansión de RAM 8 GB”

```
MemTotal:     ~7,1 GiB
MemAvailable: ~3,1–3,8 GiB (con apps abiertas)
SwapTotal:    7864316 kB  (~7,5 GiB)
SwapFree:     ~7,5 GiB (poco usado en reposo tras parar llama)
zram_enabled: 1
```

- La **expansión 8 GB** en ColorOS coincide con **swap en flash** (~7,5 GiB visibles en `SwapTotal`), además de políticas de compresión/zram del kernel.
- **GGUF mmap** desde `/sdcard/`: lectura vía FUSE — page-in lento en **primera carga**.
- **KV cache** (memoria anónima): bajo presión puede ir a **swap** → caída fuerte de tok/s (se vio `kswapd` activo con carga alta).

**Recomendación:** mantener **≥3,5 GiB** `MemAvailable` antes de `llm smol`; cerrar **Brave** y apps pesadas; modelos en `~/models/` (ext4 Termux).

---

## B. Diagnóstico latencia ~35 s (mediciones reales)

### Condiciones

- Binario: `/data/local/tmp/llama/llama-cli` / `llama-server` **b12017**, `LD_LIBRARY_PATH=/data/local/tmp/llama`
- Modelo: `HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf`, `-c 4096 -t 2 -ngl 0`
- Prompt: `Hola, qué tal?`
- Temp durante pruebas: **~38 °C** (por encima del 36 °C ideal de benchmarks; throttling leve posible)

### 1) Modo thinking (comportamiento actual del usuario con `--jinja` sin `--reasoning off`)

| Ruta modelo | Modo | Wall clock (cli) | Gen t/s (cli) |
|-------------|------|------------------|---------------|
| `/data/local/tmp/models/` | thinking on | **~34 s** | **8,4** |
| `/data/local/tmp/models/` | thinking on | ~49 s | 4,6 |
| `/sdcard/Download/llm-models/` | thinking on | **~51 s** | **5,6** |

Salida típica: bloque `[Start thinking]` + párrafo de razonamiento en inglés **antes** de responder en español.

### 2) `--reasoning off` (fix)

| Ruta | Wall clock (cli) | Gen t/s |
|------|------------------|---------|
| tmp | **~26 s** (incluye carga) | 4,3 |
| sdcard | ~29 s | 8,2 |

Respuesta directa tipo: *«¡Hola! ¿Qué tal? …»* sin bloque thinking.

### 3) `llama-server` + `/v1/chat/completions` (modelo en tmp, caliente)

| Config servidor | prompt_tokens | completion_tokens | Tiempo total |
|-----------------|---------------|-------------------|--------------|
| Default thinking | **253** | **64** (`reasoning_content`, `content` vacío) | **~30,1 s** |
| `--reasoning off` | **73** | ~29 | **~10,3 s** |
| Default + `chat_template_kwargs.enable_thinking: false` | 73 | ~31 | **~8,2 s** |

- **Plantilla / system prompt:** ~**73 tokens** de prompt con thinking desactivado vs **~253** con thinking activo (misma pregunta usuario).
- **Carga servidor** (log): ~**13 s** hasta `listening on http://127.0.0.1:18080` (primera vez).
- `llama-bench` **~9,6 tok/s** mide generación tg128 **sin** chat thinking — compatible con **~6 tok/s** en chat con plantilla.

### Causa raíz de ~35 s

1. **~60–70 %:** modo **thinking** genera **decenas de tokens ocultos** (hasta agotar `max_tokens` en la UI) a ~5–8 tok/s → **~25–30 s** solo en API.
2. **~25–40 %:** **carga del modelo** (~10–15 s la primera vez) + path `/sdcard/` algo más lento que ext4.
3. **Secundario:** RAM baja con Brave + swap; temperatura ~38 °C.

**No medido como causa principal:** límite “4 procesos” (CUR=48); Termux tenía wake-lock y foreground ops OK.

### Limpieza bench adb

Copia temporal en `/data/local/tmp/models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf` **eliminada** tras pruebas. Logs API: `docs/benchmarks/runs/api-*.txt`.

---

## C. Cambios en scripts (repo)

| Archivo                        | Cambio                                                                                          |
| ------------------------------ | ----------------------------------------------------------------------------------------------- |
| `scripts/termux/llm-common.sh` | Resuelve `~/models/` nativo si hay `.gguf`; `LLM_REASONING=off` → `--reasoning off` en servidor |
| `scripts/termux/run-smol.sh`   | Comentario; usa helper reasoning                                                                |
| `scripts/termux/bootstrap.sh`  | **Copia** GGUF de Descargas → `~/models/`; enlace `~/models-sdcard`                             |

### PC — publicar scripts en el teléfono

```powershell
adb -s YOUR_ADB_SERIAL push "c:\Users\<you>\Desktop\Proyects\realme-gt2-second-life\scripts\termux" /sdcard/Download/llm-setup/
```

### Termux — one-liners (pegar)

```bash
cp -f ~/storage/shared/Download/llm-setup/{llm-common.sh,run-smol.sh,llm,bootstrap.sh} ~/bin/ && chmod +x ~/bin/*
bash ~/storage/shared/Download/llm-setup/bootstrap.sh
source ~/.bashrc
llm smol
```

Solo copiar **SmolLM3** a almacenamiento nativo (si no quieres repetir bootstrap completo):

```bash
mkdir -p ~/models && cp -f ~/storage/shared/Download/llm-models/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf ~/models/
llm smol
```

Probar thinking otra vez (lento a propósito):

```bash
LLM_REASONING=on llm smol
```

---

## D. Apps instaladas — candidatos a desactivar (solo propuesta)

**No se ha ejecutado** `pm disable-user`. Reversible con `pm enable`.

### Apps de usuario (`pm list packages -3`)

| Paquete | Notas |
|---------|--------|
| `org.fdroid.fdroid` | **No tocar** |
| `com.termux` | **No tocar** |
| `com.brave.browser` | Alto RAM (~350+ MB); cerrar antes de LLM, no desactivar si es navegador principal |
| `com.google.android.apps.youtube.music` | Candidato bajo riesgo |
| `com.google.android.apps.docs` | Candidato |
| `com.google.android.apps.chromecast.app` | Candidato |
| `com.google.android.apps.podcasts` | Candidato |
| `com.google.android.apps.subscriptions.red` | Candidato (Google One) |
| `com.google.android.apps.tachyon` | Duo/Meet — candidato si no usas videollamadas Google |
| `com.amazon.appmanager` | Candidato |
| `andes.oplus.documentsreader` | Candidato |
| `com.oneplus.brickmode` | Candidato |
| `com.coloros.backuprestore` | Candidato si no usas copia local |
| `com.coloros.note` | Candidato si usas otra app de notas |

### Bloat ColorOS / HeyTap (preinstalado — desactivar solo si no usas)

| Paquete | Riesgo | Motivo |
|---------|--------|--------|
| `com.heytap.pictorial` | Bajo | Lock screen magazine |
| `com.coloros.assistantscreen` | Bajo | Pantalla −1 / asistente |
| `com.heytap.browser` | Medio | Navegador OEM duplicado |
| `com.heytap.music` | Bajo | Música OEM |
| `com.oplus.games` | Bajo | Game Space |
| `com.coloros.video` | Bajo | Video OEM |
| `com.coloros.karaoke` | Bajo | Karaoke |
| `com.coloros.childrenspace` | Bajo | Espacio niños |
| `com.google.android.apps.youtube` | Medio | YouTube — desactivar solo si no lo usas |
| `com.google.android.apps.maps` | Medio | Maps |

**Nunca desactivar:** `com.android.systemui`, `com.android.launcher`, `com.android.phone`, `com.android.settings`, `com.google.android.gms`, `com.google.android.inputmethod.latin`, paquetes `com.oplus.`* core (batería, NAS, subsys, telecom), `com.heytap.mcs` (push OEM — a veces rompe notificaciones).

### Consumo en sesión de diagnóstico (`dumpsys meminfo`)

Top: `llama-server` **~2,2 GiB**, **Brave** ~350 MB + procesos sandbox, **System UI**, **GMS**, **Termux** ~210 MB.

### Tabla propuesta (bajo riesgo)

| Paquete | Riesgo | Comando desactivar | Deshacer |
|---------|--------|-------------------|----------|
| `com.heytap.pictorial` | Bajo | `adb shell pm disable-user --user 0 com.heytap.pictorial` | `adb shell pm enable com.heytap.pictorial` |
| `com.coloros.assistantscreen` | Bajo | `adb shell pm disable-user --user 0 com.coloros.assistantscreen` | `adb shell pm enable com.coloros.assistantscreen` |
| `com.heytap.music` | Bajo | `adb shell pm disable-user --user 0 com.heytap.music` | `adb shell pm enable com.heytap.music` |
| `com.oplus.games` | Bajo | `adb shell pm disable-user --user 0 com.oplus.games` | `adb shell pm enable com.oplus.games` |
| `com.google.android.apps.podcasts` | Bajo | `adb shell pm disable-user --user 0 com.google.android.apps.podcasts` | `adb shell pm enable com.google.android.apps.podcasts` |
| `com.google.android.apps.chromecast.app` | Bajo | `adb shell pm disable-user --user 0 com.google.android.apps.chromecast.app` | `adb shell pm enable com.google.android.apps.chromecast.app` |
| `com.amazon.appmanager` | Bajo | `adb shell pm disable-user --user 0 com.amazon.appmanager` | `adb shell pm enable com.amazon.appmanager` |

Confirma qué filas aplicar; no se ha modificado nada sin tu OK.

**Actualización 2026-10-31 (aplicado):** se desactivaron **17 paquetes** de las tablas de **bajo riesgo** (ver abajo). **`com.coloros.assistantscreen`** no aceptó `pm disable-user` (sigue en estado `default`, probable protección ColorOS). Deshacer: [`scripts/phone/undo-disable.ps1`](../scripts/phone/undo-disable.ps1). Instantánea previa: [`phone-tuning-snapshot-20261031-154629.txt`](phone-tuning-snapshot-20261031-154629.txt).

| Métrica | Antes | Después |
|---------|-------|---------|
| `MemAvailable` | 3 875 852 kB (~3,70 GiB) | 3 921 468 kB (~3,74 GiB) |
| `SwapFree` | 6 930 952 kB | ~6 991 456 kB |

### Procesos (force-stop, reversible)

Solo detiene procesos en RAM; **no** desinstala. No usar en Termux ni Tailscale.

| Paquete | Cuándo | Comando |
|---------|--------|---------|
| Apps ya desactivadas (pictorial, music, games, …) | Tras desactivar paquetes | `adb shell am force-stop <pkg>` |
| `com.coloros.phonemanager` | Opcional antes de sesión LLM (libera ~250 MB) | `adb shell am force-stop com.coloros.phonemanager` |

**No aplicado:** matar Brave (lo mantienes instalado; ciérralo manualmente antes de `llm smol`).

### SSH + comprobaciones (PC)

**Verificado 2026-10-31 (SSH + `phone-check.ps1`):** usuario **`u0_aNNN`**, puerto **8022**, `PasswordAuthentication no`, clave en `~/.ssh/authorized_keys` (**600**), directorio **700**. Prueba: `echo ok` vía SSH con clave dedicada.

Clave dedicada (sin passphrase — cómoda en LAN/USB; protege el fichero `%USERPROFILE%\.ssh\realme_gt2_termux`):

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 -o StrictHostKeyChecking=accept-new u0_aNNN@127.0.0.1
```

Tras Tailscale, sustituye `127.0.0.1` por la IP tailnet del teléfono (mismo puerto **8022**), p. ej. **`100.x.y.z`** (nombre MagicDNS: `realme-gt-2`).

```powershell
.\scripts\termux\phone-check.ps1
```

Referencia rápida: [`scripts/termux/README.md`](../scripts/termux/README.md).

### Termux:Boot + sshd al reiniciar (runit)

Para **SSH (8022)** tras reboot del teléfono (sin abrir Termux a mano): F-Droid **Termux:Boot**, ColorOS sin restricciones de batería en Termux + Termux:Boot, luego `install-boot-services.sh`. **No** arranca `llama-server` por defecto.

```powershell
.\scripts\windows\push-termux-boot.ps1
```

```bash
bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
```

Detalle, verificación post-reboot y opt-in LLM: **[termux-boot-services.md](termux-boot-services.md)**.

### Tailscale (app oficial)

- APK estable verificado: `tailscale-android-universal-1.104.4.apk` — SHA256 `47628cecde2de0ed03f4a69424635259023daf76fb5d9afeeddfa62761690984` ([pkgs.tailscale.com](https://pkgs.tailscale.com/stable/)).
- **Verificado 2026-10-31:** VPN **CONNECTED** (`com.tailscale.ipn`), IP tailnet **`100.x.y.z/32`** en `tun1` (visible también en Termux como `tun1`).
- Lista blanca Doze: `com.tailscale.ipn` añadido vía adb.

**Modo remoto LLM (`llm smol --remote`):** el servidor enlaza a la **IP Tailscale** (`100.x`), no a `0.0.0.0`, para no exponer el puerto **8080** en la Wi‑Fi LAN. API key en **`~/.llm-api-key`** (generada con Python si el binario `openssl` de Termux falla). Pruebas: **401** sin clave, **200** con `Authorization: Bearer …` (desde el teléfono y desde el PC **omen** en la misma tailnet).

**Alternativa Termux `pkg install tailscale`:** daemon userspace dentro de Termux, sin VPN “Always-on” del sistema; más frágil en ColorOS (Doze, sin rutas automáticas para otras apps). **Recomendado:** app Android oficial + `llm smol --remote`.

Si necesitas escuchar en **toda** la LAN (no recomendado): `LLM_REMOTE_BIND_ALL=1 llm smol --remote` (sigue exigiendo API key).

### Carga 24/7 (servidor LLM enchufado)

**Medido (adb, carga USB):** nivel **100%**, `temperature` **320** (~**32 °C** batería), sensores térmicos hasta **~44 °C** bajo carga sostenida.

En **ColorOS 15:** **Ajustes → Batería → Más / Configuración avanzada** → activa **Carga inteligente** / **Carga optimizada** (limita tiempo al 100%) y, si aparece, **Protección de carga** o límite **80–90%** para uso enchufado permanente. Mantén **Termux** y **Tailscale** sin optimización agresiva de batería.

Guía ampliada (degradación, hinchazón, wake-lock, cuándo no usar 24/7): **[always-on-battery.md](always-on-battery.md)**.

---

## E. Mantener el rol principal (política operativa)

**Implementado v1:** scripts `~/bin/mode`, `mode-lib.sh`, [termux-llm-guide.md](termux-llm-guide.md) § Modos, `install-optional-services.sh`. Comandos: `mode status`, `mode llm`, `mode media`, `mode light-stack`, `mode lab`, `mode idle`.

**Dispositivo:** 8 GB RAM física + expansión swap; rol **habitual** del repo = **LLM local** (`llama-server` vía `llm smol`). Plan B sin root — ver [STATUS.md](STATUS.md), matriz [second-life-ecosystem.md §3](second-life-ecosystem.md).

### Regla de oro

**Como mucho un servicio pesado de CPU/RAM a la vez.** Servicios ligeros pueden convivir en paralelo.

| Categoría | Ejemplos | Convivencia |
|-----------|----------|-------------|
| **Pesado (elige uno)** | `llama-server` / `llm smol --remote`; transcodificación **Jellyfin**; **Metasploit** masivo (`msfconsole` + jobs largos); escaneos **nmap** muy amplios + wordlists enormes; **udocker** / **QEMU** con carga | **Mutuamente excluyentes** entre sí |
| **Ligero (paralelo OK)** | **sshd** (8022), **Tailscale** (app), **syncthing**, **mosquitto** pequeño, **nginx** estático, **cloudflared** | OK con cualquier pesado **si** RAM libre ≥ ~1,5 GiB antes de entrar en Kali — ver `kali-common.sh` |

### Orden de prioridad (este RMX3311)

1. **LLM local** — rol principal documentado; API remota por Tailscale ([termux-llm-guide.md](termux-llm-guide.md)).
2. **Pentest rootless** — solo con **`llama-server` parado** (`pkill -f llama-server` o no arrancar `llm smol`). Entrada: `kali`; evitar `kali --force` salvo emergencia.
3. **Media server (Jellyfin)** — viable en **Direct Play**; transcode **no** concurrente con LLM ([second-life-ecosystem.md §1.3](second-life-ecosystem.md)).
4. **Domótica ligera (Node-RED + MQTT)** — solo si el pesado del momento **no** es LLM, o en **otro** hardware.

### Hacer / no hacer

| ✓ Hacer | ✗ No hacer |
|---------|------------|
| Parar LLM antes de `kali` o Jellyfin transcode | `llm smol` + `kali --force` + escaneo `-p1-65535` «porque cabe en swap» |
| `termux-wake-lock` en jobs largos (Kali, copias) | Dos pesados «un rato cada uno» sin `pkill` — KV cache y proot compiten |
| Consultar informes LLM desde **PC vía Tailscale** mientras Kali corre **en** Termux con LLM apagado | **Metasploit + PostgreSQL** en rootless (no soportado oficialmente) |
| Mantener **≥3,5 GiB** `MemAvailable` antes de `llm smol` (cerrar Brave, etc.) | **Immich server**, **Home Assistant** completo, **Docker daemon** en el mismo teléfono con LLM |
| Always-on enchufado con [always-on-battery.md](always-on-battery.md) | 24/7 sin vigilar hinchazón / carga al 100% perpetua |

### Cambio de rol (flujo práctico)

```bash
# De LLM → Kali
pkill -f llama-server    # o Ctrl+C en sesión llm
termux-wake-lock
kali                     # sin --force

# De Kali → LLM remoto
exit                     # salir del chroot si dentro
llm smol --remote        # wake-lock vía llm-common.sh
```

Scripts: guardias en [`kali-common.sh`](../scripts/termux/kali-common.sh), reasoning/RAM en [`llm-common.sh`](../scripts/termux/llm-common.sh).

---

## Checklist rápido post-informe

- [x] Opciones desarrollador: **Desactivar restricciones de procesos hijo**
- [x] Quitar límite erróneo “4 procesos” (opcional; dejar estándar)
- [x] Termux: batería sin restricciones + bloqueo en recientes
- [x] `adb push` scripts + bootstrap → `~/models/`
- [x] `llm smol` → saludo corto **~7 s** en caliente (**~18–27 s** frío incl. carga) — verificado 2026-10-31 vía SSH
- [x] Aprobar tabla de apps a desactivar (**20 paquetes** en `pm list packages -d`; objetivo original 17 bloat + 3 extra)
- [x] Termux: `ssh-setup.sh` (OpenSSH, solo clave pública)
- [x] Tailscale: sesión activa, IP **100.x.y.z**
- [x] `llm smol --remote` + API key en `~/.llm-api-key` (tailnet + PC probados)
- [x] **runit + boot script** — `install-boot-services.sh` ejecutado 2026-10-31 (`termux-services`, `~/.termux/boot/start-services`; **sin** `--enable-llama-smol`) — [`termux-boot-services.md`](termux-boot-services.md)
- [x] **App Termux:Boot** (F-Droid, abrir una vez) + reinicio → **sshd** al boot sin abrir Termux — verificado **2026-10-31** post-reboot (`com.termux.boot`, SSH vía adb forward, uptime ~12 min)
- [x] **`install-optional-services.sh`** + **`~/bin/mode`** (Jellyfin, Mosquitto, udocker, Node-RED vía npm) — 2026-10-31; tras instalar: `mode apply idle`

Ver también: [`always-on-battery.md`](always-on-battery.md), [`termux-llm-guide.md`](termux-llm-guide.md) (§ Modos), [`benchmarks/rmx3311-llm.md`](benchmarks/rmx3311-llm.md), [`service-modes-design.md`](service-modes-design.md), [`scripts/termux/README.md`](../scripts/termux/README.md).
