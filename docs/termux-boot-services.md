# Termux:Boot + termux-services (Plan B, RMX3311)

**Objetivo:** que **OpenSSH** (`sshd`, puerto **8022**) vuelva tras reiniciar el teléfono **sin abrir Termux manualmente**. Opcionalmente, **llama-server** (SmolLM3) vía runit — **desactivado por defecto** (RAM pesada).

**Relacionado:** [phone-tuning.md](phone-tuning.md) (ColorOS / batería), [termux-llm-guide.md](termux-llm-guide.md) (SSH, LLM), scripts en [`scripts/termux/`](../scripts/termux/).

---

## Qué arranca al boot (por defecto)

| Componente | Por defecto | Mecanismo |
|------------|-------------|-----------|
| `termux-wake-lock` | **Sí** | Script `~/.termux/boot/start-services` |
| **runit** (`termux-services`) | **Sí** | `source $PREFIX/etc/profile.d/start-services.sh` |
| **`sshd` (8022)** | **Sí** | `sv-enable sshd` (instalador) |
| **`llama-smol` (8080)** | **No** | Solo con `install-boot-services.sh --enable-llama-smol` o `sv-enable llama-smol` |
| **Perfil `mode`** | **`idle`** | Tras runit, `start-services` ejecuta `mode apply ${TERMUX_DEFAULT_MODE:-idle}` |
| **Tailscale** | **No** | App Android (VPN); arranca si el sistema la relanza — no sustituido por este doc |

El auto-arranque antiguo en `~/.bashrc` (`ssh-setup.sh`) sigue siendo un **respaldo** al abrir Termux; con Termux:Boot + runit no dependes de una sesión interactiva.

---

## 1. Requisitos (F-Droid, misma firma)

1. **Termux** desde [F-Droid](https://f-droid.org/packages/com.termux/) (no mezclar con Play).
2. **Termux:Boot** — [F-Droid `com.termux.boot`](https://f-droid.org/packages/com.termux.boot/).
3. Abre **Termux:Boot una vez** desde el launcher (permiso de arranque).
4. **OpenSSH** ya configurado: [`ssh-setup.sh`](../scripts/termux/ssh-setup.sh) + `authorized_keys` en `llm-setup/`.
5. **ColorOS:** Termux y Termux:Boot **sin optimización de batería**, Termux bloqueado en recientes, lista blanca Doze (`com.termux`) — ver [phone-tuning.md](phone-tuning.md).

---

## 2. Instalación

### Desde el PC (adb)

```powershell
adb -s YOUR_ADB_SERIAL push "c:\Users\<you>\Desktop\Proyects\realme-gt2-second-life\scripts\termux\." /sdcard/Download/llm-setup/
# o helper:
.\scripts\windows\push-termux-boot.ps1
```

### En Termux

```bash
bash ~/storage/shared/Download/llm-setup/install-boot-services.sh
```

**Opt-in LLM al boot** (consume ~3 GiB RAM; no recomendado con Kali + escaneos):

```bash
bash ~/storage/shared/Download/llm-setup/install-boot-services.sh --enable-llama-smol
```

El instalador:

- `pkg install termux-services openssh`
- **Arranca runsvdir:** `. $PREFIX/etc/profile.d/start-services.sh` (breve espera) — necesario antes de `sv-enable` en instalaciones nuevas
- `sv-enable sshd`
- Copia [`boot/start-services`](../scripts/termux/boot/start-services) → `~/.termux/boot/start-services` (incluye `mode apply idle` si existe `~/bin/mode`)
- Copia `mode` + `mode-lib.sh` → `~/bin/` si están en `llm-setup/`
- Instala definición runit [`services/llama-smol/run`](../scripts/termux/services/llama-smol/run) pero la deja **deshabilitada** salvo `--enable-llama-smol`

> **Bloqueante para el reboot test:** sin el paquete Android **`com.termux.boot`** (F-Droid), el script en `~/.termux/boot/` **no se ejecuta** al encender el teléfono. Comprueba con `pm list packages | grep termux`.

---

## 3. Verificación

### Tras instalar (sin reboot)

Requiere haber ejecutado el instalador (runit ya presente). Si `sv status` falla, en la misma sesión:

```bash
. "$PREFIX/etc/profile.d/start-services.sh"
sleep 1
sv status sshd
pgrep -x sshd && echo sshd_ok
test -x ~/.termux/boot/start-services && echo boot_script_ok
pm list packages | grep -E 'termux'   # debe incluir com.termux.boot antes del test de reboot
```

### Tras reiniciar el teléfono

1. Espera ~1–2 min (ColorOS puede retrasar apps en background).
2. Desde el PC:

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1 "pgrep -x sshd; sv status sshd 2>/dev/null; test -f ~/.termux/boot/start-services && echo boot_script_ok"
```

O:

```powershell
.\scripts\termux\phone-check.ps1
```

(`phone-check-remote.sh` incluye bloque **boot services**.)

### Logs runit

```bash
tail -20 $PREFIX/var/log/sv/sshd/current
# si habilitaste llama-smol:
tail -20 $PREFIX/var/log/sv/llama-smol/current
```

---

## 4. Gestión manual (runit)

```bash
sv status sshd
sv up sshd
sv down sshd
sv-disable sshd    # no autostart
sv-enable sshd     # autostart con start-services

# LLM opt-in después de instalar sin flag:
sv-enable llama-smol
sv-disable llama-smol
pkill -f llama-server

# Energía (opt-in; o --enable-charge-limiter / --enable-thermal-guard al instalar)
sv-enable charge-limiter     # requiere Termux:API + mosquitto + node-red
sv-enable thermal-guard
```

`llama-smol` arranca el **router** por defecto (`LLM_SERVER_MODE` en `~/.llm.conf`): sin peticiones apenas usa RAM. Energía: [always-on-battery.md § 9](always-on-battery.md#9-limitador-de-carga-y-guardián-térmico-opt-in).

**Modo remoto al boot:** no está automatizado (Tailscale + API key). Sigue siendo manual: `llm smol --remote` cuando la VPN esté activa.

---

## 5. Revertir

```bash
bash ~/storage/shared/Download/llm-setup/uninstall-boot-services.sh
```

Quita el script Termux:Boot y deshabilita servicios runit custom; **no** desinstala paquetes `pkg`. Puedes desinstalar Termux:Boot desde Android si ya no lo necesitas.

---

## 6. Archivos en el repo

| Ruta | Uso |
|------|-----|
| `scripts/termux/boot/start-services` | Plantilla → `~/.termux/boot/` |
| `scripts/termux/install-boot-services.sh` | Instalador en el teléfono |
| `scripts/termux/uninstall-boot-services.sh` | Reversión |
| `scripts/termux/services/llama-smol/run` | Servicio runit opcional (router o single) |
| `scripts/termux/services/charge-limiter/run` · `thermal-guard/run` | Servicios runit opcionales de energía |
| `scripts/windows/push-termux-boot.ps1` | `adb push` desde Windows |

**Referencias upstream:** [Termux:Boot README](https://github.com/termux/termux-boot/blob/master/README.md), [termux-services](https://github.com/termux/termux-services), [Termux Wiki — Termux:Boot](https://wiki.termux.dev/wiki/Termux:Boot).
