# Segunda vida del Realme GT 2 (RMX3311) — ecosistema comunitario y viabilidad

**Investigación:** 2026-10-31  
**Contexto del dispositivo:** ColorOS 15 / Android 15, bootloader **bloqueado**, Deep Testing **no soportado**, 8 GB RAM, ~84 GB útiles, uso principal **LLM local** (~7,6 GiB modelos + ~3,1 GiB libres con SmolLM3 cargado).  
**Este repo:** Plan A (NetHunter con unlock) **pausado**; Plan B (Termux + Kali rootless + llama.cpp + SSH + Tailscale) **operativo** — ver [STATUS.md](STATUS.md).

---

## 1. Panorama: qué hace la comunidad con teléfonos “viejos” o bloqueados

### 1.1 Realme GT 2 / RMX3311 / codename `porsche`

| Esfuerzo | Enlace | Fecha / estado (fuente) | Relevancia para RMX3311 EU |
|----------|--------|-------------------------|----------------------------|
| Unlock EU vía Deep Testing + script histórico | [XDA — Unlock BL RMX3311 GDPR](https://xdaforums.com/t/unlock-bl-on-realme-gt2-rmx3311-gdpr.4585749/) | Hilo marcado **«NOT WORK ANYMORE»** (autor, ~2024) | No viable en A15 stock |
| Prueba de método Stano36 | [XDA — Unlock RMX3311 test](https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/) | Última actividad ~oct 2024 — **fallo** en fastboot | Misma conclusión que [unlock-research.md](unlock-research.md) |
| Rollback sin paquete oficial EU | [XDA — Rollback RMX3311](https://xdaforums.com/t/rollback-rmx3311.4622841/) | Editado mar 2025 | Riesgo alto; conflicto con regla «no CN/IN» del repo |
| ROM custom **porsche** (requiere BL desbloqueado) | [LineageOS unofficial — pjgowtham](https://github.com/pjgowtham/android_device_realme_porsche/releases) | Builds hasta **sep 2025** (Lineage 23) | **No aplica** a EU bloqueada; útil si algún día desbloqueas |
| Árbol dispositivo AOSPA | [android_device_realme_porsche](https://github.com/AOSPA/android_device_realme_porsche) | Device tree 2023+ | Referencia de hardware, no atajo de unlock |
| Kernel opensource Realme (Android S) | [realme_GT_GT2-AndroidS-kernel-source](https://github.com/realme-kernel-opensource/realme_GT_GT2-AndroidS-kernel-source) | Último push **jun 2022** | Base teórica del port NetHunter del repo |
| Colección OTA | [XDA — Collection of OTA packages](https://xdaforums.com/t/collection-of-ota-packages.4542941/) | Viva en 2026 | Paralelo a hunt OTA en [device-record.md](device-record.md) |

**RMX3312 (India)** tiene guías PixelOS/unlock que **no** trasladan al **RMX3311 EU** — ver [alternative-devices.md](alternative-devices.md) y [unlock-research.md](unlock-research.md).

### 1.2 Debloat ColorOS / Realme sin root

| Fuente | Enlace | Notas |
|--------|--------|-------|
| Guía XDA genérica `pm disable-user` | [Disable bloatware without root](https://www.xda-developers.com/disable-system-app-bloatware-android/) | Método que usa este repo (`--user 0`) |
| Tutorial XDA Realme (Master, adaptable) | [ADB debloating guide](https://xdaforums.com/t/adb-no-root-debloating-our-phone-guide-tutorial.4414751/) | Lista Heytap/ColorOS; **revisar** paquetes antes de copiar |
| Gist BBK/Realme/OPPO | [apfelchips debloat gist](https://gist.github.com/apfelchips/c7abd73141e2b199219381607aa94e36) | Advertencias (`com.coloros.weather.service` y dark mode) |
| Smartprix (Realme) | [How to remove bloatware](https://www.smartprix.com/bytes/how-to-remove-bloatware-from-realme-xiaomi-and-samsung-phones/) | Lista conservadora de apps Realme |
| Reddit GT 7 Pro (patrón OPlus) | [Realme GT 7 Pro removing bloatware](https://www.reddit.com/r/Realme/comments/1iv4ne8/realme_gt_7_pro_removing_bloatware/) | **No desactivar** `com.oplus.atlas`, `athena`, etc. (bootloop) |

**Este repo:** [phone-tuning.md](phone-tuning.md) — **20 apps** desactivadas (reversible), snapshot y `undo-disable.ps1`.

### 1.3 Teléfono Android como mini-servidor (Termux, sin root)

Patrón recurrente en 2024–2026:

| Pieza | Fuentes | Comentario |
|-------|---------|------------|
| SSH + desarrollo ligero | [Termux Wiki — Remote Access](https://wiki.termux.com/wiki/Remote_Access), [Corey Goldberg — SSH](https://coreygoldberg.com/posts/android-ssh-server/) | Puerto **8022**; ya implementado aquí |
| Tailscale en el teléfono | [XDA — old phone Linux server](https://www.xda-developers.com/old-android-phone-linux-server-handles-more-expected/) (2026) | Evita abrir puertos en el router |
| Jellyfin servidor | [r/termux — jellyfin en repo nativo](https://www.reddit.com/r/termux/comments/1qp1m40/since_when_is_it_possible_to_make_a_jellyfin/) (~ene 2026), [blog Ankan Talukdar](https://blog.ankantalukdar.com/how-i-installed-jellyfin-server-on-an-unrooted-android-phone-with-auto-restart/) (sep 2026) | `pkg install jellyfin-server` en **aarch64** |
| Syncthing | [Syncthing en Termux](https://ameyama.com/wiki/4c46c478/), [How-To Geek — Galaxy pocket server](https://www.howtogeek.com/old-galaxy-phone-into-a-pocket-linux-server-with-termux/) | Sustituto de apps Android dudosas |
| Home lab genérico | [Hashnode — Web server + SSH](https://hashcodehub.hashnode.dev/android-phone-as-a-web-server-ssh-home-lab) | tmux, Python http.server, Termux:Boot |
| XDA — servidor + Jellyfin + Papra | [Smart home gadget article](https://www.xda-developers.com/turned-old-phone-device-does-something-300-smart-home-gadgets-cant/) | **Direct Play** sí; transcodificar **no** |
| LLM en Termux | [llama.cpp — docs/android.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md), paquete [termux-packages llama-cpp](https://github.com/termux/termux-packages/blob/master/packages/llama-cpp/build.sh) | Este repo va **más lejos** (benchmarks, scripts, API remota) |
| Minecraft **Java** en Termux (`openjdk-*`, sin proot) | [JAVA_SERVER.md (BedrockServerTermux)](https://github.com/debojitsantra/BedrockServerTermux/blob/main/JAVA_SERVER.md), [mcserver-termux](https://github.com/IckyVickyUwU/mcserver-termux) | JVM nativa en **aarch64**; Geyser opcional para clientes Bedrock |
| Minecraft **Bedrock** BDS (proot + Box64) | [BedrockServerTermux](https://github.com/debojitsantra/BedrockServerTermux), [Bedrux](https://github.com/theonuverse/bedrux) | Traducción x86→ARM; más CPU/RAM que Java en el mismo hardware |
| Kali rootless | [NetHunter Rootless — Kali.org](https://www.kali.org/docs/nethunter/nethunter-rootless/) (página **2025-Jun-11**) | Documentado y verificado en [rootless-kali.md](rootless-kali.md) |
| Node-RED + MQTT | [Node-RED on Android](https://nodered.org/docs/getting-started/android), [Mosquitto on Android](https://highvoltages.co/iot-internet-of-things/mqtt-broker-on-android/) | Ligero; requiere Termux:Boot para fiabilidad |
| «Docker» sin root | [Termux-Udocker / George-Seven](https://github.com/George-Seven/Termux-Udocker/), manual [udocker](https://github.com/indigo-dc/udocker/blob/master/docs/user_manual.md) § Termux, playbook [android-docker-qemu](https://github.com/sulthonzh/android-docker-qemu/blob/main/PLAYBOOK.md) | **udocker** = imágenes OCI; **QEMU** = dockerd real pero lento |
| Cloudflare Tunnel | [Cloudflare connectivity docs](https://developers.cloudflare.com/cloudflare-one/networks/connectivity-options/), [igrek51 — Termux tunnel](https://igrek51.github.io/journal/termux-tunnel/) | Alternativa a exponer SSH/ADB sin Tailscale |
| WireGuard **dentro** de Termux | [newt issue — permission denied](https://github.com/fosrl/newt/issues/161) (oct 2025) | Crear interfaz **wg** requiere privilegios → **no** en stock |

---

## 2. Qué cubre **este** repositorio vs huecos

| Área | Cubierto aquí | Hueco / opcional |
|------|---------------|------------------|
| Unlock EU RMX3311 | [unlock-research.md](unlock-research.md), [STATUS.md](STATUS.md) | N/A hasta nueva evidencia |
| LLM local + latencia/RAM | [termux-llm-guide.md](termux-llm-guide.md), [benchmarks/rmx3311-llm.md](benchmarks/rmx3311-llm.md) | Vulkan/OpenCL: [documentado y probado — no viable en stock](benchmarks/rmx3311-llm-opencl-vulkan.md) (CPU b12017 preferido) |
| ColorOS / phantom procs / Doze | [phone-tuning.md](phone-tuning.md), [always-on-battery.md](always-on-battery.md), [termux-boot-services.md](termux-boot-services.md) | — |
| SSH + Tailscale + API remota LLM | [termux-llm-guide.md](termux-llm-guide.md), scripts `scripts/termux/` | Cloudflare Tunnel (si quieres acceso sin tailnet) |
| **Portal homepage (:8081)** | [portal-homepage.md](portal-homepage.md), `install-portal.sh` | Enlaces + `status.json` + guía modos/modelos |
| Kali rootless curado | [rootless-kali.md](rootless-kali.md) | Convivencia RAM: [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa) |
| Debloat reversible | [phone-tuning.md](phone-tuning.md) | Lista comunitaria GT2 EU específica (solo parcial) |
| NetHunter kernel / ROM | Fases 0–7, WSL | Bloqueado en dispositivo actual |
| Hardware alternativo | [alternative-devices.md](alternative-devices.md) | — |
| Media server / fotos / domótica | Matriz §3; mutex RAM: [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa) | Jellyfin operativo; *Arr*+qBit **experimento:** [media-stack-phone.md](media-stack-phone.md) (Torrentio + FlareSolverr en móvil; Jackett/PC § futuro) |
| **Minecraft servidor** (Java / Bedrock) | Matriz §3, §3.3 | **Operativo:** `mode gaming` — [minecraft-java.md](minecraft-java.md) |
| **Backlog ampliaciones** (ntfy, Gitea, gaming ligero, etc.) | **§4** (autónomas vs NAS/sync) | Solo documentación; sin scripts salvo lo ya operativo |
| Always-on 24/7 / batería | **[always-on-battery.md](always-on-battery.md)** + [phone-tuning.md § Carga 24/7 / § E](phone-tuning.md), [termux-boot-services.md](termux-boot-services.md) | — |

---

## 3. Matriz de viabilidad ( **este** teléfono, stock + Termux)

Leyenda: **Sí** = razonable sin root; **Parcial** = funciona con límites; **No** = root/unlock o inviable con RAM actual; **N/A** = no encaja con rol «caja LLM dedicada».

| Función | Stock + Termux | Root | Unlock BL | RAM / almacenamiento | Recomendación **para este RMX3311** |
|---------|----------------|------|-----------|----------------------|-------------------------------------|
| **LLM local (llama-server)** | **Sí** (operativo) | Opcional tuning | No | ~7,6 GiB modelos + pico carga; **no** correr Kali pesado a la vez | **Mantener como rol principal** |
| **SSH / SFTP (sshd)** | **Sí** | — | No | Despreciable | **Ya hecho**; SFTP = mismo servicio |
| **Tailscale (app Android)** | **Sí** | — | No | Bajo | **Preferido** frente a `tailscale` en Termux |
| **Kali rootless (nmap, msf sin DB)** | **Sí** | — | No | **~5,9 GiB** rootfs; conflicto con LLM | Usar **`kali --force` solo con LLM parado** |
| **Metasploit con PostgreSQL** | Parcial | Root/chroot especial | — | RAM + DB | **No** en rootless (oficial) |
| **Docker daemon real** | **No** | Sí + kernel | A menudo sí | — | **No intentar** en stock |
| **udocker (imágenes OCI)** | Parcial | — | No | RAM por contenedor | Solo experimentos **con LLM apagado**; sin aislamiento real |
| **QEMU + Docker dentro** | Parcial | — | No | 1+ GiB solo VM | **No** con 8 GB y LLM |
| **Jellyfin server (pkg nativo)** | Parcial | — | No | RAM + CPU transcode | **No concurrente** con LLM; Direct Play OK en SD888 si biblioteca en SD/USB |
| **Plex server** | Parcial | — | No | Similar | Peor encaje que Jellyfin en Termux |
| **mpv / Kodi** | Cliente **Sí**; servidor N/A | — | No | — | Cliente en el propio teléfono; no añade valor al rol servidor |
| **Syncthing (Termux)** | **Sí** | — | No | Bajo-medio | **Buena** opción backup **desde** el teléfono si espacio en PC/NAS |
| **Immich **servidor**** | **No** | — | — | Postgres + Redis + GB | **No** en el teléfono |
| **Immich / PhotoSync → NAS** | App Android **Sí** | — | No | Subida desde cliente | **Sí** hacia otro host; el teléfono no aloja Immich |
| **Desinstalar / desactivar Google Photos** | **Sí** (`pm disable-user`) | — | No | Libera UI, no mucho disco | Opcional; conservar si usas backup Google |
| **Samba en proot** | Parcial | — | No | proot lento | Mejor **SFTP/ Syncthing** |
| **WebDAV / nginx estático** | **Sí** | — | No | Bajo | OK para notas/archivos; **portal :8081** ([portal-homepage.md](portal-homepage.md)) |
| **Node-RED + Mosquitto** | **Sí** | — | No | ~100–300 MiB | Solo si **apagas LLM** o usas otro dispositivo |
| **Home Assistant completo** | Parcial | — | No | Pesado | Mejor en Raspberry/NAS; udocker HA posible pero **no** con LLM |
| **Cloudflare Tunnel** | **Sí** (`pkg install cloudflared`) | — | No | Bajo | Solo si necesitas exponer servicios **fuera** de Tailscale |
| **WireGuard en Termux** | **No** | Sí (VPN slot) | — | — | Usar **app WireGuard** o **Tailscale** (ya activo) |
| **AdAway / bloqueo DNS sistema** | **No** | **Sí** (Magisk) | Unlock típico | — | En stock: DNS privado en Ajustes o Pi-hole en red |
| **Monitor Wi‑Fi / injection** | **No** | — | **Sí** (kernel NH) | — | [alternative-devices.md](alternative-devices.md) |
| **Custom ROM Lineage/AOSPA** | **No** | — | **Sí** | Wipe | Bloqueado en RMX3311 EU actual |
| **Always-on 24/7 enchufado** | Parcial | — | No | **Degradación batería** | Viable con [always-on-battery.md](always-on-battery.md): carga controlada, wake-lock, sin modo ahorro; vigilar hinchazón |
| **Magisk / módulos kernel** | **No** | **Sí** | **Sí** | — | Fuera de alcance Plan B |
| **Minecraft Java** (Paper/Purpur + OpenJDK en Termux) | **Parcial** | — | No | ~2–3 GiB heap + margen OS; **no** con LLM | **Futuro / modo alternativo:** 2–4 jugadores en tailnet (Tailscale); `-Xmx2G`–`-Xmx3G`; `termux-wake-lock`; puerto **25565** |
| **Minecraft Bedrock** (BDS en proot + Box64) | Parcial | — | No | Emulación + RAM; peor que Java en SD888 | Solo si los clientes son **solo** PE; preferir Java + **Geyser** en el mismo teléfono |

### 3.1 Convivencia LLM + Kali + «servidor» — *Mantener el rol principal*

Política operativa detallada (tablas do/don't, flujos `pkill` / `kali`): **[phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa)**. Always-on enchufado: **[always-on-battery.md](always-on-battery.md)**.

Orden de prioridad recomendado en **8 GB**:

1. **Un solo servicio pesado de CPU/RAM** a la vez: `llama-server` **o** transcodificación Jellyfin **o** Metasploit masivo **o** JVM de Minecraft (modo `gaming` futuro).
2. Servicios ligeros en paralelo: **sshd**, **Tailscale**, **mosquitto** pequeño, **syncthing** (sync incremental).
3. **Kali**: escaneos con `termux-wake-lock`; evitar `seclists` completos + LLM simultáneo (ya notado en [rootless-kali.md](rootless-kali.md)).
4. **Rol principal del repo:** LLM local; pentest y media server son **modos alternativos**, no concurrentes con el pesado activo.

### 3.2 Almacenamiento (~84 GB útiles, ~14 GiB ya en Termux)

| Escenario | Espacio aprox. | ¿Cabe? |
|-----------|----------------|--------|
| Estado actual (modelos + Kali) | ~14 GiB en `~/` | Sí |
| + biblioteca Jellyfin 50 GiB | +50 GiB | **Apretado** — requeriría SD o reducir modelos |
| + Immich server | +varios GiB DB | **No recomendado** |
| + mundo Minecraft Java (Paper + backups) | +1–3 GiB | **Sí** con LLM apagado; no convive con modelos cargados en RAM |

---

### 3.3 Minecraft en el RMX3311 — valoración

**Implementado (2026-11-03):** `mode gaming` + `mc-server` (Paper, Java 25, runit) — guía **[minecraft-java.md](minecraft-java.md)**. Servidor vacío: «Done» en ~12–16 s, 20 TPS, ~1,4–1,6 GB RSS.

**Veredicto:** **Sí como ampliación opcional**, alineada con Plan B (Termux sin root), **no** como rol principal del repo ni concurrente con el LLM.

| Aspecto | Java Edition en Termux | Bedrock BDS (Box64) |
|---------|------------------------|---------------------|
| Encaje técnico | **Bueno:** OpenJDK en Termux corre nativo en **aarch64** (Snapdragon 888) | **Regular:** servidor oficial es x86_64; Box64 en proot añade CPU y RAM |
| RAM útil (8 GB totales) | Con LLM **parado**, ~5–6 GiB libres → heap **2–3 GiB** razonable para vanilla/Paper pequeño | Comunidad cita 2–5 jugadores en 4–8 GB **sin** otros servicios pesados |
| Jugadores realistas | **2–4** en LAN/tailnet, view distance moderada; no esperar servidor público masivo | Similar o peor por emulación |
| Red | **Tailscale** (ya en uso) evita abrir **25565** en el router; mismo patrón que SSH/API LLM | **19132** UDP; Geyser añade **19132** si Java + puente Bedrock |
| Termal / ColorOS | Carga sostenida CPU → throttle; enchufado + [always-on-battery.md](always-on-battery.md); riesgo de kill como en Kali → wake-lock y modo dedicado | Igual o peor |
| Almacenamiento | JAR + mundo + logs ~1–3 GiB | Similar + Debian proot si no se reutiliza el de Kali |

**Recomendación de diseño (ya aplicada):** **`mode gaming`** ([service-modes-design.md](service-modes-design.md)): `pkill llama-server`, `termux-wake-lock`, arrancar Paper con flags acotados, opcional unidad runit bajo demanda. **Paper** o **Purpur** mejor que vanilla en CPU móvil. Clientes Bedrock: **Geyser** sobre el servidor Java, no BDS+Box64 salvo requisito estricto.

**No objetivos:** hosting público 24/7 de muchos jugadores, modpacks pesados, servidor MC **con** SmolLM3 u otro modelo cargado a la vez.

---

## 4. Backlog de ampliaciones futuras (solo documentación)

**Estado:** ideas recopiladas **2026-11-03**; ninguna implica implementación en el repo salvo lo ya operativo (LLM, SSH, portal, Kali, modos v1).  
**Criterio de separación:** §4.1 = viable pensando solo en **teléfono + Termux + tailnet/LAN**; §4.2 = **requiere NAS, PC always-on, nube u otro nodo** como contraparte de sync, biblioteca o backup (Syncthing/rclone/Restic/apps de subida).

Leyenda de viabilidad: **Sí** / **Parcial** / **No** (misma semántica que §3). **Mutex LLM:** **Sí** = servicio pesado, un solo heavy a la vez; **No** = ligero en paralelo; **Parcial** = según RAM.

### 4.1 Autónomas (sin depender de NAS ni sync remota)

| Idea | Viabilidad | Modo / capa | Mutex LLM | Notas |
|------|------------|-------------|-----------|-------|
| **ntfy** / **Gotify** | **Sí** | `light-stack` o paralelo | No | Push por hooks en `mode`, fallos OOM, fin de backup local |
| **Uptime Kuma** / **Healthchecks** (self-hosted) | **Sí** | `light-stack` | No | Monitorizar sshd, llama-server, portal `:8081` vía tailnet |
| **FreshRSS** / **Tiny Tiny RSS** | **Sí** | `light-stack` | No | SQLite/Postgres pequeño; pocos feeds |
| **Linkding** | **Sí** | `light-stack` | No | Marcadores; SQLite |
| **Wallabag** | **Sí** | `light-stack` | No | Read-it-later; PHP/SQLite o Postgres pequeño |
| **Glances** / **Netdata** (agente ligero) | Parcial | `light-stack` | No | Métricas CPU/RAM del teléfono; Netdata más pesado |
| **Caddy** / **nginx** reverse proxy | **Sí** | infra | No | Unificar URLs tailnet (portal, API LLM, RSS…) |
| **Gitea** / **Forgejo** (minimal) | Parcial | `light-stack` / `lab` | Parcial | Repos **pequeños** en almacenamiento interno; no forge grande |
| **Open WebUI** (frontend) | Parcial | `llm` | No* | *Solo UI; apunta a `llama-server` existente, no segundo modelo |
| **Vaultwarden** | Parcial | `light-stack` | Parcial | Más ligero que Bitwarden oficial; evaluar RAM vs Mosquitto |
| **n8n** | Parcial | `lab` | **Sí** | Más pesado que Node-RED; automatizaciones puntuales |
| **AdGuard Home** / **Pi-hole** en Termux | Parcial | `light-stack` | No | Malo como DNS de **toda** la LAN; viable DNS filtrado **solo tailnet** o uso personal |
| **step-ca** (CA interna) | Parcial | `lab` | No | TLS interno para Caddy/proxy; experimental |
| **Tailscale Serve** / **Funnel** | **Sí** | app + Termux | No | Alternativa a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/) ya citado en §3 |
| **fail2ban** (sshd `:8022`) | **Sí** | sshd | No | Si hay intentos de fuerza bruta en tailnet expuesta |
| **App WireGuard** | **Sí** | Android | No | Peer que no use Tailscale; §3 ya descarta wg en Termux |
| **whisper.cpp** / **faster-whisper** | Parcial | `lab` / futuro `stt` | **Sí** | Transcripción batch; CPU SD888; LLM apagado |
| **Minetest** (servidor) | Parcial | `gaming` | **Sí** | Alternativa más ligera que Minecraft Java |
| **OpenTTD** dedicated | **Sí** | `gaming` | **Sí** | Muy bajo RAM; partidas tailnet |
| **Minecraft Java** (Paper/Geyser) | Parcial | `gaming` | **Sí** | Detalle en §3.3 |
| **Minecraft Bedrock** (BDS+Box64) | Parcial | `gaming` | **Sí** | Peor que Java+Geyser en aarch64 |
| **Navidrome** / **Audiobookshelf** (media **en el teléfono**) | Parcial | `media` | **Sí** | Solo biblioteca **pequeña** en `~/` o SD montada localmente |
| **Calibre-web** (ebooks **locales**) | Parcial | `media` | **Sí** | Pocos GB en almacenamiento interno |
| **Kali — auditoría LAN programada** | **Sí** | `pentest` | **Sí** | Informes en `~/storage/shared`; extiende [rootless-kali.md](rootless-kali.md) |
| **Tasker** / **MacroDroid** + **Termux API** | **Sí** | Android | No | Enchufado → `mode llm`; pérdida Wi‑Fi → ntfy |
| **Termux:Widget** | **Sí** | Android | No | Atajos `mode idle`, reinicio sshd |
| **KDE Connect** | **Sí** | app Android | No | Clipboard/archivos PC ↔ móvil |
| **Sensores → MQTT** (Termux API) | **Sí** | `light-stack` | No | Teléfono enchufado como beacon (batería, presencia) |
| **Modo `maintenance`** *(futuro)* | **Sí** | `maintenance` | **Sí** | Ventana: `pkg upgrade`, logs, backup **local** a `~/storage/shared` |
| **Cola de jobs** (`at` / cron + `flock`) | **Sí** | scripts | Parcial | Tareas nocturnas sin NAS |
| **Portal :8081 — más enlaces** | **Sí** | portal | No | ntfy, Gitea, RSS en `index.html` / `status.json` |
| **Embeddings locales** (modelo tiny, p. ej. nomic) | Parcial | `llm` / turnos | **Sí** | RAG alternando con chat pesado; no dos modelos grandes |
| **Node-RED + Mosquitto** | **Sí** | `light-stack` | Parcial | Ya en matriz §3 y [service-modes-design.md](service-modes-design.md) |
| **Cloudflare Tunnel** | **Sí** | infra | No | Ya en matriz §3 |
| **msmtp** + relay (alertas correo) | **Sí** | scripts | No | Alternativa/complemento a ntfy; cuenta SMTP externa |
| **dnsmasq** (solo lab / tailnet) | Parcial | `lab` | No | DNS local de prueba; no sustituto de Pi-hole en LAN |

### 4.2 Dependientes de NAS, sincronización u otro host

Requieren **contraparte** (NAS, PC, bucket S3, Immich en otro servidor, etc.) o **flujo de réplica** continuo. Sin ese segundo nodo, la idea queda incompleta o solo tiene sentido como **destino** de datos que salen del teléfono.

| Idea | Viabilidad | Modo / capa | Mutex LLM | Dependencia |
|------|------------|-------------|-----------|-------------|
| **Syncthing** (Termux ↔ NAS/PC) | **Sí** | `light-stack` | No | Peer remoto; ya en matriz §3 |
| **rclone** (sync/backup programado) | **Sí** | `maintenance` | Parcial | Destino: NAS, S3, Drive, WebDAV remoto |
| **Restic** / **Borg** → NAS | **Sí** | `maintenance` | **Sí** | Repositorio en otro host; snapshot `~/` Termux |
| **Immich** (cliente Android → servidor **externo**) | **Sí** | app | No | Servidor Immich **no** en el teléfono; §3 |
| **PhotoSync** / **FolderSync** | **Sí** | app | No | Fotos/carpetas → NAS o PC |
| **Jellyfin** + biblioteca **grande en NAS** | Parcial | `media` | **Sí** | Media vía Syncthing/rclone o mount de red; Direct Play |
| **Navidrome** / **Audiobookshelf** + biblioteca **en NAS** | Parcial | `media` | **Sí** | Música/podcasts replicados o leídos desde share remoto |
| **Calibre-web** + biblioteca **en NAS** | Parcial | `media` | **Sí** | Ebooks sincronizados desde otro nodo |
| **Gitea** mirror / backup **hacia NAS** | Parcial | `maintenance` | Parcial | Repo canónico en teléfono + `git push` mirror o Restic |
| **Modelos LLM «fríos»** en NAS/SD + sync bajo demanda | Parcial | `maintenance` / manual | Parcial | Liberar `~/`; pull antes de `mode llm` |
| **SD/USB como almacén media/modelos** | Parcial | `media` / manual | Parcial | No es NAS pero **sincronizas** desde PC; ver §3.2 Jellyfin 50 GiB |
| **Syncthing** backup **desde** teléfono (origen) | **Sí** | `light-stack` | No | Teléfono origen → NAS destino (matriz §3) |
| **Plex** + biblioteca remota | Parcial | `media` | **Sí** | Peor encaje que Jellyfin; misma dependencia de media externa |
| **Home Assistant completo** (udocker + integraciones) | Parcial | `lab` | **Sí** | Suele asumir NAS, cámaras, MQTT en red; §3 |

**Nota:** SD/USB montada en ColorOS puede **reducir** dependencia de NAS para media, pero sigue siendo política de **copia/sync** desde otro equipo para poblar la tarjeta; por eso bibliotecas grandes comparten fila con NAS en esta tabla.

---

## 5. Lecturas útiles al publicar el repo

Quien llegue con **RMX3311 EU bloqueado** debería leer en este orden:

1. [STATUS.md](STATUS.md) — qué funciona hoy  
2. [unlock-research.md](unlock-research.md) — por qué Plan A está pausado  
3. [termux-llm-guide.md](termux-llm-guide.md) + [rootless-kali.md](rootless-kali.md) — Plan B  
4. [always-on-battery.md](always-on-battery.md) + [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa) — 24/7 y un solo servicio pesado  
5. [termux-boot-services.md](termux-boot-services.md) — SSH (8022) tras reboot (Termux:Boot + runit)  
6. [alternative-devices.md](alternative-devices.md) — si necesita NetHunter «de verdad»  
7. [service-modes-design.md](service-modes-design.md) — perfiles `mode` y backlog de servicios  
8. [portal-homepage.md](portal-homepage.md) — una URL para servicios, modos y estado  
9. Este documento — matriz §3, Minecraft §3.3, backlog §4 (autónomas vs NAS/sync)  

---

## 6. Referencias cruzadas (fechas de consulta)

- XDA unlock / rollback: hilos citados en §1.1 (consulta **2026-10-31**).  
- Jellyfin en Termux repo nativo: comentario maintainer **~ene 2026** en [r/termux](https://www.reddit.com/r/termux/comments/1qp1m40/since_when_is_it_possible_to_make_a_jellyfin/).  
- XDA «Linux server on old Android»: artículo **2026** en [xda-developers.com](https://www.xda-developers.com/old-android-phone-linux-server-handles-more-expected/).  
- Docker/playbook Termux: [PLAYBOOK.md](https://github.com/sulthonzh/android-docker-qemu/blob/main/PLAYBOOK.md) en repositorio **android-docker-qemu** (acceso **2026-10-31**).  
- WireGuard rootless fallo: [fosrl/newt#161](https://github.com/fosrl/newt/issues/161) (**2025-10-10** en log del issue).  
- Backlog ampliaciones §4.1 / §4.2: recopilación interna (**2026-11-03**).
