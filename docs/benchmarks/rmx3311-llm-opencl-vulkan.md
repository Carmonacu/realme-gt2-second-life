# Vulkan / OpenCL en RMX3311 (Adreno 660, stock, Termux)

**Fecha:** 2026-10-31  
**Dispositivo:** Realme GT 2 (RMX3311), Snapdragon 888, **Adreno 660**, ColorOS 15, **sin root**  
**Runtime probado:** paquete Termux `llama-cpp` **0.8.0** + plugin `llama-cpp-backend-opencl`  
**Referencia CPU (recomendada):** `llama.cpp` **b12017** en `~/opt/llama-b12017` — ver [rmx3311-llm.md](rmx3311-llm.md)

---

## Resumen ejecutivo

| Backend | ¿Probado en este teléfono? | Resultado |
|---------|----------------------------|-----------|
| **CPU (b12017, bootstrap)** | Sí (barrido completo) | **~51 tok/s** (Qwen 0.5B tg128) — **usar esto** |
| **OpenCL (Termux 0.8.0)** | Sí (2026-10-31, SSH) | `ggml_opencl: platform IDs not available` o solo CPU; **≤ ~12 tok/s** en 0.5B |
| **Vulkan (`llama-cpp-backend-vulkan`)** | No instalado | En A6xx **stock** suele ser igual de frágil; no merece tiempo salvo curiosidad |

**Recomendación:** quedarse en **CPU** con los binarios del repo (`bootstrap.sh` → b12017, `-ngl 0`). No instalar backends GPU para uso diario.

---

## Paquetes Termux

```bash
pkg update
pkg install -y llama-cpp
# Solo para experimentos (no recomendado en Adreno 660 phone):
pkg install -y llama-cpp-backend-opencl    # arrastra ocl-icd
# pkg install -y llama-cpp-backend-vulkan
```

En el dispositivo (2026-10-31) ya estaba **`llama-cpp` 0.8.0**; se instaló **`llama-cpp-backend-opencl` 0.8.0** + **`ocl-icd`**.

Los scripts `~/bin/llm` y `llm-common.sh` fuerzan **`-ngl 0`** y **`~/opt/llama-b12017`** — coherente con esta recomendación.

---

## Variables de entorno (OpenCL)

El ICD de OpenCL del vendor está en **bionic**, no en Termux:

```bash
export LD_LIBRARY_PATH=/vendor/lib64:${LD_LIBRARY_PATH:-}
# Opcional: asegurar libs Termux + plugin
export LD_LIBRARY_PATH=/vendor/lib64:$PREFIX/lib
```

Comprobar que el vendor expone la lib (solo lectura, vía adb):

```text
/vendor/lib64/libOpenCL.so
```

Upstream: [llama.cpp OPENCL.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md) — drivers **A6xx en teléfonos** a menudo **no soportados** (compilador OpenCL antiguo en firmware).

---

## Prueba rápida (patrón bench)

Modelo pequeño para no calentar el teléfono:

```bash
M=~/models/qwen2.5-0.5b-instruct-q4_k_m.gguf

# Baseline CPU explícito (Termux 0.8.0)
llama-bench -m "$M" -r 1 -ngl 0 -p 512 -n 128 -t 4 -o md

# Intento GPU (capas en GPU)
export LD_LIBRARY_PATH=/vendor/lib64:$PREFIX/lib
llama-bench -m "$M" -r 1 -ngl 99 -p 512 -n 128 -t 4 -o md
```

En **adb** (binarios b12017 en `/data/local/tmp/llama/`) el mismo patrón está en [`scripts/bench/run-single-bench.sh`](../../scripts/bench/run-single-bench.sh) pero esos artefactos **solo incluyen backends CPU** (`libggml-cpu-*.so`), no OpenCL/Vulkan.

---

## Resultados medidos (OpenCL, Termux, 2026-10-31)

**Qwen2.5-0.5B Q4_K_M**, `-r 1`, `-p 512`, `-n 128`, `-t 4`:

| Config | Mensajes al cargar | Backend en tabla | pp512 (t/s) | tg128 (t/s) |
|--------|-------------------|------------------|-------------|-------------|
| `-ngl 0` (sin `LD_LIBRARY_PATH` vendor) | `platform IDs not available`; carga `libggml-opencl.so` | OpenCL (ngl 0) | ~18 | ~12 |
| `-ngl 99`, `LD_LIBRARY_PATH=/vendor/lib64:$PREFIX/lib` | Solo `libggml-cpu.so` | CPU | ~21 | ~12 |

Comparación de orden de magnitud con **b12017 CPU** en el mismo hardware: **~51 tok/s** tg128 (frío) en [rmx3311-llm.md](rmx3311-llm.md).

Interpretación:

1. **OpenCL no enumera plataforma** en este stack stock + Termux (típico A6xx phone).
2. Con vendor en `LD_LIBRARY_PATH`, el plugin OpenCL **ni siquiera se carga** en la prueba `-ngl 99`; todo cae a CPU lento (Termux 0.8.0).
3. Aunque en el futuro cargara kernels, upstream no garantiza Adreno 660; PR [#12886](https://github.com/ggml-org/llama.cpp/pull/12886) habla de compilador **> E031.38.01.00** — **no verificado** aquí.

---

## Modos de fallo esperados (Adreno A6xx, stock)

| Síntoma | Causa probable |
|---------|----------------|
| `ggml_opencl: platform IDs not available` | ICD/vendor OpenCL no visible o roto desde espacio Termux |
| Solo backend CPU con `-ngl 99` | Plugin OpenCL no enlaza `/vendor/lib64/libOpenCL.so` o init CL falla en silencio |
| Crash / CL build error al cargar modelo | Compilador OpenCL del firmware demasiado viejo ([OPENCL.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md)) |
| Vulkan: `vkCreateInstance` / no device | Driver Vulkan de producción en A6xx phone ≠ escritorio; Turnip/Freedreno requiere **root/custom** (fuera de Plan B) |
| Peor rendimiento que CPU moderno | Overhead + drivers móviles; llama.cpp optimiza ARM dotprod en CPU (b12017) |

---

## Vulkan (solo procedimiento)

```bash
pkg install -y llama-cpp-backend-vulkan
# Sin root no hay Turnip; se usa Vulkan del sistema
llama-bench -m "$M" -r 1 -ngl 99 -p 512 -n 128 -t 4 -o md
```

No se ejecutó en esta sesión para no alargar la instalación. Tratar como **misma viabilidad baja** que OpenCL en RMX3311 stock.

---

## NPU / Hexagon (SD888)

Fuera de alcance: backend Hexagon/QNN de llama.cpp apunta a **Snapdragon 8 Elite / Hexagon v79**, no SD888 — ver [08-ai-local.md](../phases/08-ai-local.md) y [discussion #14356](https://github.com/ggml-org/llama.cpp/discussions/14356).

---

## Enlaces

| Tema | Enlace |
|------|--------|
| Bench CPU completo | [rmx3311-llm.md](rmx3311-llm.md) |
| Fase 8 / checklist | [08-ai-local.md](../phases/08-ai-local.md) |
| Termux packaging | [termux-packages llama-cpp build.sh](https://github.com/termux/termux-packages/blob/master/packages/llama-cpp/build.sh) |
| Uso diario | [termux-llm-guide.md](../termux-llm-guide.md) |
