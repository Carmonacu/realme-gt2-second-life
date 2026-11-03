# Evaluación: ecosistema Gentle-AI / Engram / gentle-engram

**Fecha de investigación:** 2026-10-31  
**Proyecto:** Realme GT 2 (RMX3311) — Plan B (LLM local en Termux + Kali rootless), repo `realme-gt2-second-life`  
**Alcance:** solo lectura web + documentación del repo; **no se instaló nada** en PC ni teléfono.

---

## Resumen ejecutivo

| Herramienta | Qué es en una frase | ¿Encaja con este proyecto? |
|-------------|---------------------|----------------------------|
| **Gentle-AI** | Instalador/configurador (Go) de reglas, skills, MCP y flujo **ODD/RDD** para agentes de código ya existentes | **PC + Cursor:** opcional y razonable si quieres memoria + workflow; **teléfono:** no prioritario |
| **Engram** | Memoria persistente local (Go + SQLite) vía **MCP** para el agente; no es un LLM | **PC + Cursor:** **sí**, la pieza más útil; **teléfono + llama.cpp:** **no** encaja con el uso actual |
| **gentle-engram** | Paquete **npm** que conecta el agente **Pi** a Engram (HTTP + herramientas `mem_*`) | **No** aplica si no usas Pi; irrelevante para Termux/`llama-server` |

Tu intuición es correcta: esto está orientado a **flujos de agentes de desarrollo** (Cursor, OpenCode, Claude Code, Codex, etc.), no a sustituir el chat local con GGUF en el móvil.

---

## Contexto de nuestro proyecto (repo)

Según [`termux-llm-guide.md`](termux-llm-guide.md) y [`STATUS.md`](STATUS.md):

- Teléfono **sin root**, **8 GB RAM**, inferencia con **llama.cpp** en Termux; modelos ~3–4,2 GiB pico (p. ej. Phi ~4,2 GiB).
- En PC: documentación, scripts adb/WSL, Cursor para automatizar el repo; **bootloader bloqueado** (Plan B).
- El LLM del teléfono se usa vía **`llama-server`** y navegador en `127.0.0.1:8080`, no vía MCP de Cursor.

---

## 1. Gentle-AI (`Gentleman-Programming/gentle-ai`)

### Verificado (README y docs oficiales)

- **Autor / marca:** Alan Buscaglia (“Gentleman Programming”). Repositorio: [github.com/Gentleman-Programming/gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) (MIT; README consultado vía raw `main`, 2026-10-31).
- **Qué hace:** no es un modelo ni un chat. Es un **entorno de ingeniería determinista** para el agente que ya usas: instala/actualiza **componentes gestionados** (Engram, skills, Context7 MCP, persona, permisos, temas, GGA, etc.), inyecta **ODD** (Organic Driven Development) y **RDD** (Receipt-Driven Development, revisión acotada), y mantiene estado en `~/.gentle-ai/`.
- **Agentes declarados (17):** Pi, OpenCode, Claude Code, Codex, **Cursor**, VS Code Copilot, Gemini CLI, Kilo Code, Kimi, Kiro, Qwen Code, Hermes, Antigravity, Windsurf, OpenClaw, Trae, Conductor ([README](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/README.md)).
- **SDD (Spec-Driven Development):** desde **v4.0.0** el componente **SDD está retirado** en favor de **ODD**; restos `sdd-*` se limpian en install/sync si coinciden con plantillas oficiales ([`docs/components.md`](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/components.md)).
- **Instalación oficial (ejemplos del README, release estable citado):**
  - macOS: `brew install gentleman-programming/tap/gentle-ai`
  - macOS/Linux: `curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh | bash`
  - Windows: `go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@v4.1.1` (README; último release visible en GitHub: **v4.3.1**, 2026-10-27 — [Releases](https://github.com/Gentleman-Programming/gentle-ai/releases))
- **Uso típico:** `gentle-ai` (TUI), `gentle-ai doctor` (solo lectura), `gentle-ai install --dry-run`, `gentle-ai install`.
- **Preset `minimal` para Cursor:** documentado como **solo Engram** ([`docs/usage.md`](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/usage.md)):
  ```bash
  gentle-ai install --agent cursor --preset minimal
  ```
- **Qué escribe en Cursor (verificado en usage + upstream Engram setup):**
  - Regla gestionada `.cursor/rules/gentle-ai.mdc` con `alwaysApply: true`
  - Integración Engram vía `engram setup cursor` → `~/.cursor/mcp.json` (`mcpServers.engram` → `engram mcp` stdio)
  - Protocolo de memoria informativo en `~/.cursor/engram-memory-protocol.md` (**no se carga solo**; hay que copiarlo a User Rules si se desea)
  - Estado: `~/.gentle-ai/state.json`, backups en `~/.gentle-ai/backups/`
- **Desinstalación gestionada (no borra binarios externos):** [`gentle-ai uninstall`](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/usage.md) + snapshots previos; `gentle-ai restore` para revertir.
- **Telemetría:** métricas anónimas de uso; opt-out: `DO_NOT_TRACK`, `GENTLE_AI_TELEMETRY=0`, CI, o `gentle-ai telemetry disable` ([`docs/telemetry.md`](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/telemetry.md)).
- **Plataformas:** Windows 10/11 vía `go install`; Linux/macOS con Homebrew/apt/etc. ([`docs/platforms.md`](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/platforms.md)) — **Android/Termux no figura como soportado en la matriz publicada de releases estables**.

### No verificado / conjeturas

- Que el preset `minimal` en la versión exacta que instales incluya siempre la regla ODD completa además de Engram (el preset está definido como “Engram only” en components.md; ODD se describe como guía compartida, no componente separado).
- Impacto medido en calidad de respuestas de **Cursor** con modelos concretos en este repo (no hay benchmark propio).

---

## 2. Engram (`Gentleman-Programming/engram`)

### Verificado

- **Qué es:** sistema de **memoria persistente** para agentes de código: un **binario Go** (`CGO_ENABLED=0`), almacén **SQLite + FTS5** en `~/.engram/engram.db` (Windows: `%USERPROFILE%\.engram`), expuesto por **MCP stdio**, CLI, HTTP API y TUI ([README](https://raw.githubusercontent.com/Gentleman-Programming/engram/main/README.md)).
- **No requiere** Node, Python ni Docker para el binario ([Installation docs](https://engram.gentlemanprogramming.com/getting-started/installation/)).
- **No invoca modelos:** las herramientas `mem_save`, `mem_search`, `mem_context`, etc. las llama el **agente** (p. ej. Cursor con su modelo en la nube). Engram **no** se conecta a `llama-server` ni a un endpoint OpenAI-compatible por diseño documentado.
- **Cursor:** `engram setup cursor` registra MCP global y escribe protocolo en `~/.cursor/engram-memory-protocol.md` ([`docs/AGENT-SETUP.md`](https://github.com/Gentleman-Programming/engram/blob/main/docs/AGENT-SETUP.md)).
- **Instalación (README / INSTALLATION.md):**
  - `brew install gentleman-programming/tap/engram`
  - Windows: `go install github.com/Gentleman-Programming/engram/v3/cmd/engram@latest` (línea v3 actual en docs; releases recientes incluyen **v3.6.0**, 2026-10-24 — [Releases](https://github.com/Gentleman-Programming/engram/releases))
  - Artefactos GoReleaser: `linux`/`darwin`/`windows` × `amd64`/`arm64` ([`.goreleaser.yaml`](https://github.com/Gentleman-Programming/engram/blob/main/.goreleaser.yaml))
- **Cloud / Git sync (opcional):** memoria local por defecto; `engram sync` exporta a `.engram/` en el repo; **Engram Cloud** es opt-in con token ([README](https://raw.githubusercontent.com/Gentleman-Programming/engram/main/README.md), [`docs/engram.md` en gentle-ai](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/engram.md)).
- **Licencia:** MIT ([repo Engram](https://github.com/Gentleman-Programming/engram)).

### Android / Termux (parcialmente verificado, con matices)

| Hecho | Fuente |
|-------|--------|
| Binarios **linux_arm64** precompilados **no** son glibc de desktop fiable en Termux (Bionic); instalar desde fuente con PIE se documenta en el ecosistema Gentle-AI | [Issue #276](https://github.com/Gentleman-Programming/gentle-ai/issues/276), [PR #277](https://github.com/Gentleman-Programming/gentle-ai/pull/277) (2026) |
| **PR #277** (soporte Termux en `gentle-ai`): estado **closed**, **no merged** (`merged: false` vía API GitHub, 2026-10-31) | API GitHub PR 277 |
| Crash **SIGSYS / faccessat2** en Termux con Go 1.25 + kernel &lt; 5.8 en builds antiguos; mitigación en **v2.0.0-rc.8** (clipboard diferido) | [Issue #1067](https://github.com/Gentleman-Programming/engram/issues/1067), notas RC8 |
| Compilar en dispositivo: `go install ...@main` reportado como funcional tras fix (comentario en #1067) | Issue #1067 |

**Conjetura (no medida en nuestro RMX3311):** proceso `engram mcp`/`engram serve` suele ser **mucho más pequeño** que un GGUF 3B (~decenas de MB de binario + SQLite en disco), pero en 8 GB **cualquier servicio extra compite** con Phi (~4,2 GiB) y Termux; además **Cursor no corre en el teléfono**, así que la memoria MCP no alimenta el chat `llama-server` sin re-arquitectura completa (agente MCP + modelo local).

---

## 3. `gentle-engram` (paquete Pi)

### Verificado

- Paquete **`npm:gentle-engram`** para el agente **[Pi](https://pi.dev)** ([pi.dev/packages/gentle-engram](https://pi.dev/packages/gentle-engram), [`plugin/pi/README.md`](https://github.com/Gentleman-Programming/engram/blob/main/plugin/pi/README.md)).
- Conecta Pi a Engram con **herramientas nativas `mem_*`** sobre servidor HTTP de Engram; **no** registra Engram MCP en Pi por defecto en el flujo “native-only”.
- Instalación típica Pi: `pi install npm:gentle-engram@…`, `pi-engram init` (según README del plugin).
- **No** es un sustituto de Engram core: necesitas el binario `engram` igualmente.

### No aplica aquí

- Uso principal del usuario: **Cursor en PC** + **llama.cpp en Termux**, no Pi como IDE principal.

---

## 4. ¿Necesita modelos en la nube o puede usar `localhost:8080`?

| Pregunta | Respuesta verificada |
|----------|----------------------|
| ¿Engram usa un LLM? | **No.** Solo persistencia y búsqueda (MCP/HTTP). |
| ¿Gentle-AI ejecuta inferencia? | **No.** Configura agentes; los modelos los elige cada IDE (Cursor, etc.). |
| ¿Se documenta apuntar Engram a `llama-server` OpenAI-compatible? | **No** en README/AGENT-SETUP consultados. |
| ¿GGA puede tener `PROVIDER` tipo `ollama:…`? | **Sí** (preserva literales personalizados en config GGA) — componente **GGA**, no Engram ([`docs/components.md`](https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/docs/components.md)). Eso afecta al switcher GGA, no al stack Termux del teléfono. |

El chat local del móvil (**SmolLM3, Qwen, DeepSeek, Phi**) sigue siendo independiente de Gentle-AI/Engram.

---

## 5. Madurez, licencia y seguridad (notas honestas)

### Verificado

- **Licencia:** MIT en ambos repos principales.
- **Edad del ecosistema:** repos creados **feb 2026** (metadatos GitHub en búsqueda); releases muy activas (p. ej. gentle-ai **v4.3.1**, 2026-10-27).
- **Escala comunitaria:** miles de stars (cifras en README; pueden cambiar).
- **Issues abiertos:** volumen alto en gentle-ai (README indicaba ~962 open issues en snapshot web — señal de proyecto caliente pero también de churn).
- **Gentle-AI:** lista de denegación de lectura/edición en paths sensibles (`~/.ssh`, `.env*`, etc.) en componente `permissions` (principalmente Claude Code / OpenCode/Kilocode — Cursor tiene reglas propias + deny-list parcial vía ecosystem).
- **Engram:** datos locales en `~/.engram/`; MCP stdio lanzado por el IDE; cloud opcional con tokens que no deben commitearse.
- **Windows:** binarios Engram **sin Authenticode** (nota en release **v3.5.1** / investigaciones Smart App Control — [Releases Engram](https://github.com/Gentleman-Programming/engram/releases)).

### Conjetura

- “Production-ready” universal: los propios docs marcan RC/prerelease para algunas líneas y piden mantener copia conocida buena al actualizar.

---

## 6. Recomendación para **este** proyecto

### (a) PC — Cursor + repo NetHunter: **útil con moderación**

**Encaja cuando:**

- Quieres que el agente **recuerde** entre sesiones decisiones ya documentadas en [`STATUS.md`](STATUS.md) (bootloader EU bloqueado, Plan B, rutas Termux, MD5 OTA, etc.) sin repetir el briefing.
- Trabajas mucho con **Cursor Agent** en este repo y aceptas tocar `~/.cursor/mcp.json` y reglas gestionadas.

**Pieza recomendada:** **Engram** (directo o vía `gentle-ai install --agent cursor --preset minimal`).

**Opcional:** preset **`full-gentleman`** solo si quieres skills + Context7 + persona + RDD/ODD completo; es **más invasivo** en configuración global y telemetría (desactivable).

**No sustituye:** la documentación en `docs/` — sigue siendo la fuente de verdad versionada; Engram es **capa auxiliar** del agente.

### (b) Teléfono — LLM local Termux: **no recomendado / poco realista**

- El valor de Engram es **MCP + agente de código**; el flujo actual es **`llm smol`** + UI web, sin agente MCP.
- **8 GB RAM:** aunque Engram sea ligero frente a Phi, añade complejidad y otro proceso Go **sin beneficio** en ese flujo.
- **Soporte Termux** en gentle-ai: PR no fusionada; Engram en Termux tiene **historial de incompatibilidades** con binarios prebuilt → solo experimental vía **compilación en dispositivo**.
- **No modificar el teléfono** para probar esto (acordado).

### (c) Overkill / evitar ahora

- **Gentle Shell + Pi + gentle-engram** si no usas Pi.
- **Engram Cloud** sin necesidad multi-máquina.
- **CodeGraph**, **Context7**, **full-gentleman** si solo quieres memoria del proyecto Plan B.
- Instalar todo el ecosistema en **Termux** “por si acaso”.

---

## 7. Prueba mínima de bajo riesgo (solo PC — no ejecutada en esta sesión)

Objetivo: **solo Cursor + Engram**, telemetría off, reversible.

### Requisitos

- Go **1.25.10+** (README gentle-ai para Windows) o usar release precompilado donde exista.
- `git` en PATH (quickstart).
- Cursor instalado.

### Pasos sugeridos (PowerShell, desde documentación oficial)

```powershell
# 1) Binario gentle-ai (ejemplo README; o @latest / v4.3.1 según preferencia de canal)
go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@v4.3.1

# Asegurar PATH (si hace falta):
# $env:Path += ";$([Environment]::GetEnvironmentVariable('USERPROFILE'))\go\bin"

# 2) Diagnóstico sin cambios
gentle-ai doctor

# 3) Vista previa
gentle-ai install --dry-run --agent cursor --preset minimal

# 4) Opt-out telemetría antes del install real (docs/telemetry.md)
gentle-ai telemetry disable

# 5) Instalar solo memoria (preset minimal = Engram only, docs/components.md)
gentle-ai install --agent cursor --preset minimal

# 6) Copiar protocolo de memoria a User Rules (manual; docs AGENT-SETUP Cursor)
# Abrir: %USERPROFILE%\.cursor\engram-memory-protocol.md → pegar en Cursor Customize → Rules

# 7) Reiniciar Cursor para cargar MCP
```

**Alternativa más mínima (solo Engram, sin gentle-ai):**

```powershell
go install github.com/Gentleman-Programming/engram/v3/cmd/engram@latest
engram doctor
engram setup cursor
# + paso manual del protocolo en User Rules
```

### Cómo deshacer (documentado)

```powershell
# Quitar configuración gestionada por gentle-ai (no elimina el binario en go\bin)
gentle-ai uninstall --agent cursor --yes

# Restaurar desde snapshot si algo quedó mal
gentle-ai restore --list
gentle-ai restore latest --yes   # según docs/usage.md

# Telemetría
gentle-ai telemetry disable      # ya aplicado

# Binarios (manual)
Remove-Item "$env:USERPROFILE\go\bin\gentle-ai.exe" -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\go\bin\engram.exe" -ErrorAction SilentlyContinue

# Memoria Engram (solo si quieres borrar datos, destructivo)
# Remove-Item -Recurse -Force "$env:USERPROFILE\.engram"
# Remove-Item -Recurse -Force "$env:USERPROFILE\.gentle-ai"
```

Revisar `~/.cursor/mcp.json` y quitar la clave `engram` si `uninstall` no la tocara (Engram manual setup).

**Opcional en el repo:** `engram sync` crea/actualiza `.engram/` para versionar memoria de equipo — valorar privacidad antes de commitear.

---

## 8. Próximo paso recomendado

1. **Seguir con la documentación en `docs/`** como fuente principal (ya está alineada con Plan B).
2. Si quieres experimentar: en el **PC**, **`gentle-ai install --dry-run --agent cursor --preset minimal`** + **`gentle-ai telemetry disable`**, luego install real; usar el agente en este repo y comprobar en `engram tui` qué guarda.
3. **No** instalar Gentle-AI/Engram en el **teléfono** para el stack llama.cpp actual.

---

## Fuentes consultadas (URLs y fechas visibles)

| Recurso | URL | Fecha / nota |
|---------|-----|----------------|
| Gentle-AI README | https://github.com/Gentleman-Programming/gentle-ai | README raw `main`, consulta 2026-10-31 |
| Gentle-AI releases v4.3.1 | https://github.com/Gentleman-Programming/gentle-ai/releases | Release 2026-10-27 |
| Gentle-AI usage / uninstall | https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/usage.md | raw fetch 2026-10-31 |
| Gentle-AI components / presets | https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/components.md | raw fetch 2026-10-31 |
| Gentle-AI telemetry | https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/telemetry.md | raw fetch 2026-10-31 |
| Gentle-AI platforms | https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/platforms.md | consulta 2026-10-31 |
| Gentle-AI engram.md | https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/engram.md | raw fetch 2026-10-31 |
| Engram README | https://github.com/Gentleman-Programming/engram | raw `main`, 2026-10-31 |
| Engram INSTALLATION | https://github.com/Gentleman-Programming/engram/blob/main/docs/INSTALLATION.md | consulta 2026-10-31 |
| Engram releases (v3.6.0) | https://github.com/Gentleman-Programming/engram/releases | 2026-10-24 |
| Engram AGENT-SETUP (Cursor) | https://github.com/Gentleman-Programming/engram/blob/main/docs/AGENT-SETUP.md | raw fetch 2026-10-31 |
| gentle-engram (Pi) | https://pi.dev/packages/gentle-engram | consulta 2026-10-31 |
| Termux gentle-ai PR #277 | https://github.com/Gentleman-Programming/gentle-ai/pull/277 | **closed, not merged** (API 2026-10-31) |
| Engram Termux faccessat2 #1067 | https://github.com/Gentleman-Programming/engram/issues/1067 | issue/RC8 2026 |
| Docs proyecto Termux LLM | [`termux-llm-guide.md`](termux-llm-guide.md) | repo local |
| Estado proyecto | [`STATUS.md`](STATUS.md) | verificado 2026-10-31 |

---

*Documento generado para decisión informada; no implica endorsement del ecosistema Gentleman Programming.*
