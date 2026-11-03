# Chat LLM local en Termux (RMX3311, sin root)

**Dispositivo:** Realme GT 2 (RMX3311), 8 GB RAM, Android 15 / ColorOS 15  
**Termux:** F-Droid **0.118.3** (no usar la fork de Google Play)  
**Benchmarks:** [`benchmarks/rmx3311-llm.md`](benchmarks/rmx3311-llm.md)  
**Fase:** [`phases/08-ai-local.md`](phases/08-ai-local.md)

---

## Qué ya hicimos desde el PC (adb)

| Acción | Comando / efecto | ¿Funcionó? |
|--------|------------------|------------|
| Lista blanca Doze para Termux | `adb shell dumpsys deviceidle whitelist +com.termux` | **Sí** — aparece `user,com.termux` |
| Subir límite procesos fantasma | `device_config put activity_manager max_phantom_processes 2147483647` | **Sí** — lectura: `2147483647` |
| Desactivar monitor de phantom procs | `settings put global settings_enable_monitor_phantom_procs false` | **Sí** — lectura: `false` |
| Mover 5 GGUF | `/data/local/tmp/models/` → `/sdcard/Download/llm-models/` | **Sí** — tamaños verificados |
| Binarios llama.cpp **b12017** (copia) | `/data/local/tmp/llama/` → `/sdcard/Download/llm-setup/llama-b12017/` | **Sí** — originales intactos en tmp |
| Scripts de chat | `scripts/termux/` → `/sdcard/Download/llm-setup/` | **Sí** |

**Termux:API** no es necesario para el LLM; `termux-wake-lock` viene de **termux-tools** (base). Solo lo usan los opcionales `charge-limiter` / `thermal-guard` ([always-on-battery.md §9](always-on-battery.md#9-limitador-de-carga-y-guardián-térmico-opt-in)).

### Deshacer tweaks adb (reversible)

```powershell
adb -s YOUR_ADB_SERIAL shell "dumpsys deviceidle whitelist -com.termux"
adb -s YOUR_ADB_SERIAL shell "device_config put activity_manager max_phantom_processes 32"
adb -s YOUR_ADB_SERIAL shell "settings put global settings_enable_monitor_phantom_procs true"
```

(Opcional) Si OEM resetea `device_config`:

```powershell
adb -s YOUR_ADB_SERIAL shell "device_config set_sync_disabled_for_tests none"
```

---

## ColorOS — obligatorio en el teléfono (una vez)

1. **Ajustes** → **Acerca del teléfono** → pulsa **Versión** 7 veces → **Opciones de desarrollador**.
2. Activa **Desactivar restricciones de procesos hijo**  
   (en inglés: *Disable child process restrictions*; en Android 14+ es la vía recomendada para Termux/proot).

   **No confundir** con **Límite de procesos en segundo plano** / *Background process limit* (“Como máximo 4 procesos”). Esa opción **no** sustituye a la anterior: solo reduce apps en caché cuando no las usas; **no** arregla el corte de procesos hijo de Termux. En adb, con límite estándar suele verse `CUR_MAX_CACHED_PROCESSES=48` (no “4”). Puedes dejar el límite de segundo plano en **Estándar**.
3. **Ajustes** → **Batería** → **Gestión de batería de apps** → **Termux** → permitir **autoarranque**, **actividad en segundo plano** y **primer plano**; desactiva optimización agresiva.
4. Durante sesiones largas: quita **modo ahorro de energía** y **bloquea Termux** en recientes (multitarea).

Sin esto, ColorOS puede matar `llama-server` con **signal 9**.

---

## Modos de servicio (`mode`, v1)

Interfaz única para no mezclar LLM, Kali y media en 8 GB RAM. Scripts en [`scripts/termux/mode`](../scripts/termux/mode).

```bash
# Tras install-boot-services.sh (copia mode → ~/bin)
mode status
mode llm                 # router llama-server (todos los modelos, bajo demanda; ver § Router)
mode idle                # para todo lo pesado
mode pentest --shell     # para LLM + shell Kali (sin kali --force)
mode media               # Jellyfin (install-optional-services.sh)
mode light-stack         # Mosquitto + Node-RED
```

Desde el PC (SSH):

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1 mode status
ssh … u0_aNNN@127.0.0.1 mode llm
```

**Tras reboot:** el boot aplica **`idle`** por defecto; ejecuta **`mode llm`** cuando quieras chat. Variable opcional: `TERMUX_DEFAULT_MODE=llm` (consume RAM al arrancar).

Diseño completo: [`service-modes-design.md`](service-modes-design.md).

## Router, KV q8_0, especulativa y métricas (b12017)

Flags verificados contra `tools/server/README.md` y el código del tag **b12017** (el mismo build que corre en el teléfono) y probados con el binario oficial `b12017` **x86_64** (no en el teléfono). Config opcional en **`~/.llm.conf`** (plantilla [`llm.conf.example`](../scripts/termux/llm.conf.example)); las variables de entorno mandan sobre el fichero.

| Opción | Cómo | Qué hace |
|--------|------|----------|
| **Router** (defecto en `mode llm` y servicio `llama-smol`) | `llm router` · `LLM_SERVER_MODE=router` | `llama-server` sin `-m` + `--models-preset ~/.cache/llm/router-presets.ini` (generado con los GGUF presentes) + `--models-max 1` + `--sleep-idle-seconds 600`. Un endpoint :8080; el modelo se carga con la 1.ª petición y se descarga tras 10 min sin uso. |
| Volver al modo anterior | `LLM_SERVER_MODE=single` en `~/.llm.conf` | `mode llm` / `llama-smol` = SmolLM3 fijo (`run-smol.sh`). Antes de arrancar el router se hace una sonda de capacidad (`llm router-check`, cacheada por binario en `~/.cache/llm/router-capability`, puerto de sonda `LLM_PROBE_PORT=18090`); si el build no soporta router, `mode llm`, `llm router` y el servicio `llama-smol` caen **al momento** a single con aviso. Si el router arranca pero no da `/health` en 30 s, `mode llm` también cae a single (y corta antes si el log muestra el error de subprocess). |
| **KV cache q8_0** | `LLM_KV_TYPE=q8_0` (cualquier `llm …`, router y servicio) | `-ctk q8_0 -ctv q8_0 -fa on` (la V cuantizada **exige** flash-attn en b12017; con `-fa off` falla al crear contexto). ≈ mitad de RAM de KV → más contexto (p. ej. `LLM_KV_TYPE=q8_0 llm qwen3b 8192`). |
| **Especulativa** | `llm qwen3b-spec` · preset router `qwen3b-spec` | Qwen2.5-3B + borrador Qwen2.5-0.5B: `--model-draft … --spec-type draft-simple --spec-draft-n-max 8 --spec-draft-p-min 0.75`. En b12017 **`--draft-max`/`--draft-min` ya no existen**. +~0,5 GiB RAM. Medida 2026-11-03: **sin ganancia** (2,86 vs 2,84 tok/s), pero con el teléfono limitado — [repetir](benchmarks/rmx3311-llm.md#variantes-router--kv-q8_0--especulativa-b12017). |
| **Métricas** | `LLM_METRICS=1` (defecto) | `--metrics` → `GET /metrics` (Prometheus). En router: `/metrics?model=smol`. El portal muestra tok/s medio, modelo cargado y aceptación del borrador. |

```bash
mode llm                         # router en segundo plano (log: ~/llm-mode.log)
llm models                       # smol / qwen3b / qwen05 / ds15 / phi / qwen3b-spec + estado
llm unload                       # descarga ya el modelo cargado (libera RAM sin parar el router)
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"smol","messages":[{"role":"user","content":"hola"}]}'
curl -s 'http://127.0.0.1:8080/metrics?model=smol' | grep tokens_seconds
```

### Router NO disponible con el binario empaquetado (prueba 2026-11-03)

En el teléfono, el `llama-server` b12017 instalado (paquete/binario Android) **falla el modo router al instante**:

```
failed to initialize router models: subprocess is not enabled on this build
```

Causa (verificado en el código de llama.cpp, `CMakeLists.txt` del tag b12017 y de `master`): el router lanza un subproceso `llama-server` por modelo y eso depende de la opción CMake **`LLAMA_SUBPROCESS`** (*"llama-common: use subprocess, required by server tools and server router mode"*), que vale **`OFF` por defecto cuando se compila para Android** (también iOS/WASM). El [build.sh de Termux](https://github.com/termux/termux-packages/blob/master/packages/llama-cpp/build.sh) no la activa, así que `pkg install llama-cpp` tampoco trae router. Con estos binarios **el router no es usable**; los scripts lo detectan y usan single (SmolLM3).

Opciones si quieres router de verdad:

1. **Compilar llama.cpp desde el código fuente en Termux** con la opción activada (30–90 min en el SD888):
   ```bash
   pkg install -y git cmake ninja clang make libandroid-spawn
   git clone --depth 1 https://github.com/ggml-org/llama.cpp ~/src/llama.cpp
   cmake -S ~/src/llama.cpp -B ~/src/llama.cpp/build -DCMAKE_BUILD_TYPE=Release \
     -DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod -DLLAMA_BUILD_SERVER=ON -DLLAMA_SUBPROCESS=ON
   cmake --build ~/src/llama.cpp/build -j"$(nproc)"
   cp -a ~/src/llama.cpp/build/bin/* ~/opt/llama-b12017/   # o LLM_BIN_DIR=… en ~/.llm.conf
   rm -f ~/.cache/llm/router-capability && llm router-check
   ```
   (`bootstrap.sh` ya pasa `-DLLAMA_SUBPROCESS=ON` cuando compila desde fuente.) **No probado aún en el teléfono:** que el subproceso funcione bajo Android/Termux con esta opción forzada está sin verificar; si enlaza mal, prueba añadiendo `-DCMAKE_EXE_LINKER_FLAGS=-landroid-spawn` (lo que hace el paquete de Termux).
2. **Proxy tipo [llama-swap](https://github.com/mostlygeek/llama-swap)**: un endpoint OpenAI que arranca/para un `llama-server` single por modelo según el campo `"model"` (mismo efecto que el router, sin necesitar `LLAMA_SUBPROCESS`). No integrado en estos scripts.
3. Quedarse en **single** (`echo 'LLM_SERVER_MODE=single' >> ~/.llm.conf`): evita la sonda en cada arranque; `llm <modelo>` para cambiar de modelo.

**Ojo con el router:** la API **exige** el campo `"model"` (la UI web tiene selector). Con `--models-max 1`, pedir otro modelo descarga el anterior (recarga ~10–15 s). En presets fijamos `ctx-size` (sin él, `--fit` elegiría el contexto máximo y en CPU la RAM se considera ilimitada). `thermal-guard` puede forzar menos hilos con `~/.cache/llm/threads-override`.

**Benchmark en el teléfono** (baseline vs KV q8_0 vs especulativa): [`scripts/bench/run-llm-variants.sh`](../scripts/bench/run-llm-variants.sh) — ver [benchmarks/rmx3311-llm.md](benchmarks/rmx3311-llm.md#variantes-router--kv-q8_0--especulativa-b12017).

### Portal homepage (puerto 8081)

Enlaces a servicios, tablas de modos/modelos y estado en vivo (`status.json`). Instalación: [`portal-homepage.md`](portal-homepage.md) · `bash ~/storage/shared/Download/llm-setup/install-portal.sh`.

### Jellyfin (`mode media`)

1. `bash ~/storage/shared/Download/llm-setup/install-optional-services.sh` (instala `jellyfin-server`, **dotnet-runtime-10.0**, runit con [`services/jellyfin/run`](../scripts/termux/services/jellyfin/run) — define **`DOTNET_ROOT=$PREFIX/lib/dotnet`**).
2. `mode media` — para LLM, levanta Jellyfin en **8096**.
3. Navegador (Tailscale conectada en el **teléfono**): `http://100.x.y.z:8096/web/` — asistente inicial y biblioteca bajo `~/storage/shared/…` (ruta absoluta Jellyfin: `/data/data/com.termux/files/home/storage/shared/Movies`).
4. **Direct Play** preferido; no transcodificar con LLM activo.
5. Media de prueba legal (Blender, Syncthing, `adb push`): [jellyfin-media.md](jellyfin-media.md).
6. Volver: `mode idle` o `mode llm`.

Si el log runit dice «You must install .NET», re-copia el `run` del repo sobre `$PREFIX/var/service/jellyfin/run`.

**Tailscale tras reboot:** abre la **app Android** Tailscale (VPN ON); `phone-check` puede mostrar «sin 100.x» en Termux aunque el túnel esté bien en el sistema.

---

## Pasos en el teléfono (~6)

1. Abre **Termux** (F-Droid).
2. `termux-setup-storage` → concede permiso de almacenamiento.
3. `bash /sdcard/Download/llm-setup/bootstrap.sh`  
   (copia binarios a `~/opt/`, scripts a `~/bin/`, **copia GGUF a `~/models/`** en almacenamiento Termux — mmap rápido).
4. Cierra y vuelve a abrir Termux (carga `PATH` y `termux.properties`).
5. `llm smol` → espera *“loading model”* → abre el navegador: **http://127.0.0.1:8080** (UI de chat de `llama-server`).
6. Para parar: **Ctrl+C** en Termux, o `pkill -f llama-server`.

Comandos alternativos: `llm qwen3b`, `llm qwen05`, `llm ds15`, `llm phi` (ver tabla abajo).

---

## Dónde están los modelos

| Ubicación | Acceso |
|-----------|--------|
| **`~/models/*.gguf`** | Copia en almacenamiento privado Termux (recomendado; bootstrap) |
| **`/sdcard/Download/llm-models/*.gguf`** | Copia en SD/FUSE (`~/models-sdcard` o `~/storage/shared/...`) — más lenta en carga |
| PC (copia) | `downloads/models/` en el repo |
| Bench adb (solo shell) | `/data/local/tmp/llama/` — **Termux no puede leer tmp** |

---

## Qué modelo usar

| Tarea | Modelo | Comando | Hilos | ctx | ~tok/s (tg128) | RAM pico |
|-------|--------|---------|-------|-----|----------------|----------|
| **Chat diario (recomendado)** | SmolLM3-3B Q4_K_M | `llm smol` | 2 | 4096 | **~9,6** | ~3,9 GiB |
| Multilingüe / alternativa 3B | Qwen2.5-3B | `llm qwen3b` | 4 | 4096 | ~6,9 | — |
| Respuestas muy rápidas | Qwen2.5-0.5B | `llm qwen05` | 4 | 4096 | ~51 (frío) | baja |
| Razonamiento / CoT | DeepSeek-R1 1.5B | `llm ds15` | 4 | 4096 | ~24 | — |
| Código / reasoning (pesado) | Phi-4-mini | `llm phi` | 4 | **2048** | ~5,4 | **~4,2 GiB** |

**No uses `-t 6` ni `-t 8` en modelos ≥3B** en este teléfono (cuelgues medidos).

### Glosario rápido

- **tok/s (tg128):** tokens generados por segundo; más alto = respuesta más fluida.
- **`-t` (hilos):** núcleos CPU para inferencia; en SD888, 3B rinde mejor con **2** (SmolLM3) o **4** (Qwen3B).
- **`-c` (contexto):** ventana de conversación; más ctx = más RAM (KV cache).
- **RAM:** mira `MemAvailable` antes de cargar; Phi necesita **≥4,5 GiB** libres o arriesgas cierre de Termux.

```bash
free -h
head -3 /proc/meminfo
```

---

## Detener / recuperar

| Problema | Qué hacer |
|----------|-----------|
| Parar servidor | Ctrl+C en Termux o `pkill -f llama-server` |
| Termux “signal 9” | ColorOS: pasos de batería + **Desactivar restricciones…**; vuelve a ejecutar `llm …` |
| OOM con Phi | `llm smol` o cierra apps; `llm phi 2048` |
| UI no carga | Comprueba que Termux sigue en primer plano; URL exacta **127.0.0.1:8080** (no `0.0.0.0` por defecto) |

---

## Si tarda mucho en responder (~30 s o más)

SmolLM3 trae **modo “thinking”** (razonamiento oculto) activo por defecto en plantillas recientes de llama.cpp. En chat verás `[Start thinking]` y el servidor puede gastar decenas de tokens en `reasoning_content` **antes** de mostrar la respuesta — con `max_tokens` bajo, la UI parece “colgada”.

**Medido en este RMX3311 (2026-10-31, adb):**

| Modo | prompt_tokens | completion | Tiempo API (modelo caliente, tmp) |
|------|---------------|------------|-------------------------------------|
| Thinking **on** (defecto) | **253** | 64 (solo reasoning) | **~30 s** |
| **`--reasoning off`** (scripts actuales) | **73** | ~29 | **~10 s** |
| `enable_thinking: false` en JSON | 73 | ~31 | **~8 s** |

La **primera** pregunta tras abrir `llm smol` suma **~10–15 s** de carga del GGUF (~1,8 GiB). Con modelos en **`/sdcard/`** (FUSE), la carga puede ser un poco más lenta que en **`~/models/`** (ext4 Termux).

**Qué hacer (en orden):**

1. Actualiza scripts desde el PC y vuelve a copiar a Descargas, luego en Termux:
   ```bash
   cp -f ~/storage/shared/Download/llm-setup/{llm-common.sh,run-smol.sh,llm,bootstrap.sh} ~/bin/
   chmod +x ~/bin/*
   bash ~/storage/shared/Download/llm-setup/bootstrap.sh   # solo si aún no copiaste GGUF a ~/models
   ```
2. Arranca con **`llm smol`** (ya incluye **`--reasoning off`**). Para probar thinking: `LLM_REASONING=on llm smol`.
3. Opciones de desarrollador: **Desactivar restricciones de procesos hijo** (no el límite “4 procesos”).
4. **Expansión de RAM 8 GB**: añade **~7,5 GiB de swap** en flash; si hay poca RAM libre, la KV cache puede ir a swap y bajar tok/s — cierra Brave/apps pesadas antes de inferir.
5. Tras cambios, **Ctrl+C** y vuelve a `llm smol`; la segunda pregunta debe ir en **~5–12 s** para un saludo corto.

Informe completo: [`phone-tuning.md`](phone-tuning.md).

### Acceso remoto con Tailscale

1. **Instala / abre Tailscale** en el teléfono (APK oficial en `downloads/apps/` o Play Store). Inicia sesión, acepta **VPN** y excluye Tailscale de optimización de batería.
2. **Verificado (RMX3311):** IP tailnet **`100.x.y.z`**, hostname **`realme-gt-2`**, interfaz **`tun1`** (también visible en Termux).
3. Actualiza scripts (`adb push` → copiar a `~/bin/`; ver [`scripts/termux/README.md`](../scripts/termux/README.md)) y arranca:
   ```bash
   llm smol --remote
   ```
   - Escucha en la **IP Tailscale** (`100.x`), **no** en `0.0.0.0` (evita exponer **8080** en la Wi‑Fi LAN).
   - Primera vez: crea **`~/.llm-api-key`** (`chmod 600`). Léela **solo en el teléfono**: `cat ~/.llm-api-key`.
   - Si `openssl` no está operativo en Termux, la clave se genera con **Python** (`secrets.token_hex`).
4. Desde otro dispositivo en la tailnet (p. ej. PC **omen**):
   - **UI:** `http://100.x.y.z:8080`
   - **API:** `http://100.x.y.z:8080/v1` + cabecera `Authorization: Bearer <clave>`
   - Sin clave → **401**; con clave → **200** (comprobado 2026-10-31).
5. **SSH a Termux:** puerto **8022**, usuario **`u0_aNNN`**, solo clave (`PasswordAuthentication no`).
   ```powershell
   adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022   # USB
   ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1
   # o vía tailnet:
   ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@100.x.y.z
   ```
   Setup una vez: `bash ~/storage/shared/Download/llm-setup/ssh-setup.sh`  
   Comprobación PC: `.\scripts\termux\phone-check.ps1`

**Seguridad:** modo normal `llm smol` → **127.0.0.1** sin API key. Modo remoto → **obligatoria** API key. Solo enlazar a toda la LAN si aceptas el riesgo: `LLM_REMOTE_BIND_ALL=1 llm smol --remote`.

**Termux `pkg install tailscale` (alternativa):** no integra VPN a nivel sistema; requiere `tailscaled` manual y suele ser peor en ColorOS que la app oficial.

### LAN / Wi‑Fi sin Tailscale (no recomendado)

Por defecto el servidor escucha solo **127.0.0.1**. Usa **`llm smol --remote`** solo con Tailscale o red de confianza + API key.

---

## Paquete Termux `llama-cpp`

El repo oficial de Termux empaqueta **v0.8.0** ([build.sh](https://github.com/termux/termux-packages/blob/master/packages/llama-cpp/build.sh)), **muy anterior** a los benchmarks **b12017**. El bootstrap instala primero la copia **b12017** desde `/sdcard/Download/llm-setup/llama-b12017/`; solo compila desde fuente si falta esa carpeta.

**GPU (OpenCL/Vulkan):** no uses plugins Termux en este dispositivo — prueba 2026-10-31: OpenCL sin plataforma o ~12 tok/s vs ~51 en CPU b12017. Detalle: [rmx3311-llm-opencl-vulkan.md](../benchmarks/rmx3311-llm-opencl-vulkan.md). Los scripts `llm` fuerzan **`-ngl 0`**.

---

## Opcional: arrancar desde el PC (adb)

Tras bootstrap + **reiniciar Termux**, con `allow-external-apps=true` en `~/.termux/termux.properties`:

```powershell
.\scripts\termux\adb-start-llm.ps1 -Model smol
```

**No verificado** en esta sesión (bootstrap debe ejecutarlo el usuario primero). Si falla, usa `llm smol` en Termux.

---

## Archivos del repo

| Ruta | Uso |
|------|-----|
| [`scripts/termux/bootstrap.sh`](../scripts/termux/bootstrap.sh) | Instalación única |
| [`scripts/termux/llm`](../scripts/termux/llm) | Menú principal |
| [`scripts/termux/run-*.sh`](../scripts/termux/) | Un script por modelo (`run-router.sh`, `run-qwen3b-spec.sh` nuevos) |
| [`scripts/termux/llm.conf.example`](../scripts/termux/llm.conf.example) | Plantilla `~/.llm.conf` (router, KV, especulativa, métricas) |
| [`scripts/bench/run-llm-variants.sh`](../scripts/bench/run-llm-variants.sh) | Benchmark baseline / KV q8_0 / especulativa (Termux) |
| [`scripts/termux/adb-start-llm.ps1`](../scripts/termux/adb-start-llm.ps1) | Intento adb RUN_COMMAND |
| [`scripts/termux/ssh-setup.sh`](../scripts/termux/ssh-setup.sh) | OpenSSH en Termux (una vez) |
| [`scripts/termux/install-boot-services.sh`](../scripts/termux/install-boot-services.sh) | Termux:Boot + runit (`sshd` al reboot) — [termux-boot-services.md](../docs/termux-boot-services.md) |
| [`scripts/termux/mode`](../scripts/termux/mode) | Perfiles RAM (`llm`, `pentest`, `media`, …) — [service-modes-design.md](../docs/service-modes-design.md) |
| [`scripts/termux/install-optional-services.sh`](../scripts/termux/install-optional-services.sh) | Jellyfin, Mosquitto, Node-RED, udocker |
| [`scripts/termux/phone-check.ps1`](../scripts/termux/phone-check.ps1) | Estado vía SSH |
| [`scripts/phone/undo-disable.ps1`](../scripts/phone/undo-disable.ps1) | Revertir apps desactivadas |

Más estabilidad Termux/Kali: [`rootless-kali.md`](rootless-kali.md#coloros-15-realme--termux-stability).
