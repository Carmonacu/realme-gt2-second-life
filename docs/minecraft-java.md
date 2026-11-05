# Servidor Minecraft Java (Paper) en el RMX3311

Servidor **Minecraft Java Edition** con **Paper** en Termux (sin root ni proot), supervisado por runit y controlado con **`mode gaming`** / **`mc-server`**. Probado en el teléfono el **2026-11-03**.

| | |
|---|---|
| Versión | **Paper 26.3 build 238** (STABLE) = Minecraft Java **26.3** (protocolo 777) |
| Java | **OpenJDK 25** (`pkg install openjdk-25`; Paper 26.x exige Java ≥ 25) |
| Directorio | `~/minecraft/paper` (mundo `world/`, `plugins/`, `logs/latest.log`) |
| Backups | `~/minecraft/backups/paper-AAAAMMDD-HHMMSS.tar.gz` (se conservan 5) |
| Config | `~/.config/gt2-minecraft/minecraft.conf` (plantilla [`minecraft.conf.example`](../scripts/termux/minecraft.conf.example)) |
| Puerto | **25565/TCP** (Java) · 19132/UDP solo con Geyser |
| Conectar | **`100.127.134.111:25565`** (IP Tailscale del teléfono) o `<IP-LAN>:25565` en la misma Wi-Fi |

## Uso rápido

```bash
mc-server install        # Java + Paper estable más reciente (sha256 verificado) + eula + runit
mode gaming              # para LLM/Jellyfin/qBittorrent, pantalla on, wake-lock, arranca y espera «Done»
mc-server status         # PID, RAM, versión, jugadores (server list ping)
mc-server op TuNick      # hacerte operador
mc-server cmd "tps"      # cualquier comando de consola (sin /) y su salida
mc-server console        # consola interactiva; Ctrl+D sale SIN parar el servidor
mc-server logs -f        # seguir logs/latest.log
mc-server backup         # copia en caliente (save-off → save-all flush → tar.gz → save-on)
mode media               # sale de gaming: «stop» limpio (guarda el mundo) y vuelve Jellyfin
```

En el cliente: **Multijugador → Añadir servidor → `100.127.134.111:25565`** (el PC/móvil del jugador tiene que estar en la tailnet). El cliente debe ser **la misma versión** (26.3); `online-mode=true` exige cuentas Java legítimas.

**EULA:** `mc-server install` escribe `eula=true` porque al instalar el servidor aceptas el [EULA de Minecraft](https://www.minecraft.net/eula) (Mojang). Si no lo aceptas, no lo instales.

## Cómo funciona

- **Descarga:** API oficial **PaperMC Fill v3** (`https://fill.papermc.io/v3/projects/paper`; la API v2 `api.papermc.io` está obsoleta). `MC_VERSION=auto` elige la versión más nueva con `support.status = SUPPORTED` y build en canal **STABLE**, sin `-rc`/`-pre`; comprueba el **sha256** que publica la API antes de usar el JAR (`paper.jar` → `paper-26.3-238.jar`). La misma API da la **Java mínima** (se instala `openjdk-<N>` con pkg si falta) y los **flags recomendados** (los de Aikar).
- **JVM:** `-Xms2560M -Xmx2560M` + flags de Aikar (G1GC, `MaxGCPauseMillis=200`, `G1NewSizePercent=30`, …) **sin `-XX:+AlwaysPreTouch`** (`MC_PRETOUCH=1` para activarlo): en un teléfono de 8 GB es mejor que el heap se reserve bajo demanda. `-Duser.timezone` se toma de Android (`getprop persist.sys.timezone`; si no, Java en Termux pone los logs en UTC).
- **server.properties** (solo si la clave no existe; tus cambios se respetan): `online-mode=true`, `view-distance=8`, `simulation-distance=6`, `max-players=8`, `sync-chunk-writes=false`, `enable-rcon=false`, `motd`.
- **Servicio runit `minecraft`** (`$PREFIX/var/service/minecraft`, normalmente con `down`): `run` → `mc-server _run`, que abre una **FIFO** `~/minecraft/paper/console.fifo` como stdin de Java (abierta lectura+escritura, nunca da EOF). Los comandos (`stop`, `save-all`, `tps`, …) se escriben en la FIFO y la salida se lee de `logs/latest.log`. Así no hace falta **RCON** (que en vanilla escucha en todas las interfaces).
- **Parada limpia:** `mc-server stop` hace `sv once` (que runit no lo reinicie), manda `stop` por la consola y espera a que Java salga (guarda todos los mundos; en la prueba, 1 s). Si en `MC_STOP_TIMEOUT` (120 s) no ha salido: SIGTERM (el hook de apagado de Minecraft también guarda) y por último SIGKILL.
- **`mode gaming`:** para LLM (`llama-server` y `llama-smol`), Jellyfin, qBittorrent/*Arr* (`media-stack stop`) y QEMU; comprueba térmica y **RAM ≥ 2,75 GiB** (`MODE_MIN_GAMING_KB`); enciende la pantalla (`gt2-screen on`, si `SCREEN_CONTROL=1`) — imprescindible porque con la pantalla apagada ColorOS limita `cpu4` a 1,44 GHz ([Pantalla y rendimiento](termux-llm-guide.md#pantalla-y-rendimiento)); `termux-wake-lock`; `mc-server start` (espera «Done»). Cualquier otro modo (`media`, `idle`, `llm`, `light-stack`, `pentest`, `lab`) para Minecraft limpio primero; con `MC_BACKUP_ON_STOP=1` hace backup antes; luego apaga la pantalla si `SCREEN_OFF_ON_EXIT=1` (`~/.llm.conf`).
- **Estado:** `mode status` añade la línea de Minecraft; el portal (:8081) muestra versión y jugadores (`status.json` → `services.minecraft`).

## Medidas (2026-11-03, servidor vacío, pantalla encendida, enchufado)

| | |
|---|---|
| `mc-server install` | 4,8 s (JAR 52,7 MB a ~41 MB/s; Java ya instalado) |
| Primer arranque (genera el mundo) | **Done (15,7 s)**; `mode gaming` completo 35,6 s (incluye parar Jellyfin) |
| Arranques siguientes | Done (11,7 s); `mc-server restart` 16,8 s |
| TPS (1m/5m/15m) | **20.0, 20.0, 20.0** |
| RAM | RSS Java **1,4–1,6 GB** (heap 2560M no se llena en vacío); MemAvailable del teléfono 3,17 → 2,52 GB; swap sin usar |
| CPU | ~30 % de un núcleo en reposo; `cpu4` a 2,42 GHz con la pantalla encendida |
| Backup en caliente | 1,8 s, 760 KB (mundo recién creado) |
| Parada (`stop`) | 1 s |

Avisos inofensivos en el log: `oshi`/`JNA` (*libc.so.6 not found*, *Did not find udev*) — son del informe de sistema de los crash reports; Android usa bionic y no glibc. No afectan al servidor.

**Pendiente:** probar con 2–4 jugadores reales por la tailnet (TPS y RAM bajo carga).

## Consejos de rendimiento

- **Pantalla encendida** (brillo mínimo) y **enchufado** con «Permanecer activo»; `mode gaming` la enciende sola.
- **Nada más pesado a la vez** (ni LLM ni Jellyfin transcodificando): `mode gaming` ya los para.
- Distancias: `view-distance=8`, `simulation-distance=6` son el punto de partida; con 4+ jugadores baja a 6/4. Paper: en `config/paper-world-defaults.yml` puedes limitar entidades/redstone si cae el TPS.
- **Pregenera** el mundo si vais a explorar mucho (plugin Chunky: `chunky radius 1000`, `chunky start`) con nadie conectado, para no generar chunks durante la partida.
- Heap: 2560M va sobrado para pocos jugadores; `MC_XMX=3G` solo si `MemAvailable` lo permite. Más heap no da más TPS.
- Mira `mc-server cmd tps` y `mc-server status` (RSS). Térmica: `thermal-guard` / `mode status`.

## Backups

```bash
mc-server backup                              # manual (en caliente)
echo 'MC_BACKUP_ON_STOP=1' >> ~/.config/gt2-minecraft/minecraft.conf   # al salir de gaming
ls -lh ~/minecraft/backups
# Restaurar: mode media; cd ~/minecraft/paper; mv world world.old; tar -xzf ~/minecraft/backups/paper-….tar.gz world
```

Incluye `world*`, `server.properties`, listas (`ops`, `whitelist`, `banned-*`), `bukkit.yml`, `spigot.yml`, `config/` y `plugins/` (sin los `.jar`). Para copias fuera del teléfono: Syncthing/rclone de `~/minecraft/backups`.

## Actualizar

```bash
mc-server backup && mc-server update          # último build STABLE (reinicia si estaba en marcha)
MC_VERSION=26.3 mc-server update              # fijar versión
```

Un cambio de **versión** de Minecraft convierte el mundo y no tiene vuelta atrás: backup antes. Los clientes deben actualizar a la misma versión.

## Jugadores Bedrock (Geyser + Floodgate) — opcional

No se instala por defecto. Para que móviles/consolas Bedrock entren al mismo servidor Java:

```bash
mc-server geyser install      # o: mc-server install --geyser · o MC_GEYSER=1 en minecraft.conf
mc-server restart
```

Descarga **Geyser-Spigot** y **Floodgate-Spigot** de la API oficial de GeyserMC (`download.geysermc.org/v2`, sha256 verificado) a `plugins/`. Bedrock conecta a **`<IP>:19132` (UDP)**. Floodgate permite cuentas Bedrock (Xbox) sin cuenta Java (nombres con prefijo `.`). Config: `plugins/Geyser-Spigot/config.yml`. Ojo: Geyser suele tardar unos días en soportar una versión nueva de Java; si al arrancar dice que no soporta 26.3, espera a una versión nueva (`mc-server geyser install` otra vez). Quitar: `mc-server geyser remove && mc-server restart`.

## Amigos sin Tailscale (fuera del alcance)

El servidor solo se publica en la tailnet y la LAN. Opciones, ninguna configurada aquí:
- **Invitarles a la tailnet** (Tailscale: compartir el nodo con su cuenta, *node sharing*) — lo más simple y seguro.
- **Túnel/relay TCP** (playit.gg, un VPS con frp/WireGuard) — expone el servidor a Internet: usa `white-list=true`.
- **Abrir 25565 en el router** — no recomendado (IP doméstica expuesta; el teléfono cambia de IP LAN).

## Problemas

| Síntoma | Causa / solución |
|---|---|
| `mode gaming`: «MemAvailable … < 2883584» | Algo pesado sigue en RAM; `mode status`, o baja `MC_XMX` / `MODE_MIN_GAMING_KB` |
| Lag / TPS < 20 con la pantalla apagada | ColorOS limita la CPU: `gt2-screen on` (ver guía de pantalla) |
| «java terminó durante el arranque» | `mc-server logs 80`; Java antigua → `mc-server install` instala la correcta |
| El cliente dice «Outdated server/client» | Versión distinta: actualiza el cliente o fija `MC_VERSION` |
| No conecta desde fuera | ¿El jugador está en la tailnet? `mc-server ping 100.127.134.111` desde el teléfono |
