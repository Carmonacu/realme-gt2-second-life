# Portal homepage (Termux, Plan B)

**Objetivo:** una sola URL con enlaces a servicios del teléfono, guía de modos/modelos y estado en vivo — sin memorizar puertos.

**Coste RAM:** ~**3–8 MiB** (nginx, 1 worker). El `index.html` no consume RAM en servidor (archivos estáticos). Comparable a servir solo HTML; no usar Flame/Homepage (Node) en 8 GB si el rol principal es LLM.

**Puerto por defecto:** **8081** (`PORTAL_PORT`).

---

## Instalación

1. Desde el PC (mismo flujo que el resto de scripts):

   ```powershell
   .\scripts\windows\push-termux-boot.ps1
   ```

2. En Termux (tras `install-boot-services.sh` si aún no lo hiciste):

   ```bash
   bash ~/storage/shared/Download/llm-setup/install-portal.sh
   ```

3. Abre en el navegador:
   - En el teléfono: **http://127.0.0.1:8081/**
   - Desde la tailnet (app **Tailscale ON** en el móvil): **http://100.x.y.z:8081/**

Opcional: dejar el servicio deshabilitado al instalar: `install-portal.sh --no-enable` → luego `rm $PREFIX/var/service/portal/down && sv up portal`.

---

## Archivos

| Ruta en teléfono | Origen repo |
|------------------|-------------|
| `~/var/www/portal/index.html` | [`scripts/termux/www/index.html`](../scripts/termux/www/index.html) |
| `~/var/www/portal/status.json` | Generado por `portal-status.sh` |
| `~/bin/portal-status.sh` | [`scripts/termux/portal-status.sh`](../scripts/termux/portal-status.sh) |
| `$PREFIX/var/service/portal/run` | [`scripts/termux/services/portal/run`](../scripts/termux/services/portal/run) |

---

## Estado en vivo (`status.json`)

Se regenera automáticamente:

- Tras cada **`mode llm|idle|media|…`** (hook en `mode-lib.sh`).
- Al arrancar el servicio **portal** (runit).
- Cada ~5 min desde **`thermal-guard`** y en cada cambio de **`charge-limiter`** (si están activos).

Manual:

```bash
bash ~/bin/portal-status.sh
```

Contenido: modo actual, `MemAvailable`, IP Tailscale (`100.x` si existe), procesos pesados y flags `running` / `health_ok` por servicio. **No** incluye la API key del LLM.

Desde v1.1 también: `llm.server_mode` (router/single), modelo cargado, `kv_cache` y `llm.metrics` (tok/s de generación y prompt calculados con los contadores acumulados de `/metrics`, aceptación del borrador si hay especulativa) + bloque `power` (batería, enchufe, estado térmico) leído de `~/.cache/gt2-power/`. Pills **Batería / Enchufe / LLM** en la cabecera.

La página refresca el JSON cada **30 s** en el navegador.

---

## Seguridad

- El portal escucha en **8081** en todas las interfaces (como Jellyfin por defecto). Contenido público de la tailnet; no expone secretos.
- **LLM** en modo remoto sigue requiriendo **Bearer** en `:8080`.
- Preferible acceder vía **Tailscale**, no abrir puertos en el router.

---

## Actualizar contenido

Tras cambiar HTML o scripts en el PC:

```powershell
.\scripts\windows\push-termux-boot.ps1
```

```bash
cp -f ~/storage/shared/Download/llm-setup/www/index.html ~/var/www/portal/
cp -f ~/storage/shared/Download/llm-setup/portal-status.sh ~/bin/
cp -f ~/storage/shared/Download/llm-setup/mode-lib.sh ~/bin/
chmod +x ~/bin/portal-status.sh
bash ~/bin/portal-status.sh
# si cambió run de nginx:
cp -f ~/storage/shared/Download/llm-setup/services/portal/run $PREFIX/var/service/portal/run
sv restart portal
```

---

## Relacionado

- Modos: [`service-modes-design.md`](service-modes-design.md)
- LLM y puertos: [`termux-llm-guide.md`](termux-llm-guide.md)
- Boot sshd: [`termux-boot-services.md`](termux-boot-services.md)
- Matriz de servicios: [`second-life-ecosystem.md`](second-life-ecosystem.md)
