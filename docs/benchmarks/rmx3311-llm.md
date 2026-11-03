# Benchmarks LLM locales — Realme GT 2 (RMX3311)

**Fecha:** 2026-10-31 (barrido inicial + **completado 13:50–14:45**)  
**Dispositivo:** RMX3311, Snapdragon 888 (SM8350), 8 GB RAM, Android 15 / ColorOS, **sin root**  
**ADB:** `YOUR_ADB_SERIAL`  
**Runtime:** `llama.cpp` **b12017** en `/data/local/tmp/llama/` con `LD_LIBRARY_PATH`  
**Backend CPU:** `libggml-cpu-android_armv8.2_2.so` (dotprod; **no** i8mm en cpuinfo)  
**Pruebas:** `llama-bench -p 512 -n 128 -r 3 -ngl 0`, hilos **2–4** (no 6/8 en ≥3B); `timeout 600` en teléfono  

Logs crudos:
- Sesión 1: [`rmx3311-llm-raw.log`](rmx3311-llm-raw.log)
- Sesión 2 (detached, un log por run): [`runs/`](runs/)

---

## Preflight (solo lectura)

| Comprobación | Resultado |
|--------------|-----------|
| Batería | **100%**, USB, **≥ 30%** OK |
| Temperatura inicial (sesión 2) | **~26 °C** → subió a **~33 °C** tras barrido largo |
| Almacenamiento `/data/local/tmp` | **~96 GB** libres |
| RAM `MemAvailable` | **~2,9–4,7 GB** (ColorOS; preflight **> 1,5 GB**) |
| `taskset` | Presente; **no usado** en sesión 2 |

---

## Tabla resumen (mejor `-t` por modelo)

Valores **tg128** = generación; **pp512** = prefill. Mejor **tg128** estable del barrido (sesión 1 fría salvo donde se indica).

| Modelo | Quant | Tamaño | Mejor `-t` | pp512 (t/s) | **tg128 (t/s)** | Notas |
|--------|-------|--------|------------|-------------|-----------------|--------|
| Qwen2.5-0.5B-Instruct | Q4_K_M | 463 MiB | **4** | 106,5 | **51,0** | Sesión 1 fría; reconfirm t=3/4 en sesión 2 **~25 t/s** (teléfono ya caliente) |
| DeepSeek-R1-Distill-Qwen-1.5B | Q4_K_M | 1,04 GiB | **4** | 78,5 | **23,8** | Sesión 1; t=3/4 sesión 2 **~12 t/s** (caliente) |
| **SmolLM3-3B** | Q4_K_M | 1,78 GiB | **2** | 21,6 | **9,62** | Mejor calidad/velocidad; t=4 → 7,29 |
| Qwen2.5-3B-Instruct | Q4_K_M | 1,95 GiB | **4** | 11,4 | **6,89** | Completado sesión 2 (`runs/20261031-142000-*`) |
| Phi-4-mini-instruct | Q4_K_M | 2,32 GiB | **4** | 10,0 | **5,41** | Primera medición completa sesión 2; t=2 → 4,30 |

### Detalle Phi-4-mini (sesión 2, frío→templado)

| `-t` | pp512 | tg128 | Δ temp |
|------|-------|-------|--------|
| 2 | 10,67 | 4,30 | 31,6→32,9 °C |
| 3 | 9,39 | 4,49 | 32,5→33,4 °C |
| 4 | 10,03 | **5,41** | 33,0→33,6 °C |

### Detalle Qwen2.5-3B (sesión 2)

| `-t` | pp512 | tg128 | Δ temp |
|------|-------|-------|--------|
| 2 | 13,11 | 6,16 | 33,3→33,5 °C |
| 3 | 10,51 | 6,05 | 33,1→33,4 °C |
| 4 | 11,43 | **6,89** | 33,1→33,4 °C |

**taskset `f0`:** en sesión 1, tras calor prolongado, **tg128 ≈ 0,14 t/s** — **no usar**.

---

## RAM (pico VmHWM, `llama-cli -c 4096 -t 2 -n 64`)

Medición con muestreo `/proc/<pid>/status` en teléfono (`run-peak-rss.sh`).

| Modelo | VmHWM pico | MemAvailable antes | MemAvailable pico aprox. |
|--------|------------|--------------------|---------------------------|
| SmolLM3-3B | **~3,93 GiB** (4 115 108 kB) | ~4,24 GiB | estable (~4,23 GiB) |
| Phi-4-mini | **~4,24 GiB** (4 446 888 kB) | ~4,25 GiB | carga pesada en 8 GB |

Logs: [`runs/20261031-143511-peak-rss-SmolLM3-3B-t2.log`](runs/20261031-143511-peak-rss-SmolLM3-3B-t2.log), [`runs/20261031-143823-peak-rss-Phi-4-mini-t2.log`](runs/20261031-143823-peak-rss-Phi-4-mini-t2.log).

Sesión 1 (SmolLM3 `@t=4`, muestreo único): VmHWM **~2,05 GiB** en snapshot parcial — la sesión 2 con monitor continuo es la referencia.

---

## Térmica y throttling (5 min sostenido)

**SmolLM3-3B, `-t 2`**, bucle `llama-bench -n 128` **300 s** (`run-sustained.sh`):

| Run | t transcurrido | Temp (°C) | tg128 (t/s) | pp512 (t/s) |
|-----|----------------|-----------|-------------|-------------|
| 1 | 0 s | 31,6 | 5,49 | 12,08 |
| 2 | 116 s | 31,8 | 6,28 | 12,99 |
| 3 | 222 s | 32,2 | 6,25 | 13,04 |

**Conclusión:** con `-t 2` y USB, **sin caída fuerte** de tg128 (~5,5→6,3 t/s); temperatura **+0,9 °C** en ~5 min. Con `-t 4` tras calor, sesión 1 mostró tg1024 ~5,8 t/s pero riesgo de anomalías con `taskset`/`-t 6+`.

Log: [`runs/20261031-144004-sustained-SmolLM3-3B-t2-300s.log`](runs/20261031-144004-sustained-SmolLM3-3B-t2-300s.log).

---

## Fallos / limitaciones (con evidencia)

| Issue | Evidencia |
|-------|-----------|
| `-t 6` / `-t 8` en **≥3B** | Cuelgue tg128 >44 min (SmolLM3, sesión 1) |
| Phi / Qwen interrumpidos (sesión 1) | ADB off, `Terminated`, tg ~0,19 con teléfono caliente |
| PC-side kills (sesión 1) | Log compartido, timeout foreground |
| Reconfirm 0,5B/1,5B en sesión caliente | tg128 ~50% del pico en frío — usar valores sesión 1 para “mejor -t” |
| **Sesión 2** | **0 fallos**; `finish-benchmarks.ps1` + `nohup` + log por run |

---

## Recomendación medida en este dispositivo

| Uso | Modelo | `-t` | `-c` | tg128 medido |
|-----|--------|------|------|--------------|
| **Mejor equilibrio calidad/velocidad** | **SmolLM3-3B Q4_K_M** | **2** | 4096 | **~9,6 tok/s** |
| Alternativa multilingüe | Qwen2.5-3B-Instruct Q4_K_M | **4** | 4096 | **~6,9 tok/s** |
| Código / razonamiento compacto | Phi-4-mini-instruct Q4_K_M | **4** | **2048–4096** | **~5,4 tok/s** (RAM ~4,2 GiB pico) |
| Máxima velocidad | Qwen2.5-0.5B-Instruct Q4_K_M | **4** | 4096 | **~51 tok/s** (frío) |
| CoT rápido | DeepSeek-R1-Distill-Qwen-1.5B Q4_K_M | **4** | 4096 | **~24 tok/s** (frío) |

**Evitar:** `-t 6` u `-t 8` en **≥3B**; `taskset f0` tras calor; barridos largos sin pausa (**esperar temp < 36 °C**, 60–90 s entre modelos).

---

## Scripts (re-ejecución)

| Script | Uso |
|--------|-----|
| [`scripts/bench/download-models.ps1`](../../scripts/bench/download-models.ps1) | Descarga GGUF al PC |
| [`scripts/bench/push-models.ps1`](../../scripts/bench/push-models.ps1) | `adb push` → `/data/local/tmp/models/` |
| [`scripts/bench/run-on-device.sh`](../../scripts/bench/run-on-device.sh) | Barrido legacy en teléfono |
| [`scripts/bench/finish-benchmarks.ps1`](../../scripts/bench/finish-benchmarks.ps1) | **Recomendado:** detached, log por run, RSS + 5 min |
| [`scripts/bench/run-single-bench.sh`](../../scripts/bench/run-single-bench.sh) | Una prueba (teléfono) |
| [`scripts/bench/run-peak-rss.sh`](../../scripts/bench/run-peak-rss.sh) | VmHWM + meminfo |
| [`scripts/bench/run-sustained.sh`](../../scripts/bench/run-sustained.sh) | Bucle térmico |
| [`scripts/bench/cleanup-device.ps1`](../../scripts/bench/cleanup-device.ps1) | Borra modelos en tmp (opcional) |
| [`scripts/bench/run-llm-variants.sh`](../../scripts/bench/run-llm-variants.sh) | **Termux** (no adb): KV q8_0 vs especulativa — ver abajo |

Binarios PC: `downloads/llama-android/` (gitignored).

---

## Variantes: router / KV q8_0 / especulativa (b12017)

### Resultados 2026-11-03 (teléfono, condiciones degradadas)

Condiciones: teléfono en segundo plano vía SSH, Jellyfin parado, `-t 4`, ctx 4096, generación de 120 tokens, temp 0 (greedy), `llama-server` b12017.

| Variante | Prompt (tok/s) | Generación (tok/s) |
|----------|---------------:|-------------------:|
| Qwen2.5-3B Q4_K_M · KV f16 (base) | 2,08 | 2,84 |
| Qwen2.5-3B · KV q8_0 + flash-attn | 4,29 | 2,87 |
| Qwen2.5-3B + borrador Qwen2.5-0.5B (especulativa, n-max 8, p-min 0,75) | 4,29 | 2,86 (sin ganancia) |
| SmolLM3-3B | 4,26 | 2,60 |

**Ojo — no sacar conclusiones todavía:** todo está muy por debajo de lo medido antes (~9,6 tok/s SmolLM3, ~6,9 tok/s Qwen2.5-3B). Durante la prueba: `cpu4` (núcleos medios) con `scaling_max_freq` limitado a **1,44 GHz**, **1,7 GB de swap** usados y **load avg ~8** → probablemente throttling de ColorOS en segundo plano / pantalla apagada. **Repetir con la pantalla encendida y Termux en primer plano** antes de decidir sobre especulativa o KV q8_0.

Router: **no probado** — el binario b12017 del teléfono no lo soporta (`subprocess is not enabled on this build`, ver [termux-llm-guide.md](../termux-llm-guide.md#router-no-disponible-con-el-binario-empaquetado-prueba-2026-11-03)).

### Cómo repetir

Script en Termux (usa `~/models` y `~/opt/llama-b12017`, no `/data/local/tmp`):

```powershell
adb -s YOUR_ADB_SERIAL push scripts/bench/run-llm-variants.sh /sdcard/Download/llm-setup/
```

```bash
mode idle                                   # sin llama-server activo (o --stop-llm)
bash ~/storage/shared/Download/llm-setup/run-llm-variants.sh            # ~25–40 min con cooldowns
bash ~/storage/shared/Download/llm-setup/run-llm-variants.sh --skip-bench --reps 1   # solo parte B
```

- **A (llama-bench):** Qwen2.5-3B `-t 4`, pp512/tg128 a profundidad 0 y 2048: `base` · `-fa 1` · `-fa 1 -ctk q8_0 -ctv q8_0`.
- **B (llama-server `/completion`, greedy):** `base` · `kv-q8` · `spec` (borrador 0.5B) · `spec-kv-q8`; tok/s, aceptación del borrador (`timings.draft_n_accepted`), pico VmHWM.
- Logs: `/sdcard/Download/llm-bench-runs/<ts>-llm-variants/` (`summary.md` + un log por variante). PC: `adb pull /sdcard/Download/llm-bench-runs/. docs/benchmarks/runs/`.

Smoke test del script en PC x86_64 con b12017 (sin valor para el teléfono): funciona de punta a punta; en CPU x86 la KV q8_0 bajó pp a profundidad 2048 — **medir en SD888 antes de recomendarla**.

## GPU (OpenCL / Vulkan)

Probado en stock + Termux: **no viable** frente a CPU b12017. Paquetes, env vars y logs: **[rmx3311-llm-opencl-vulkan.md](rmx3311-llm-opencl-vulkan.md)**.

---

## Próximo paso sugerido

1. Seguir **[termux-llm-guide.md](../termux-llm-guide.md)** (`llm smol` → http://127.0.0.1:8080).  
2. Uso diario: **SmolLM3 @ -t 2 -c 4096**; Phi solo si cabe en RAM y aceptas ~5 tok/s.
