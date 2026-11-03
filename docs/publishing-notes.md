# Notas antes de hacer público el repositorio

**Objetivo:** compartir el camino **RMX3311 EU bloqueado → Plan B (Termux + LLM + Kali rootless)** sin filtrar datos personales ni claves.  
**Última revisión:** 2026-10-31  

**Estado (2026-10-31):** documentación de ecosistema y checklist listas; **pendiente antes del primer push público:** anonimizar serial/IP/rutas personales (§1.1), revisar `git status` (§1.4), opcional renombrar hostname Tailscale en docs.

---

## 1. Checklist de seguridad y privacidad

### 1.1 Debe revisarse / anonimizarse

| Elemento | Dónde aparece hoy | Acción sugerida |
|----------|-------------------|-----------------|
| **Serial ADB** (`YOUR_ADB_SERIAL`) | [STATUS.md](STATUS.md), [device-record.md](device-record.md), [phone-tuning.md](phone-tuning.md), [termux-llm-guide.md](termux-llm-guide.md), [rootless-kali.md](rootless-kali.md), scripts `phone-check.ps1`, etc. | Sustituir por **`YOUR_ADB_SERIAL`** o omitir `-s` en ejemplos genéricos |
| **IP Tailscale** (`100.x.y.z`) | STATUS, termux-llm-guide, phone-tuning | Usar **`100.x.y.z`** o `realme-gt-2.tailnet-name.ts.net` ficticio |
| **Hostname Tailscale** (`realme-gt-2`) | termux-llm-guide | Aceptable si no es único globalmente; opcional renombrar a `example-phone` |
| **Usuario Termux** (`u0_aNNN`) | Varios docs | Dejar como ejemplo **genérico** (`u0_aNNN`) — cambia por instalación |
| **Rutas Windows personales** | `c:\Users\<you>\Desktop\...` en phone-tuning | Cambiar a `C:\Users\<you>\...\realme-gt2-second-life` |
| **Claves SSH privadas** | No deben estar en git (`.gitignore` cubre `*.pem`) | Verificar que **nunca** se suba `realme_gt2_termux` (solo ruta `$env:USERPROFILE\.ssh\...` OK) |
| **Clave pública en repo** | `downloads/apps/authorized_keys` (carpeta `downloads/` gitignored salvo README) | Confirmar que **no** se trackea; si se copia a docs, usar clave **de ejemplo** |
| **API key LLM** | Solo referencias a `~/.llm-api-key` en dispositivo | **Nunca** commitear contenido del archivo |
| **MagicDNS / nombre tailnet real** | termux-llm-guide | Generalizar si el nombre identifica tu cuenta |

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

Ya en [.gitignore](../.gitignore): `backup_porsche/`, `downloads/*` (excepto README), `.env`, claves.  
**Antes del push:** `git status` y confirmar que no hay:

- Dumps `*.img`, OTA `*.zip`, OFP  
- Modelos GGUF en `downloads/models/` (grandes + licencia)  
- Copias de particiones  

---

## 2. Licencia

| Opción | Cuándo usarla |
|--------|----------------|
| **MIT** | Scripts, docs, PowerShell/bash — máxima reutilización |
| **Apache-2.0** | Si prefieres cláusula de patente explícita |
| **GPL-3.0** | Solo si quieres copyleft fuerte (puede disuadir forks corporativos) |

**Recomendación:** **MIT** para el repo completo, con README aclarando que **firmware Realme**, **Kali**, **Termux** y **llama.cpp** tienen sus propias licencias al instalarlos.

Añadir archivo `LICENSE` en la raíz antes del primer release público.

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

El README actual está orientado a **port NetHunter**; conviene un párrafo inicial honesto sobre el **estado real del dispositivo** (Plan B activo, Fases 2–7 bloqueadas).

---

## 4. Issues y etiquetas GitHub sugeridas

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
