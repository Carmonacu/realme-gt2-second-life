# Rootless Kali / NetHunter (stock RMX3311)

Run Kali tooling **without root**, **without** a NetHunter kernel, on **ColorOS 15 / Android 15**. This is **Plan B** while [bootloader unlock remains blocked](STATUS.md).

**Official reference:** [NetHunter Rootless](https://www.kali.org/docs/nethunter/nethunter-rootless/) (page updated **2025-Jun-11**).  
**Research snapshot:** 2026-10-31.

---

## Instalación verificada — RMX3311 (2026-10-31)

> **Ética / legal:** usa estas herramientas **solo** contra sistemas que te pertenezcan o con **permiso escrito** del propietario. `scanme.nmap.org` permite escaneos ligeros; no abuses.

### Enfoque elegido (y por qué)

| Opción | Decisión |
|--------|----------|
| **Oficial `install-nethunter-termux`** (Kali) | **Elegida** |
| **`proot-distro install kali`** (Termux) | Descartada para producción en este teléfono |

**Motivos:** el script oficial ([offs.ec/2MceZWr](https://offs.ec/2MceZWr) → GitLab Kali, `VERSION=20250525`) instala el **rootfs NetHunter/Kali arm64** documentado, crea `nethunter` / `nh`, ruta de actualización **`apt` dentro del chroot**, y encaja con [NetHunter Rootless](https://www.kali.org/docs/nethunter/nethunter-rootless/). `proot-distro` es más simple de resetear, pero **no** trae el wrapper NetHunter ni el mismo flujo oficial; en ColorOS 15 ambos usan **proot** (mismas limitaciones de kernel).

**Imagen:** `[2] NetHunter ARM64 (minimal)` — **no** `full`/`kali-linux-default` (varios GB innecesarios).

### Preflight (SSH, 2026-10-31)

Desde PC:

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1
```

En Termux: **~75 GB libres** en almacenamiento compartido; **MemAvailable ~3,0–3,6 GiB**; **`llama-server` no estaba en ejecución**; batería OK. Instalación con `termux-wake-lock`.

### Comandos ejecutados (resumen)

```bash
# Termux — dependencias + instalador oficial
pkg install -y wget curl axel proot tar xz-utils
wget -O install-nethunter-termux https://offs.ec/2MceZWr
chmod +x install-nethunter-termux
export TERM=xterm-256color
echo 2 | ./install-nethunter-termux   # minimal arm64; requiere TTY (ssh -t) o pipe

# DNS en chroot (Android/Termux no monta resolv.conf en proot por defecto)
cp $PREFIX/etc/resolv.conf ~/kali-arm64/etc/resolv.conf

# Dentro de Kali (root en chroot)
nh -r apt update && nh -r apt full-upgrade -y
nh -r apt install -y kali-linux-core
nh -r apt install -y nmap whatweb nikto sqlmap hydra john gobuster ffuf dirb wfuzz \
  curl wget dnsutils whois netcat-openbsd socat python3-pip git exploitdb seclists
nh -r apt install -y metasploit-framework
```

**Tamaños (después de instalar):**

| Componente | Tamaño |
|------------|--------|
| `~/kali-arm64` (rootfs + herramientas) | **~5,9 GiB** |
| Archivo `.tar.xz` minimal (opcional borrar) | **~121 MiB** |
| `~/models` (LLM, sin tocar) | **~7,6 GiB** |
| **Total `~/` aprox.** | **~14 GiB** |

**Versiones clave:** Kali **2026.3** (`VERSION_ID=2026.3`); `nmap` **7.991**; `metasploit-framework` **6.5.7-0kali1**; `kali-linux-core` **2026.4.2**; `hydra` **9.7-2**; `sqlmap` **1.10.10-1**; `seclists` **2025.3** (grande — ver nota abajo).

### Entrar en Kali (día a día)

En **Termux** (scripts en `~/bin/`, copiados desde `scripts/termux/` del repo):

```bash
termux-wake-lock          # escaneos largos / ColorOS
kali                      # shell Kali (usuario kali en proot)
kali --force              # si necesitas entrar con llama-server activo (no recomendado)
kali-update               # apt update + full-upgrade en el chroot
kali-uninstall            # borra solo kali-arm64 + nh (pide confirmación SI)
```

Atajos oficiales equivalentes: `nethunter` / `nh` · root en chroot: `nh -r`.

Desde **PC**:

```powershell
adb -s YOUR_ADB_SERIAL forward tcp:8022 tcp:8022
ssh -i $env:USERPROFILE\.ssh\realme_gt2_termux -p 8022 u0_aNNN@127.0.0.1
kali
```

**Guardias (`kali-common.sh`):** refuse si **MemAvailable &lt; ~1,5 GiB**; refuse si **`llama-server` activo** (usa `kali --force` solo si aceptas compartir RAM); sincroniza **`resolv.conf`** antes de entrar.

### Pruebas realizadas (evidencia)

| Prueba | Resultado |
|--------|-----------|
| `nh -r cat /etc/os-release` | `Kali GNU/Linux Rolling` **2026.3** |
| `nh -r nmap --version` | **7.991** |
| `nh -r apt update` | OK (repos `kali.download`) |
| `nh -r curl -sI https://http.kali.org` | `HTTP/1.1 200 OK` |
| `nh -r host scanme.nmap.org` | resolución DNS OK |
| `nh -r nmap -sT -Pn -p 80,443 -T3 scanme.nmap.org` | **80/tcp open**, 443 closed, ~0,6 s |
| `nh -r nmap -sT -Pn -T3 -p1-400 scanme.nmap.org` | **~20 s**, varios puertos (22, 80, …) |
| `nh -r ping -c1 scanme.nmap.org` | **OK** (ICMP desde proot en este dispositivo) |
| `nh -r msfvenom -h` | Metasploit payload generator presente |
| `nh -r nmap -sn` / `-sS` → `127.0.0.1` | **Fallo ruta** (`setup_target: failed to determine route`) |
| Escaneo **~2,5 min** en foreground (`-p1-800`) | proot/nmap **sin signal 9** |
| Escaneo **10 min** en background | **No verificado** (jobs vía `nohup`/SSH sin TTY fallaron por quoting; repetir manualmente en Termux con `termux-wake-lock`) |
| `msfconsole -n -q -x 'version; exit'` vía SSH | **No verificado** (arranque lento / bloqueo en sesión no interactiva); usar **`msfconsole -n`** en Termux interactivo |

**Nota `seclists`:** metapaquete **grande**; se instaló dentro del tope **&lt; ~8 GiB** del rootfs (~5,9 GiB total). Para ahorrar espacio: `nh -r apt remove seclists` y usar solo `wordlists`/`dirb` wordlists.

### Tabla de capacidades (rootless, este teléfono)

| Función | ¿Funciona? | Notas |
|---------|------------|--------|
| **nmap -sT / -sV** (TCP conect) | **Sí** | Preferir `-Pn` si ICMP/ruta falla |
| **nmap -sS** (SYN raw) | **No** / error ruta | Sin raw sockets reales en Android sin root |
| **nmap -sn** (ping sweep) | **Inconsistente** | A veces falla ruta en proot; `-sT` a puertos conocidos |
| **ping / ICMP** | **Sí** (probado a scanme) | Puede variar por destino/red |
| **whatweb, nikto, sqlmap, hydra, john, gobuster, ffuf, dirb, wfuzz** | **Sí** (instalados) | Hydra: rate-limit en objetivos reales |
| **searchsploit / exploitdb** | **Sí** | |
| **hashcat (GPU)** | **No instalado** | Sin GPU útil en Termux |
| **metasploit-framework** | **Parcial** | **`msfconsole -n`** (sin DB); DB oficial rootless limitada |
| **802.11 monitor / injection** | **No** | Requiere kernel NetHunter |
| **USB HID / BadUSB** | **No** | |
| **arp-scan** | **No instalado** | Raw ARP limitado sin root |
| **Docker** | **No** | Daemon no viable en proot |
| **Módulos kernel / `modprobe`** | **No** | |
| **KeX (VNC desktop)** | **No probado** | Opcional; consume RAM |

### Kali + LLM local (opcional)

Regla del teléfono: **una carga pesada a la vez** (`llm smol` **o** Kali, no ambos).

- **`llama-server`** escucha en Termux (`127.0.0.1:8080`); el **proot no comparte** ese localhost con el chroot.
- Uso práctico: pentest en **`kali`**, informes asistidos desde **Termux** o desde el **PC vía Tailscale** (`llm smol --remote`), no mezclar sin montajes extra.
- Si en el futuro quieres API desde Kali: exponer puerto en interfaz Tailscale del teléfono (documentado en [termux-llm-guide.md](termux-llm-guide.md)), no `127.0.0.1:8080` dentro de `nh`.

### Actualizar / eliminar

```bash
kali-update
# o: nh -r apt update && nh -r apt full-upgrade -y

kali-uninstall    # escribe SI — no borra ~/models
rm -f ~/kali-nethunter-rootfs-*.tar.xz   # recuperar ~121 MiB
```

---

## What rootless gives vs full NetHunter

| Capability | Rootless (proot Kali) | Full NetHunter (custom kernel) |
|------------|----------------------|--------------------------------|
| CLI pentest tools (`nmap`, `sqlmap`, …) | **Mostly yes** in chroot | **Yes** |
| **Monitor mode / Wi‑Fi injection** | **No** (needs kernel/driver) | **Yes** on supported devices |
| **USB HID / BadUSB** | **No** | **Yes** with supported kernel |
| **Docker** inside proot | **Unreliable / not supported** | Sometimes on device (still hard) |
| **Root on Android** | **No** | Often yes (Magisk) |
| **Metasploit DB** | **Limited** (official docs) | Full stack easier |

NetHunter comparison table: [Kali NetHunter docs](https://www.kali.org/docs/nethunter/).

---

## Prerequisites

- Stock phone, USB debugging / wireless debugging for **optional** PC-side `adb` (phantom-process tweaks).
- **~8–15 GB free storage** for Kali rootfs + tools.
- Stable network for first install.
- Read [ColorOS stability](#coloros-15-realme--termux-stability) **before** long installs.

---

## Termux: F-Droid vs Google Play

| Source | Status |
|--------|--------|
| **[F-Droid](https://f-droid.org/packages/com.termux/)** (`0.118.3`, 2025-05-29) | **Recommended** — official maintainer channel |
| **GitHub releases** | Official alternative ([termux-app](https://github.com/termux/termux-app)) |
| **Google Play `v0.120+`** | **Experimental fork** — diverged from mainline; ~v0.108 feature level; **deprecated** for most users ([discussion #4000](https://github.com/termux/termux-app/discussions/4000), 2024-06-08) |

**Never mix** APK signatures between F-Droid, GitHub, and Play.

For NetHunter Store–bundled Termux: still prefer updating to **current F-Droid Termux** if the store ships an old build — uninstall store Termux **only if** you accept reinstalling the rootfs (backup first).

---

## Installation — official NetHunter Rootless

### Path A — NetHunter Store (documented by Kali)

1. Install **NetHunter Store** from [store.nethunter.com](https://store.nethunter.com) (see [rootless doc](https://www.kali.org/docs/nethunter/nethunter-rootless/)).
2. From the store, install **Termux**, **NetHunter KeX client**, **Hacker’s Keyboard** (install button may not refresh — ignore).
3. In Termux:

```bash
termux-setup-storage
pkg install wget
wget -O install-nethunter-termux https://offs.ec/2MceZWr
chmod +x install-nethunter-termux
./install-nethunter-termux
```

4. After install, update Kali (**first command inside `nethunter`**):

```bash
nethunter
sudo apt update && sudo apt full-upgrade -y
# Optional full tool metapackage (large):
# sudo apt install -y kali-linux-default
```

**Usage (from [official table](https://www.kali.org/docs/nethunter/nethunter-rootless/)):**

| Command | Purpose |
|---------|---------|
| `nethunter` or `nh` | Kali shell (proot) |
| `nethunter kex passwd` | Set KeX VNC password (once) |
| `nethunter kex &` | Desktop session (background — use `fg` for password prompt) |
| `nethunter kex stop` | Stop KeX |

### Path B — proot-distro Kali only (no NetHunter wrapper)

Useful if you want **Debian/Kali** without the NetHunter helper scripts:

```bash
pkg update && pkg upgrade -y
termux-setup-storage
pkg install proot-distro
proot-distro install kali
proot-distro login kali
```

Inside Kali:

```bash
apt update && apt full-upgrade -y
apt install -y kali-linux-core   # smaller than kali-linux-default
```

**Verified limitation:** same as rootless — **no kernel Wi‑Fi tools**, no real `sudo` on Android (proot gives root **inside** the chroot only — [official tips](https://www.kali.org/docs/nethunter/nethunter-rootless/)).

---

## ColorOS 15 (Realme) — Termux stability

Without these, **`signal 9`**, `[Process completed (signal 9)]`, and KeX drops are common on **Android 12+** (phantom / child process limits) and **ColorOS 15** (vendor hardening).

### On-device (no PC)

1. **Developer options** → enable **Disable child process restrictions**  
   - Android **14+** official toggle: [Android-Docs phantom processes](https://github.com/agnostic-apollo/Android-Docs/blob/master/en/docs/apps/processes/phantom-cached-and-empty-processes.md)  
   - ColorOS **15** / Oppo–Realme: also reported for proot/Termux ([DroidWin](https://droidwin.com/termux-not-working-on-android-15-oneplus-realme-oppo-fixed/), community reports **2024–2025**)

2. **Battery — Termux (and KeX client, Termux:X11 if used):**  
   - Settings → **Battery** → **App battery management** → Termux → enable **Allow auto-launch**, **Allow background activity**, **Allow foreground activity**; disable aggressive optimize ([dontkillmyapp Realme](https://dontkillmyapp.com/realme), [llcloud ColorOS guide](https://llcloud.app/guides/stop-oppo-realme-killing-apps/))  
   - Turn off **Power saving mode** during long scans  
   - **Lock Termux** in recents (multitasking menu)

3. **Termux wakelock:**

```bash
pkg install termux-api   # also install Termux:API app from F-Droid if using API
termux-wake-lock
```

4. In Termux notification: **Acquire wakelock** (if shown).

### Wireless debugging + `adb` (PC or same Wi‑Fi)

**Android 15 / ColorOS:** enable **Wireless debugging**; pair once from PC.

**Raise phantom process cap** (helps proot forks; **verified** mechanism — [Android-Docs](https://github.com/agnostic-apollo/Android-Docs/blob/master/en/docs/apps/processes/phantom-cached-and-empty-processes.md), [termux-app #2366](https://github.com/termux/termux-app/issues/2366)):

```bash
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell "/system/bin/device_config get activity_manager max_phantom_processes"
```

**If Google Play services resets `device_config`** (some OEMs):

```bash
adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
```

**Android 12L / 13+ alternative** (also disables excessive-CPU child kill when toggle unavailable):

```bash
adb shell "settings put global settings_enable_monitor_phantom_procs false"
```

**Android 14+ preferred on-device:** **Disable child process restrictions** in Developer options (persists while Dev options stay enabled — [Android-Docs](https://github.com/agnostic-apollo/Android-Docs/blob/master/en/docs/apps/processes/phantom-cached-and-empty-processes.md)).

**Verified gap:** On **plain Android 12** (not 12L+), **no** setting disables **excessive CPU** kill of child processes — only the **>32 phantom** trim ([Android-Docs](https://github.com/agnostic-apollo/Android-Docs/blob/master/en/docs/apps/processes/phantom-cached-and-empty-processes.md)). ColorOS 15 behaves like modern Android — use the **Developer options** toggle first.

**Project rule:** run `adb` only for these read/write settings when **you** choose; this repo doc does not require it.

---

## What works / what does not (rootless on GT2)

### Works (typical)

- Network scanning **from Android network stack** (`nmap` over TCP/UDP, not raw 802.11 monitor)
- Web app testing, password lists, `sqlmap`, `hydra` (rate-limited), `searchsploit`, scripting
- **SSH client/server** to external lab machines (real monitor mode on **other** hardware)
- Learning / reporting workflows aligned with [PLAN.md](PLAN.md) ethics and scope

### Does not work (or broken expectations)

| Feature | Why |
|---------|-----|
| **802.11 monitor mode / injection** | Needs **kernel** + firmware support (NetHunter kernel path **blocked** on RMX3311 EU) |
| **Internal Wi‑Fi chip pentest** | Same |
| **USB HID attacks** | Needs root + kernel |
| **Docker daemon** | No cgroups in proot; use **native** packages or remote lab |
| **`top` / some `/proc` tools** | [Official rootless tip](https://www.kali.org/docs/nethunter/nethunter-rootless/) |
| **Metasploit DB** | Official: works but **without DB support** in rootless |

---

## Backup rootfs

From Termux (**stop KeX / nethunter sessions first**):

```bash
tar -cJf kali-arm64.tar.xz kali-arm64 && mv kali-arm64.tar.xz ~/storage/downloads/
```

(Use `armhf` only on 32-bit rootfs — GT2 is **arm64**.)

---

## Pair with local AI

See [phases/08-ai-local.md](phases/08-ai-local.md) and **[termux-llm-guide.md](termux-llm-guide.md)**: run **`llm smol`** in Termux (`llama-server` on `127.0.0.1:8080`), query from Kali proot via `curl` — keeps heavy RAM use in one environment.

---

## Suggested first session (after install)

```bash
# Termux
nethunter
sudo apt update && sudo apt install -y nmap whatweb
nmap -sV -T3 <lab-target-ip>    # only systems you own or have written permission to test
```

---

## Sources

| ID | URL | Notes |
|----|-----|-------|
| K1 | https://www.kali.org/docs/nethunter/nethunter-rootless/ | Install/usage; updated 2025-Jun-11 |
| K2 | https://www.kali.org/docs/nethunter/ | Editions comparison |
| K3 | https://github.com/agnostic-apollo/Android-Docs/blob/master/en/docs/apps/processes/phantom-cached-and-empty-processes.md | Phantom processes |
| K4 | https://github.com/termux/termux-app/issues/2366 | Termux signal 9 |
| K5 | https://dontkillmyapp.com/realme | Realme battery UI |
| K6 | https://github.com/termux/termux-app/discussions/4000 | Play vs F-Droid |
