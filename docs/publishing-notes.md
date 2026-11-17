# Notas antes de hacer público el repositorio

**Objetivo:** compartir el camino **RMX3311 EU bloqueado → Plan B (Termux + LLM + Kali rootless)** sin filtrar datos personales ni claves.  
**Última revisión:** 2026-11-17  

**Estado (2026-11-17):** el repositorio ya es **público**. Esta pasada (CAR-76) aplicó anonimización en el árbol actual, amplió `.gitignore` (§1.4), verificó MIT + README (§3) y etiquetas sugeridas (§4). **Persiste en el historial Git** información sensible de commits anteriores — ver recomendación en el PR; no se reescribió historia.

---

## 1. Checklist de seguridad y privacidad

### 1.1 Debe revisarse / anonimizarse

| Elemento | Dónde aparece | Estado (2026-11-17) |
|----------|----------------|---------------------|
| **Serial ADB** | Docs, `device-record.md`, scripts PowerShell | **Hecho** — placeholder `YOUR_ADB_SERIAL`; scripts usan `GT2_ADB_SERIAL` / `ANDROID_SERIAL` vía [`scripts/windows/adb-serial.ps1`](../scripts/windows/adb-serial.ps1) |
| **IP Tailscale** | Guides LLM / tuning / STATUS | **Hecho** — `100.x.y.z` / `<TAILSCALE_IP>` |
| **Hostname Tailscale** | termux-llm-guide, portal | **Hecho** — `example-phone` (hint en `portal-status.sh` configurable con `TAILSCALE_HOST_HINT`) |
| **Usuario Termux** (`u0_aNNN`) | Varios docs | **OK** — genérico |
| **Rutas Windows personales** | push adb, WSL | **Hecho** — rutas relativas al repo o `REPO_ROOT` / `%USERPROFILE%` sin usuario real |
| **Claves SSH privadas** | `.gitignore` `*.pem` | **OK** — solo rutas `$env:USERPROFILE\.ssh\…` en docs |
| **Clave pública en repo** | `downloads/apps/authorized_keys` | **OK** — `authorized_keys` y `downloads/apps/*` gitignored |
| **API key LLM** | Solo `~/.llm-api-key` en dispositivo | **OK** — no trackeada |
| **MagicDNS / nombre tailnet real** | termux-llm-guide | **Hecho** — sin nombres de tailnet reales |

### 1.2 Plantilla sugerida para [device-record.md](device-record.md)

```markdown
| adb serial | `YOUR_ADB_SERIAL` (opcional; no necesario para clonar el proyecto) |
| Tailscale (ejemplo) | `100.x.y.z` / hostname MagicDNS de tu tailnet |
```

Mantén build **RMX3311_15.0.0.1650(EX01)** — es información pública de firmware, no PII.

### 1.3 Qué **sí** puede quedar público

- Codename **porsche**, modelo **RMX3311**, SoC **SM8350**  
- Hashes de APK Tailscale / llama (integridad, no secretos)  
- MD5 del Full OTA EU documentado  
- Listas de paquetes `pm disable-user` (sin IMEI)  
- Benchmarks anonimizados en `docs/benchmarks/`  

### 1.4 Archivos que no deben entrar al remoto

En [.gitignore](../.gitignore): `backup_porsche/`, `downloads/*` (excepto README y `.gitkeep`), `downloads/models/`, `downloads/apps/*`, `*.gguf`, `authorized_keys`, `.env`, claves, `nethunter_backup/`, imágenes/firmware (`*.img`, `*.zip`, `*.ofp`).  

**Revisión CAR-76:** `git ls-files` sin dumps, modelos GGUF ni claves; snapshots de tuning sin serial en texto.

---

## 2. Licencia

| Opción | Cuándo usarla |
|--------|----------------|
| **MIT** | Scripts, docs, PowerShell/bash — máxima reutilización |
| **Apache-2.0** | Si prefieres cláusula de patente explícita |
| **GPL-3.0** | Solo si quieres copyleft fuerte (puede disuadir forks corporativos) |

**Recomendación:** **MIT** para el repo completo, con README aclarando que **firmware Realme**, **Kali**, **Termux** y **llama.cpp** tienen sus propias licencias al instalarlos.

**Estado:** archivo [`LICENSE`](../LICENSE) MIT en la raíz — **hecho**.

---

## 3. Estructura README para recién llegados

Propuesta de bloques (español o bilingüe EN/ES):

1. **TL;DR** — «RMX3311 EU: unlock bloqueado; Plan B operativo (LLM + Kali rootless + SSH + Tailscale)».  
2. **¿Es para mí?** — Tabla: tienes 3311 EU / quieres NetHunter completo → lee [alternative-devices.md](alternative-devices.md).  
3. **Inicio rápido Plan B** — enlaces a [termux-llm-guide.md](termux-llm-guide.md), [rootless-kali.md](rootless-kali.md) y [always-on-battery.md](always-on-battery.md) si dejas el teléfono enchufado.  
4. **Plan A (pausado)** — [PLAN.md](PLAN.md), [unlock-research.md](unlock-research.md), [STATUS.md](STATUS.md).  
5. **Ecosistema / ampliaciones** — [second-life-ecosystem.md](second-life-ecosystem.md) y [jellyfin-media.md](jellyfin-media.md) (media server).  
6. **Hardware alternativo** — [alternative-devices.md](alternative-devices.md).  
7. **Avisos legales** — pentest solo con autorización; EU firmware only; riesgo brick.  
8. **Contribuir** — issues welcome; no se aceptan secretos en PRs.

**Estado (2026-11-17):** [`README.md`](../README.md) incluye párrafo Plan B + sección **Para recién llegados (es)** alineada con esta lista.

---

## 4. Issues y etiquetas GitHub sugeridas

Crear en el repositorio (Settings → Labels) si no existen:

- `plan-b` — Termux / LLM / rootless  
- `unlock-blocked` — investigación EU  
- `docs` — documentación  
- `help-wanted` — OTA mirrors, drivers fastboot Windows  
- `wontfix-unlock-cn` — peticiones CN/IN (conflicto con [PLAN.md](PLAN.md))  

Plantilla de issue «Mi RMX3311 también tiene Deep Testing no soportado» → enlace a unlock-research + STATUS.

---

## 5. Comunicación al publicar

**Título sugerido del repo (sin cambiar obligatorio):**  
*NetHunter / segunda vida — Realme GT 2 RMX3311 EU (Plan B Termux)*  

**Descripción corta:**  
Documentación verificada para GT2 europeo con bootloader bloqueado: LLM local, Kali NetHunter rootless, debloat reversible, investigación unlock y port kernel (pausado).

**Foros donde enlazar (con tacto):**

- [XDA RMX3311 unlock test](https://xdaforums.com/t/unlock-bootloader-for-rmx3311-test.4669611/) — «Plan B documentado en …»  
- r/Realme, r/termux — solo si cumples reglas anti-spam; aporta resumen + matriz de viabilidad  

**No prometer:** unlock EU en A15, NetHunter con injection en stock, Docker «real» sin root.

---

## 6. Post-publicación (mantenimiento)

- [ ] Actualizar [STATUS.md](STATUS.md) cuando cambie build OTA o stack Termux  
- [ ] Re-ejecutar búsqueda OTA trimestral (enlaces CDN mueren — ver device-record)  
- [ ] Si desbloqueas otro dispositivo, bifurcar experiencia en rama o doc separado  
- [ ] Rotar API key LLM si alguna vez se filtró en un log commitado  
- [ ] Tras cambios locales con datos reales, `git grep` serial / `100.` / rutas de usuario antes de push  

---

## 7. Enlaces internos obligatorios en la primera release pública

| Doc | Propósito |
|-----|-----------|
| [second-life-ecosystem.md](second-life-ecosystem.md) | Comunidad + qué más se puede montar |
| [service-modes-design.md](service-modes-design.md) | Servicios opcionales + diseño de modos RAM (sin implementar) |
| [always-on-battery.md](always-on-battery.md) | 24/7 enchufado, batería, térmica, rol principal |
| [termux-boot-services.md](termux-boot-services.md) | Termux:Boot + runit (sshd al reboot) |
| [benchmarks/rmx3311-llm-opencl-vulkan.md](benchmarks/rmx3311-llm-opencl-vulkan.md) | OpenCL/Vulkan probados — quedarse en CPU b12017 |
| [jellyfin-media.md](jellyfin-media.md) | Jellyfin en Termux: media de prueba legal (Blender), rutas y Direct Play |
| [alternative-devices.md](alternative-devices.md) | Salida hardware NetHunter completo |
| [publishing-notes.md](publishing-notes.md) | Esta checklist (opcional mantener privada un tiempo — contiene hints de scrubbing) |