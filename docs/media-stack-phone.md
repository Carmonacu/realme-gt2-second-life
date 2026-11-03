# Pila media en el móvil (experimento) — Jellyfin + qBit + *Arr*

**Estado:** experimental (pila 2026-10-31; indexadores Torrentio + FlareSolverr en proot documentados 2026-11-01)  
**Dispositivo:** RMX3311, 8 GB RAM, ~50–60 GB libres para biblioteca  
**Política:** si va lento, inestable o ColorOS mata procesos → desinstalar automatización y quedarte con Jellyfin + copias manuales ([jellyfin-media.md](jellyfin-media.md)).

**Configuración objetivo (ahora):** indexación en el teléfono con **Torrentio** (custom en Prowlarr) + **FlareSolverr** en el mismo **proot Ubuntu** que Radarr/Sonarr/Prowlarr — todo en un solo sitio, aceptando RAM ajustada. Ampliaciones en PC (Jackett, híbrido) → § [Ampliaciones futuras](#ampliaciones-futuras-cuando-haga-falta).

---

## Qué monta esto

| Pieza | Dónde corre | Puerto web (Tailscale / LAN) |
|-------|-------------|------------------------------|
| **Jellyfin** | Termux nativo | **8096** (`mode media`) |
| **qBittorrent-nox** | Termux nativo | **8090** (WebUI; no usar 8080 — LLM) |
| **Radarr** | proot **Ubuntu** | **7878** |
| **Sonarr** | proot Ubuntu | **8989** |
| **Prowlarr** | proot Ubuntu | **9696** |
| **FlareSolverr** (objetivo) | proot Ubuntu | **8191** (API; no es UI) |

Los *Arr* están en **.NET** y suelen necesitar **glibc** → **proot-distro Ubuntu** (no Termux solo). qBit en Termux evita otro chroot para torrents. **FlareSolverr** también va en proot (Chromium + **Python 3**), no en Termux.

**RAM:** usa `mode idle` o `mode media` antes de arrancar la pila; **no** `mode llm` a la vez. Con FlareSolverr activo el margen baja mucho — § [Presupuesto RAM](#presupuesto-ram-mode-media-sin-llm). Anota OOM en `~/storage/shared/mode-transitions.log`.

---

## Almacenamiento (biblioteca en el teléfono)

Tras `termux-setup-storage`:

| Uso | Ruta Termux |
|-----|-------------|
| Películas (Jellyfin + Radarr) | `~/storage/shared/Movies` |
| Series (Jellyfin + Sonarr) | `~/storage/shared/TV` |
| Torrents en curso (qBit) | `~/storage/shared/Downloads/torrents` |
| Config *Arr* / qBit | `~/media-arr/config/` |
| Binarios *Arr* | `~/media-arr/apps/` |

Rutas absolutas para Jellyfin (como en [jellyfin-media.md](jellyfin-media.md)):

- Películas: `/data/data/com.termux/files/home/storage/shared/Movies`
- Series: `/data/data/com.termux/files/home/storage/shared/TV`

---

## Instalación (una vez)

1. Copia scripts al teléfono (como el resto del repo): `~/storage/shared/Download/llm-setup/`.
2. En Termux:

```bash
export PATH=$HOME/bin:$PREFIX/bin:$PATH
bash ~/storage/shared/Download/llm-setup/install-media-arr-stack.sh
```

3. Tras instalar Ubuntu en proot (varios minutos), el script ejecuta el setup dentro del chroot (`install-inside-ubuntu.sh`: Radarr, Sonarr, Prowlarr en `~/media-arr/apps/`).
4. Opciones desarrollador + batería Termux: igual que [termux-llm-guide.md](termux-llm-guide.md) (restricciones de procesos hijo, Doze whitelist).

**Requisitos:** Jellyfin ya instalado (`install-optional-services.sh`). Espacio: Ubuntu rootfs ~2–4 GiB en `$PREFIX/var/lib/proot-distro/` además de la biblioteca.

**FlareSolverr:** no lo instala `install-media-arr-stack.sh` — pasos manuales en § [FlareSolverr en proot](#flaresolverr-en-proot-ubuntu).

---

## Uso diario

```bash
export PATH=$HOME/bin:$PREFIX/bin:$PATH

# 1) Parar LLM y activar Jellyfin
mode media

# 2) qBit + Radarr/Sonarr/Prowlarr (proot)
media-stack start

# 3) FlareSolverr (manual hasta que lo automatices tú)
# proot-distro login ubuntu -- bash -lc '… ver § FlareSolverr …'

# Estado
media-stack status

# Parar automatización (Jellyfin sigue si mode media)
media-stack stop

# Volver a rol LLM
media-stack stop
mode idle
mode llm
```

**Tailscale:** abre la app VPN en el teléfono; accede p. ej. `http://100.x.y.z:7878` (Radarr), `:8090` (qBit), `:8096` (Jellyfin), `:9696` (Prowlarr).

---

## Configuración inicial (manual, una vez)

### qBittorrent (8090)

- Usuario/contraseña por defecto suele ser `admin` / `adminadmin` — **cámbialo**.
- Descargas → carpeta por defecto:  
  `/data/data/com.termux/files/home/storage/shared/Downloads/torrents`
- **No** uses la carpeta bajo `media-arr/config/qbittorrent/.../downloads` ni el root `/` del proot Ubuntu — libtorrent puede crear **`~/.l2s` / `rootfs/.l2s`** con decenas de GB de parciales invisibles en el explorador.
- Tras instalar o si el disco se llena: **`qprune`** (o `qbit-prune`) — equivale a `media-stack stop` → limpieza `.l2s` → rutas qBit → `media-stack start`. Solo limpiar sin arrancar: **`qprune-ns`**.
- Manual equivalente: `media-stack stop` → `bash ~/bin/qbit-prune-orphans.sh` → `bash ~/bin/qbit-ensure-config.sh` → `media-stack start`.
- En Sonarr/Radarr: limita búsquedas masivas (temporada completa = N torrents); al quitar un torrent en qBit usa **eliminar con archivos** (`Session\DeleteTorrentContentsAsDefault=true` lo aplica el script `qbit-ensure-config.sh`).
- Categoría opcional `radarr` / `sonarr` (Radarr/Sonarr la crean al conectar).

### Prowlarr (9696)

- **Apps** → añadir Radarr (`http://127.0.0.1:7878`) y Sonarr (`http://127.0.0.1:8989`) — desde **dentro del teléfono** `127.0.0.1` enlaza Termux y proot cuando los servicios escuchan en todas las interfaces.
- Indexadores objetivo (Torrentio + Torznab con FlareSolverr): § [Configuración objetivo](#configuración-objetivo-ahora).

### Radarr / Sonarr

- **Root folder:** películas → ruta absoluta `…/storage/shared/Movies`; series → `…/storage/shared/TV`.
- **Download client:** qBittorrent, host `127.0.0.1`, puerto API qBit (8080 interno del daemon; en WebUI revisa *Web UI* / API).
- Completed download handling: mover/hardlink según prefieras; en un solo volumen, **hardlink** ahorra espacio (misma partición `/storage`).

### Jellyfin

- Bibliotecas Movies + TV apuntando a las rutas absolutas de arriba.
- Tras importación Radarr/Sonarr: **Scan library** o esperar escaneo programado.

---

## Configuración objetivo (ahora)

Política actual del proyecto: **no depender de un PC** para indexar; Prowlarr en el móvil con **Torrentio** (trackers/agregadores ES vía config) y **FlareSolverr** para indexers Torznab que fallen con Cloudflare (1337x, YTS, etc.). Es **subóptimo en RAM** pero concentra todo en el teléfono.

### Torrentio en Prowlarr

Torrentio agrega muchos proveedores (incl. **`mejortorrent`**, **`dontorrent`**, **`limetorrents`**, etc.) sin Chromium en el móvil. En *Arr* se usa el indexer custom de la comunidad, no el addon Stremio.

#### Carpeta `Definitions/Custom` (recomendado)

Prowlarr **no** usa solo “pegar YAML” en todos los casos: la forma estable es el folder **Custom** dentro del **App Data** de Prowlarr ([wiki Servarr](https://wiki.servarr.com/prowlarr/indexers#adding-a-custom-yml-definition)). Las definiciones se **cachean** un rato; tras cambiar un YML → **reinicia Prowlarr** o espera.

| Entorno | Ruta `Definitions/Custom` |
|---------|---------------------------|
| **Este teléfono (proot, `-data=…/config/prowlarr`)** | `~/media-arr/config/prowlarr/Definitions/Custom/` |
| Ruta absoluta (Jellyfin/qBit ya usan este estilo) | `/data/data/com.termux/files/home/media-arr/config/prowlarr/Definitions/Custom/` |
| Linux desktop | `~/.config/Prowlarr/Definitions/Custom/` |
| Docker | `/config/Definitions/Custom/` |

**En el repo:** `bash ~/storage/shared/Download/llm-setup/media-arr/fetch-torrentio-yml.sh` (o tras `install-media-arr-stack.sh`) deja **`torrentio.yml`** en esa carpeta Custom.

**Pasos:**

1. Asegura el archivo: `…/Definitions/Custom/torrentio.yml` (permisos de lectura para el usuario de Prowlarr en proot).
2. **System** → **Restart** Prowlarr (o reinicia la pila: `media-stack stop && media-stack start`).
3. **Indexers** → **Add Indexer** → busca **Torrentio** (nombre del YML) y añádelo — **no** hace falta duplicar el YAML si ya está en Custom.
4. **Alternativa:** **Add Indexer** → **Custom** → pegar el contenido del YML (útil para pruebas; para producción preferir Custom/).

5. **Configurar proveedores (español + resto):** [torrentio.stremio.ru/configure](https://torrentio.stremio.ru/configure) → marcas MejorTorrent, DonTorrent, etc. → copia solo la parte `providers=…|sort=…|…` al campo **Torrentio Options** del indexer → **Test**.

**Error de validación** `field=infohash, selector=url, value=<null>`: el YML antiguo (p. ej. `master` sin merge) busca `url` en el JSON; la API devuelve `infoHash`. Vuelve a ejecutar `fetch-torrentio-yml.sh` (repo fijado al fix con `selector: infoHash`) → **System → Restart Prowlarr** → borra el indexer Torrentio roto y créalo de nuevo.

**Debrid provider:** si **no** tienes API key de Real-Debrid, elige **None** y deja la key **vacía**. Con **Real-Debrid** seleccionado y key vacía la URL de prueba lleva `realdebrid=` y la validación suele fallar aunque el YML esté bien.

#### Con Real-Debrid (recomendado para automatización *Arr*)

| Campo típico en el indexer | Valor |
|----------------------------|--------|
| API key / Debrid | Token de [real-debrid.com/apitoken](https://real-debrid.com/apitoken) |
| Sort / quality | Según prefieras (4K, cam, etc.) |

**Flujo:** Prowlarr devuelve enlaces **alojados en debrid** cuando el release está en caché → Radarr/Sonarr pueden usar **cliente de descarga compatible** (según versión del YML: a veces HTTP directo, a veces still magnet). **qBittorrent local** sigue siendo el cliente principal del repo para torrents clásicos; con debrid puede hacer falta **Blackhole** / cliente debrid o aceptar que parte de releases vayan por HTTP — revisa el YML y los logs de Radarr al probar una película.

**Ventaja en el móvil:** cero RAM extra (solo HTTP).

#### Sin Real-Debrid

- Torrentio puede listar **imanes/enlaces** de trackers públicos; Radarr/Sonarr **pueden** enviarlos a **qBit** si el resultado es magnet/torrent válido.
- **Limitaciones:** muchos enlaces «premium» de la config Stremio **no** aplican; menos consistencia que con debrid; MejorTorrent/DonTorrent vía agregador ≠ mismo comportamiento que Jackett dedicado (episodios sueltos en series, etc.).
- Útil para **descubrimiento** y pruebas; para biblioteca local fiable en 8 GB, debrid o indexers Torznab directos suelen ir mejor.

#### Torrentio vs FlareSolverr

| | **Torrentio** | **FlareSolverr + Torznab** |
|---|---------------|----------------------------|
| RAM | ~0 extra | **+300 MiB–1,5 GiB** (Chromium) |
| ES (MejorTorrent, DonTorrent) | Vía proveedores en configure | Mejor con **Jackett** (futuro) o indexers Prowlarr que pasen test |
| Cloudflare | No aplica (API/agregador) | Resuelve desafíos para 1337x, etc. |

Puedes tener **ambos** en Prowlarr: Torrentio para agregación ES/debrid y Torznab+`flaresolverr` para trackers concretos.

**Qué no sustituye Torrentio:** Radarr/Sonarr/qBit/Jellyfin como pila local — ver tabla en § [Referencia rápida Torrentio](#referencia-rápida-torrentio).

---

### FlareSolverr en proot Ubuntu

**No hay Docker en el teléfono** como camino oficial del repo (stock + Termux). En proot sí puedes usar Docker si lo instalas tú en Ubuntu (pesado en ARM); lo habitual es **instalación desde código** (Python 3 + Chromium).

**Chromium en proot (snap):** en Ubuntu reciente, `apt install chromium-browser` suele ser un **stub de snap** que en proot **no funciona** (`requires the chromium snap`). El script `install-flaresolverr-inside-ubuntu.sh` usa, en este orden: **Google Chrome arm64** extraído en `~/media-arr/apps/chrome/` (si ya lo tienes), **Playwright Chromium** (`playwright install chromium` en el venv si no hay Chrome), o un `.deb` arm64 que instales tú. FlareSolverr 3.5.x **no lee** `CHROME_PATH` upstream; el script del repo **parchea** `src/utils.py` para respetarlo y evitar el stub de `/usr/bin/chromium-browser`. En **ARM64**, `undetected_chromedriver` suele bajar un driver **x86_64** — el script descarga **chromedriver linux-arm64** (Chrome for Testing, misma versión que el Chrome) y lo expone como `CHROMEDRIVER_PATH`.

**Red:** Prowlarr y FlareSolverr en el **mismo proot** → proxy `http://127.0.0.1:8191`. No hace falta reenvío Termux↔proot para este par. (qBit sigue en Termux → Radarr usa `127.0.0.1` hacia qBit como ya documentado arriba.)

#### Opción recomendada: script del repo (Python + Chromium en proot)

Desde Termux (copia scripts con `adb push` → `llm-setup`):

```bash
proot-distro login ubuntu -- bash /data/data/com.termux/files/home/media-arr/install-flaresolverr-inside-ubuntu.sh
proot-distro login ubuntu -- bash /data/data/com.termux/files/home/media-arr/start-flaresolverr.sh
```

O manualmente dentro de Ubuntu (`proot-distro login ubuntu`):

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates git python3 python3-pip python3-venv python3-dev build-essential
apt-get install -y chromium || apt-get install -y chromium-browser
apt-get install -y xvfb   # opcional

MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"
mkdir -p "$MEDIA_ARR/apps/flaresolverr"
cd "$MEDIA_ARR/apps/flaresolverr"
git clone --depth 1 https://github.com/FlareSolverr/FlareSolverr.git .
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export CHROME_PATH="$(command -v chromium || command -v chromium-browser)"
export LOG_LEVEL=info
# Prueba en primer plano:
.venv/bin/python src/flaresolverr.py
# Debe escuchar en :8191 — prueba desde proot:
curl -s http://127.0.0.1:8191/v1 -H 'Content-Type: application/json' \
  -d '{"cmd":"request.get","url":"https://www.google.com","maxTimeout":60000}' | head -c 200
```

**Arranque en segundo plano (manual):**

```bash
proot-distro login ubuntu -- bash -lc '
  bash /data/data/com.termux/files/home/media-arr/start-flaresolverr.sh
'
```

Documentación upstream: [FlareSolverr — Installation](https://github.com/FlareSolverr/FlareSolverr#installation) (`pip install -r requirements.txt` + `python src/flaresolverr.py`).

#### Alternativas (más frágiles en ARM/proot)

| Opción | Notas |
|--------|--------|
| **Docker CE dentro de proot** | Posible en algunos dispositivos; mucho disco/RAM; no soportado por scripts del repo. |
| **Imagen Docker solo FlareSolverr** | Misma pila que en PC, pero dentro de proot — doble capa, más OOM. |
| **npm start** | **Obsoleto** — upstream migró a Python; no uses `package.json` / `npm start`. |

Si Chromium no arranca en proot (sandbox): prueba flags/documentación FlareSolverr para `--no-sandbox` vía env `BROWSER_ARGS` (último recurso; menos seguro).

---

### Prowlarr: proxy FlareSolverr e indexers

1. **Settings** → **Indexer Proxies** → **+** → **FlareSolverr**
   - **Host:** `http://127.0.0.1:8191`
   - **Tags:** `flaresolverr`
2. En cada indexer Torznab que falle con Cloudflare (p. ej. **1337x**, **YTS**, **TorrentGalaxy** si aplica): editar → **Tags** → añadir `flaresolverr` (mismo tag que el proxy).
3. **Test** indexer tras tener FlareSolverr en marcha.

Orden de arranque práctico: `media-stack start` → FlareSolverr → pruebas en Prowlarr.

---

## Presupuesto RAM (`mode media`, sin LLM)

Contexto del RMX3311: **~7,1 GiB** `MemTotal`, ColorOS + swap ~7,5 GiB ([phone-tuning.md](phone-tuning.md)). Con Termux en reposo y debloat aplicado suele quedar **~3,3–3,8 GiB** `MemAvailable` **antes** de levantar la pila.

### Tabla orientativa (RSS por proceso, no medido en este dispositivo aún)

| Componente | Idle / típico | Pico / búsqueda o descarga | Dónde |
|------------|---------------|----------------------------|--------|
| Android + ColorOS (base) | ~2,5–3,5 GiB del total | — | — |
| Termux + runit (sshd, Tailscale app aparte) | ~150–250 MiB | — | Termux |
| **Jellyfin** (`mode media`) | ~200–400 MiB | +CPU si transcode (evitar) | Termux |
| **qBittorrent-nox** | ~150–300 MiB | ~400–800 MiB con muchos peers | Termux |
| **Radarr** | ~150–350 MiB | ~400–600 MiB import/scan | proot |
| **Sonarr** | ~150–350 MiB | ~400–600 MiB | proot |
| **Prowlarr** | ~150–300 MiB | ~300–500 MiB búsqueda manual | proot |
| Chroot **proot** (Ubuntu, sin contenedor) | ~80–200 MiB overhead | — | proot |
| **FlareSolverr** (Chromium) | ~300–500 MiB idle | **~800 MiB–1,5 GiB** por desafío; fugas suben con el tiempo | proot (**objetivo actual**) |
| **Jackett** (solo si lo añades) | ~150–250 MiB | ~200–350 MiB | proot / PC |

Fuentes comunidad: FlareSolverr ~310 MiB idle en Docker, **>1 GiB** tras uso prolongado ([FlareSolverr#1387](https://github.com/FlareSolverr/FlareSolverr/issues/1387)); Jackett ~150–300 MiB ([Jackett#9359](https://github.com/Jackett/Jackett/issues/9359)).

### Escenarios sumados (orden de magnitud)

| Escenario | Suma servicios media (aprox.) | `MemAvailable` esperado* | Notas |
|-----------|------------------------------|---------------------------|--------|
| **A — Baseline** (Jellyfin + qBit + *Arr*) | **~1,0–1,8 GiB** | **~1,5–2,5 GiB** | Sin FlareSolverr ni Torrentio extra |
| **B — Objetivo actual** A + **Torrentio** + **FlareSolverr en proot** | **~1,5–3,3 GiB** (+ picos CF) | **~0,5–1,5 GiB** | **Aceptado** por política «todo en el teléfono»; vigilar OOM |
| **C — + Jackett local en proot** | +**~0,2–0,35 GiB** | peor que B | Redundante con Prowlarr; solo futuro si hace falta |
| **D — Híbrido (futuro)** Prowlarr móvil + **Jackett + FlareSolverr en PC** Tailscale | móvil ≈ A | como A | § [Ampliaciones futuras](#ampliaciones-futuras-cuando-haga-falta) |
| **E — Solo Torrentio** (sin FlareSolverr) | como A | **~1,5–2,5 GiB** | Menos indexers Torznab con CF; más estable |

\*Partiendo de ~3,5 GiB libres antes de `media-stack start`; bajo presión → swap en flash, **signal 9**.

**Cuándo plantear migrar FlareSolverr al PC (futuro):** `MemAvailable` &lt; ~1 GiB de forma repetida, FlareSolverr/zombie Chromium tras búsquedas, Termux **signal 9** con pila idle — checklist en § [Ampliaciones futuras](#ampliaciones-futuras-cuando-haga-falta).

---

## Ampliaciones futuras (cuando haga falta)

Marca **futuro** — no forman parte del objetivo «todo en el móvil» salvo que vuelvas a necesitar más indexers o estabilidad.

### Checklist: PC con Docker (Jackett + FlareSolverr)

- [ ] En el **PC** (Docker Compose): **FlareSolverr** `:8191` + **Jackett** `:9117`; en Jackett, URL FlareSolverr ([Jackett README — FlareSolverr](https://github.com/Jackett/Jackett#configuring-flaresolverr)).
- [ ] Activar indexers **MejorTorrent** / **DonTorrent** (dominios espejo cambian; test en Jackett).
- [ ] **Prowlarr móvil** → **Indexers** → **Torznab** → URL tailnet, p. ej. `http://100.x.y.z:9117/api/v2.0/indexers/mejortorrent/results/torznab/…` + API key Jackett.
- [ ] **Apps** Prowlarr siguen en `127.0.0.1` hacia Radarr/Sonarr del teléfono.
- [ ] Apagar **FlareSolverr local** en proot para recuperar RAM.

### MejorTorrent / DonTorrent (referencia)

| Sitio | Prowlarr nativo | Jackett | Cloudflare |
|-------|-----------------|---------|------------|
| **MejorTorrent** | **No** ([Prowlarr#29](https://github.com/Prowlarr/Prowlarr/issues/29)) | **Sí** | A menudo sí ([Jackett#9339](https://github.com/Jackett/Jackett/issues/9339)) |
| **DonTorrent** | PR upstream ([Prowlarr#2601](https://github.com/Prowlarr/Prowlarr/pull/2601)) | **Sí** | Variable |

**Sonarr + DonTorrent:** episodios a veces solo en ficha de serie — automatización de temporadas completas puede fallar; películas y packs suelen ir mejor ([Prowlarr/Indexers#538](https://github.com/Prowlarr/Indexers/pull/538)). Torrentio mitiga en parte vía agregador, no igual que Jackett.

### Escenario D — híbrido recomendado si el móvil sufoca

1. Mantener **Prowlarr + *Arr* + qBit + Jellyfin** en el GT2.
2. **Jackett + FlareSolverr solo en PC** (Tailscale).
3. Opcional: **seguir con Torrentio** en Prowlarr para ES/debrid sin tocar el PC.

### Síntomas para migrar FlareSolverr off-phone

- OOM / **signal 9** con `mode media` y sin descarga activa.
- Búsquedas Prowlarr timeout masivos en indexers con tag `flaresolverr`.
- `MemAvailable` crónico &lt; 1 GiB tras reiniciar FlareSolverr.
- Calentamiento/swap constante con Chromium en proot.

---

## Referencia rápida Torrentio

| | **Torrentio (Prowlarr custom)** | **Pila *Arr* en el teléfono** |
|---|--------------------------------|-------------------------------|
| **Uso principal** | Agregador HTTP (+ debrid opcional) | Radarr/Sonarr + qBit → `Movies`/`TV` → Jellyfin |
| **Stremio** | Addon en app Android aparte; no integra Jellyfin Termux | — |
| **¿Reemplaza qBit?** | No para flujo local clásico; con debrid cambia el cliente efectivo | — |

---

## Criterios para **abortar** el experimento

Desinstala la automatización si ocurre de forma repetida:

- Termux cierra con **signal 9** durante descarga + *Arr* + FlareSolverr activos.
- `MemAvailable` &lt; ~1 GiB con solo media ( `mode status` ) **y** no quieres pasar al híbrido PC.
- Importaciones fallan por rutas (Remote Path Mapping) y no merece la pena depurar proot.
- El teléfono se calienta mucho enchufado 24/7 con qBit + escaneos.

Rollback rápido:

```bash
media-stack stop
bash ~/storage/shared/Download/llm-setup/uninstall-media-arr-stack.sh
```

Conservas `~/storage/shared/Movies` y `TV`; Jellyfin sigue sirviendo archivos ya descargados.

---

## Alternativa si falla proot

- **Solo qBit en Termux** + añadir torrents a mano → misma carpeta `Downloads/torrents` y mover a `Movies`/`TV`.
- **PC como *Arr*** + Syncthing al móvil (diseño previo) — sin cambiar dónde vive la biblioteca.

---

## Referencias

- [jellyfin-media.md](jellyfin-media.md) · [phone-tuning.md](phone-tuning.md) (RAM, `mode media`) · [service-modes-design.md](service-modes-design.md) · [second-life-ecosystem.md](second-life-ecosystem.md) §3  
- Scripts: `scripts/termux/install-media-arr-stack.sh`, `media-arr/install-inside-ubuntu.sh`, `media-stack`, `uninstall-media-arr-stack.sh`  
- Indexers custom: [dreulavelle/Prowlarr-Indexers](https://github.com/dreulavelle/Prowlarr-Indexers) · configure: [torrentio.stremio.ru](https://torrentio.stremio.ru/configure)
