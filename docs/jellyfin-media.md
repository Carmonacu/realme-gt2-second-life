# Jellyfin — media de prueba legal (RMX3311)

**Contexto:** Jellyfin en Termux (`mode media`, puerto **8096**). Solo usar contenido **libre** para pruebas; no subir material con copyright sin permiso.

## Ruta de biblioteca en el teléfono

En Termux, la carpeta expuesta a la galería Android es:

| Vista | Ruta |
|-------|------|
| Termux | `~/storage/shared/Movies` |
| Series (opcional) | `~/storage/shared/TV` |
| Absoluta (Jellyfin / adb) | `/data/data/com.termux/files/home/storage/shared/Movies` |

Requiere `termux-setup-storage` hecho una vez. **Direct Play** en clientes modernos (H.264/AAC); evita transcodificar en el SD888 con 8 GB RAM — ver [phone-tuning.md](phone-tuning.md) y [service-modes-design.md](service-modes-design.md).

## Descargar en el teléfono (SSH)

Desde el PC (forward **8022**, clave `~/.ssh/realme_gt2_termux`):

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1
```

En Termux:

```bash
export PATH=$HOME/bin:$PREFIX/bin:$PATH
mkdir -p ~/storage/shared/Movies
cd ~/storage/shared/Movies

# Big Buck Bunny 320p — Blender (dominio público)
# El .mp4 suelto en blender.org devuelve 404; usar el ZIP oficial:
curl -L --retry 3 -o BigBuckBunny_320x180.mp4.zip \
  https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4.zip
unzip -o BigBuckBunny_320x180.mp4.zip && rm BigBuckBunny_320x180.mp4.zip

# Sintel (trailer 1080p) — Blender Open Movie
curl -L --retry 3 -o sintel_trailer-1080p.mp4 \
  https://download.blender.org/durian/trailer/sintel_trailer-1080p.mp4

ls -lh BigBuckBunny_320x180.mp4 sintel_trailer-1080p.mp4
```

Si `curl` falla: `pkg install curl` o `aria2c -x 4 -o … <url>`. Comprobar tamaño (> 1 MiB) o `ffprobe` si tienes `pkg install ffmpeg`.

## Alternativa: copiar desde el PC (`adb push`)

Útil si la red del teléfono es lenta:

```powershell
adb -s YOUR_ADB_SERIAL push .\BigBuckBunny_320x180.mp4 /sdcard/Movies/
adb -s YOUR_ADB_SERIAL push .\sintel_trailer-1080p.mp4 /sdcard/Movies/
```

En Android, `/sdcard/Movies` es la misma carpeta que `~/storage/shared/Movies` tras el enlace Termux.

## Uso real (biblioteca grande)

Biblioteca **en el teléfono** (~50–60 GB): películas en `Movies`, series en `TV`. Opciones:

- **Automatización en el móvil (experimento):** qBit + Radarr/Sonarr/Prowlarr — [media-stack-phone.md](media-stack-phone.md) (objetivo: Torrentio + FlareSolverr en proot; híbrido PC en § futuro).
- **Solo copia desde PC:** Syncthing o `adb push` hacia esas carpetas.

No mezclar transcodificación Jellyfin con `mode llm`.

## Asistente Jellyfin (pendiente en dispositivo)

1. `mode media` (si no está activo).
2. Navegador: `http://<tailscale-ip>:8096/web/` (ej. Tailscale del teléfono).
3. Crear usuario admin → **Bibliotecas** → **Añadir biblioteca** → tipo **Películas** → carpeta  
   `/data/data/com.termux/files/home/storage/shared/Movies` → guardar.
4. Escanear biblioteca → abrir título → **Reproducir**. En el reproductor web, preferir **Direct Play** / desactivar transcodificación forzada si el cliente lo soporta.

Guía de modos: [termux-llm-guide.md § Jellyfin](termux-llm-guide.md#jellyfin-mode-media).
