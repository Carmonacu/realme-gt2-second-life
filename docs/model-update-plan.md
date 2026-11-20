# Plan de actualización de modelos — LFM3 / LFM2.5 (2026-11)

**Fecha:** 2026-11-19 · [CAR-117](https://linear.app/carmonacu/issue/CAR-117/realme-gt2-re-revision-del-unlock-eu-ronda-3-y-plan-de-actualizacion) · **Estado:** propuesto, **sin ejecutar**
**Regla acordada:** si los candidatos dan **mejor rendimiento** (velocidad + RAM) **y más calidad**, se cambian (preset por defecto).

**Incumbentes** ([benchmarks/rmx3311-llm.md](benchmarks/rmx3311-llm.md)): SmolLM3-3B Q4_K_M (~9,6 tg128 t/s, pico VmHWM ~3,9 GiB) y Qwen2.5-3B Q4_K_M (~11 t/s router; alternativa multilingüe).

---

## 1. Candidatos y por qué

| Modelo | Quant / tamaño | Origen | Estado en llama.cpp (verificado 2026-11-19) |
|--------|----------------|--------|----------------------------------------------|
| **LFM3-1.7B** | **Q4_0 ~993 MiB** (Q8_0 1,71 GiB; QAD-Q4_0 disponible) | [LiquidAI/LFM3-1.7B-GGUF](https://huggingface.co/LiquidAI/LFM3-1.7B-GGUF) | Soporte merged **2026-10-27** ([#31252](https://github.com/ggml-org/llama.cpp/pull/31252)). Arquitectura **híbrida** (13 conv + 5 SWA + 6 attn) → cache casi todo recurrente, KV diminuto; 256K contexto; tool calling |
| **LFM2.5-2.6B** | Q4_0 ~1,5 GiB (estimado; confirmar al descargar) | [LiquidAI en HF](https://huggingface.co/LiquidAI) (buscar LFM2.5-2.6B-GGUF) | Familia LFM2 soportada desde 2025; los benches del fabricante lo corren en **b11744** |
| **Qwen3-1.7B** (control, rol multilingüe) | Q4_K_M ~1,1 GiB | HF (revisión **Instruct-2507**, la actual del modelo) | Soporte Qwen3 en llama.cpp desde 2025 — sin riesgo de build |

Referencia del fabricante (Liquid, medido en Q4_0 con llama.cpp en 3 dispositivos edge): LFM3-1.7B **prefill ≥2,5× y decode ≥1,8× más rápido** que todos los comparados usando la menor RAM. **Cifras del fabricante: medir, no creer.**

## 2. Build de referencia (importante)

- **b12549** (2026-11-19) trae paquete prebuilt **`llama-b12549-bin-android-arm64-snapdragon.tar.gz`** y, sobre todo, el **fix del reuse de contexto para modelos recurrentes** ([#32339](https://github.com/ggml-org/llama.cpp/issues/32339): LFM3 en `llama-server` reprocesaba el prompt entero en cada turno con builds ~b12416; cerrado el 2026-11-17). También añade spec-dec para LFM3 ([#31598](https://github.com/ggml-org/llama.cpp/pull/31598)) y tensor-split ([#31431](https://github.com/ggml-org/llama.cpp/pull/31431) — irrelevante en CPU).
- **No usar builds anteriores a b12416 con LFM3 en router.**
- Dos binarios, como siempre:
  1. **Bench**: el prebuilt snapdragon b12549 (sin router) para `llama-bench`.
  2. **Router**: auto-compilar b12549 en Termux con las flags del repo (`-DLLAMA_SUBPROCESS=ON -DSUBPROCESS_HAVE_CWD=0 -landroid-spawn` — [termux-llm-guide.md](termux-llm-guide.md) § Router), porque **el prebuilt no trae router** (igual que pasaba en b12017).
- Comprobación previa barata: cargar `LFM3-1.7B-Q4_0.gguf` con el **b12017 ya compilado en el teléfono** — el soporte se mergeó (27-10) antes de su build (11-03), así que probablemente ya lo corra; si carga, hacer el bench doble (b12017 vs b12549) para aislar el delta de binario.

## 3. Fase A — velocidad (metodología existente, sin cambios)

Condiciones de siempre: USB conectado, pantalla encendida brillo mínimo, temp inicial < 36 °C, cooldown 60–90 s entre modelos, Jellyfin parado, `MemAvailable` preflight > 1,5 GB.

1. **Barrido**: `scripts/bench/finish-benchmarks.ps1` → `llama-bench -p 512 -n 128 -r 3`, `-t 2/3/4`, para: SmolLM3-3B (incumbente), LFM3-1.7B Q4_0, LFM2.5-2.6B Q4_0, Qwen3-1.7B Q4_K_M. Evitar `-t 6/8` en ≥3B (ya sabido: cuelgues).
2. **RAM**: `run-peak-rss.sh` (VmHWM pico con `-c 4096`). Se espera LFM3-1.7B ≪ SmolLM3 (~3,9 GiB) — la mitad de parámetros y KV recurrente.
3. **Térmica**: `run-sustained.sh` (300 s) solo para los 2 finalistas.
4. **Router**: con el b12549 auto-compilado → `mode llm`, cambio de modelo, `llm unload`, `/metrics?model=`, `/v1/chat/completions` (120 tok, greedy), `--sleep-idle-seconds`. Confirmar que el reuse de contexto funciona (#32339): segunda petición del mismo chat debe procesar solo los tokens nuevos (ver `timings.prompt_n`).
5. **KV**: no asumir que `KV q8_0` ayuda en LFM3 (el cache es casi todo estado recurrente); registrar con y sin `-ctk q8_0 -ctv q8_0` y decidir con datos.

## 4. Fase B — calidad («más inteligentes», nuevo método: juez ciego por pares)

1. **Suite fija** de ~24 prompts, mayoría **en español** + algunos en inglés, 4 por categoría: instrucciones/estructurado, resumen, razonamiento/mates, QA factual, código pequeño, multilingüe. Se versiona en `docs/benchmarks/eval-suite-2026-11.md`. Incluir 1–2 casos de uso real del teléfono (chat de `:8080`).
2. **Generación**: cada modelo responde vía su chat template en `llama-server` (greedy, 256 tok máx, mismo system prompt vacío); logs a `docs/benchmarks/runs/eval-<modelo>/`.
3. **Juez**: **glm-5.3 vía OpenCode Go** (ya disponible para Angel), a ciegas: por cada prompt se le dan las dos respuestas con etiquetas A/B barajadas y pide ganador + una línea de razón. El juez no sabe cuál es el incumbente. *Alternativa sin API:* puntuación manual 0/1/2.
4. **Métricas**: win-rate global y por categoría; revisar a mano las respuestas donde el juez dude. Comprobar explícitamente que **el español no degrada** (HF no destaca ES en la lista de idiomas de LFM3 — la suite lo revela).

## 5. Regla de decisión (acordada)

| Criterio | Umbral |
|----------|--------|
| Velocidad | tg128 ≥ SmolLM3 (**~9,6 t/s** a su mejor `-t`) — se espera muy por encima |
| RAM | VmHWM pico ≤ **~3,9 GiB** (SmolLM3) — se espera muy por debajo |
| Calidad | win-rate ≥ **55 %** vs SmolLM3 en la suite, **y** sin fallos catastróficos en español |
| Funcional | router OK en b12549 auto-compilado + template correcta + reuse de contexto verificado |

Resultados posibles:

- **Cumple todo** → LFM3 pasa a **preset por defecto** (`llm.conf` / `llm-common.sh`); SmolLM3 queda como preset de calidad (`smol`).
- **Solo velocidad/RAM** → añadir preset `lfm3` **sin** cambiar el defecto; el «cambio» se pospone a una suite ampliada.
- Qwen3-1.7B: mismo proceso contra **Qwen2.5-3B** (rol multilingüe) — solo cambia el defecto multilingüe si gana ambos ejes.

## 6. Despliegue (si se adopta)

1. `download-models.ps1` + `push-models.ps1` con los GGUF elegidos (patrón existente).
2. Presets nuevos en `scripts/termux/llm-common.sh` + `llm.conf.example` (patrón `run-smol`/`run-qwen3b`).
3. Actualizar `docs/benchmarks/rmx3311-llm.md` (sección «LFM3/LFM2.5, 2026-11»), `STATUS.md` y el README de modelos.
4. Borrar los GGUF viejos solo tras una semana de uso estable (`cleanup-device.ps1`).

## 7. Riesgos conocidos (verificados en GitHub, 2026-11-19)

- **LFM3 híbrido + servidor**: el bug #32339 causaba reprocesado del prompt en cada turno con builds ~b12416 → **b12549 o superior obligatorio para el router**.
- Cifras del fabricante ≠ SD888 (además: su blog mide con GPU offload; este teléfono es CPU-only con las GPU backends ya descartadas).
- LFM3-1.7B **no** está pensado para razonamiento multi-paso complejo (lo dice el propio fabricante) — la suite debe pesar el uso real (chat, resumen, QA) más que olimpiadas de matemáticas.
- Qwen3-1.7B-2507: confirmar el GGUF exacto al descargar (hay revisiones antiguas del modelo rondando).

## Fuentes

| Recurso | URL | Nota |
|---------|-----|------|
| Soporte LFM3 en llama.cpp | https://github.com/ggml-org/llama.cpp/pull/31252 | Merged 2026-10-27; GGUFs oficiales |
| GGUF oficial LFM3-1.7B | https://huggingface.co/LiquidAI/LFM3-1.7B-GGUF | Q4_0 993 MiB · Q8_0 1,71 GiB · QAD-Q4_0 |
| Fix reuse de contexto (recurrentes) | https://github.com/ggml-org/llama.cpp/issues/32339 | Cerrado 2026-11-17; builds ≥ ~b12416 |
| Spec-dec LFM3 | https://github.com/ggml-org/llama.cpp/pull/31598 | Merged 2026-11-03 |
| Blog LFM3 (benchs fabricante) | https://www.liquid.ai/blog/lfm3 | Edge, Q4_0, con GPU offload |
| Release b12549 (snapdragon) | https://github.com/ggml-org/llama.cpp/releases/tag/b12549 | 2026-11-19 |
| Metodología incumbente | [`benchmarks/rmx3311-llm.md`](benchmarks/rmx3311-llm.md) · [`termux-llm-guide.md`](termux-llm-guide.md) | Este repo |

---

*Plan generado desde investigación web (CAR-117); ninguna prueba se ha ejecutado en el teléfono. Re-revisión del unlock EU en [`unlock-research.md`](unlock-research.md) § Round 3 (misma fecha): sigue bloqueado, sin cambios en la matriz §7.*
