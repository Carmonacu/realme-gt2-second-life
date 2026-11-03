# Phase 8 — Local AI (rootless, stock RMX3311)

**Goal:** Run a useful **local LLM on CPU** (primary) inside **Termux** on stock ColorOS 15 — no root, no custom kernel. Optional GPU (OpenCL) / NPU experiments are **secondary** and often **not worth it** on Adreno 660 phones.

**Unblocks:** This phase does **not** depend on NetHunter kernel work ([STATUS.md](../STATUS.md) Phase 2 blocked). Pair with [rootless-kali.md](../rootless-kali.md) for pentest tooling.

**Research snapshot:** 2026-10-31 (web sources cited inline). **On-device benchmarks:** 2026-10-31 → [`../benchmarks/rmx3311-llm.md`](../benchmarks/rmx3311-llm.md). **Chat en Termux (pasos en español):** [`../termux-llm-guide.md`](../termux-llm-guide.md).

---

## Device assumptions (this project)

| Item | Value |
|------|--------|
| Model | Realme GT 2 **RMX3311**, 8 GB RAM |
| SoC | Snapdragon **888** (SM8350): Cortex-X1 + A78 + A55, **Adreno 660**, Hexagon **780** (DSP v68 class) |
| OS | ColorOS 15 / Android 15, **bootloader locked**, **no root** |
| Realistic RAM for LLM | ~**4–5 GB** total for weights + KV + Termux overhead (ColorOS + apps reserve the rest) |

---

## Checklist

- [x] Install **Termux from F-Droid** (not deprecated Play fork) — **0.118.3** on device (2026-10-31).
- [ ] ColorOS: **battery / phantom-process** mitigations — [rootless-kali.md](../rootless-kali.md#coloros-15-realme--termux-stability) + [termux-llm-guide.md](../termux-llm-guide.md).
- [ ] Run **`bash /sdcard/Download/llm-setup/bootstrap.sh`** once ([termux-llm-guide.md](../termux-llm-guide.md)); uses **llama.cpp b12017** (not outdated Termux `llama-cpp` 0.8.0 alone).
- [x] GGUF on phone: `/sdcard/Download/llm-models/` (5 models); `~/models` symlink after bootstrap.
- [ ] Baseline: `llama-cli` or `llama-server` with **`-c 2048` or `-c 4096`**, `-t 4`, `-ngl 0` (CPU only); note tokens/s.
- [ ] Optional: PocketPal AI benchmark (same llama.cpp TG metric) for comparison.
- [ ] **Do not** set context to model maximum (32k–128k) on 8 GB — OOM risk.
- [ ] SSH remoto: `ssh-setup.sh` + Tailscale — [termux-llm-guide.md](../termux-llm-guide.md).
- [ ] (Recomendado servidor 24/7) **Termux:Boot + runit** — `install-boot-services.sh` ([termux-boot-services.md](../termux-boot-services.md)); LLM al boot solo opt-in.
- [x] OpenCL / Vulkan (Termux plugins): **probado OpenCL — no viable** en RMX3311 stock ([rmx3311-llm-opencl-vulkan.md](../benchmarks/rmx3311-llm-opencl-vulkan.md)); mantener **`-ngl 0`** y **b12017**.
- [ ] Hexagon / QNN NPU on SD888: treat as **not realistic** for llama.cpp today (backend targets **Snapdragon 8 Elite**, Hexagon **v79** — [discussion #14356](https://github.com/ggml-org/llama.cpp/discussions/14356), [Snapdragon README](https://github.com/Liquid4All/benchmarks-llama.cpp/blob/benchmarks/docs/backend/snapdragon/README.md)).

---

## Model selection (8 GB RAM, CPU on SD888)

### Quantization guidance

| Quant | On-disk (typical 3B) | Quality | Notes |
|-------|----------------------|---------|--------|
| **Q4_K_M** | ~1.9–2.1 GB | Default sweet spot | Recommended default for chat + code on phone |
| Q4_0 | Similar size | Slightly lower | Legacy; llama.cpp can **repack at load** for ARM (`Q4_0_4_4` / dotprod / i8mm variants in bartowski repos) |
| Q4_0_4_4 | ~1.8 GB | Q4_0-class | **Safe ARM** repack when CPU features unknown ([bartowski Qwen2.5 table](https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF)) |
| Q4_0_4_8 | ~1.8 GB | Q4_0-class | Needs **i8mm** (SD888 has it); segfault reports exist with aggressive `armv8.4a+i8mm` **build** flags in Termux — prefer **runtime** repack or `GGML_CPU_ARM_ARCH=armv8.2-a+dotprod` |
| Q3_K_M / IQ quants | ~1.3–1.6 GB | Lower | Use if OOM with Q4_K_M |
| Q8_0 | ~3.3 GB+ | High | Usually **too heavy** for 8 GB phone alongside OS |

**Context vs RAM:** KV cache dominates at long context. Example: Llama 3.2 3B Q4_K_M ≈ **3.2 GB** at **4k** context vs **~16 GB** at 128k (estimates — [localmodel.run Llama 3.2 3B](https://localmodel.run/model/llama-3.2-3b)). On this phone, cap **`-c 2048–4096`** for 3B; **`-c 8192`** only when no other heavy apps and after monitoring `free`.

### Compared small models (verified repos, 2025–2026)

| Model | Params | Q4_K_M file (verified) | Native context | Fit on 8 GB @ `-c 4096` | Notes |
|-------|--------|------------------------|----------------|-------------------------|--------|
| **Qwen2.5-3B-Instruct** | 3.09B | **2.1 GB** [`Qwen/Qwen2.5-3B-Instruct-GGUF`](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF) / **1.93 GB** imatrix [`bartowski/...`](https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF) | 32k | **Good** | Mature llama.cpp support; strong multilingual |
| **SmolLM3-3B** | 3B | **1.92 GB** [`bartowski/HuggingFaceTB_SmolLM3-3B-GGUF`](https://huggingface.co/bartowski/HuggingFaceTB_SmolLM3-3B-GGUF) | 64k/128k w/ YaRN | **Good** | EN/FR/ES/DE/IT/PT; Apache; blog **2025-07-08** ([SmolLM3](https://huggingface.co/blog/smollm3)) |
| **Qwen3-4B** | 4B | **2.5 GB** [`Qwen/Qwen3-4B-GGUF`](https://huggingface.co/Qwen/Qwen3-4B-GGUF) (upload **2025-05-05**) | 32k+ | **Tight** | Best quality in class but heavier; use `-c 2048` first |
| **Llama 3.2 3B Instruct** | 3B | **2.02 GB** [`unsloth/Llama-3.2-3B-Instruct-GGUF`](https://huggingface.co/unsloth/Llama-3.2-3B-Instruct-GGUF) | 128k | **OK @ 4k** | Meta license; long context is a trap on 8 GB |
| **Gemma 3 4B IT** | 4B | **2.49 GB** [`ggml-org/gemma-3-4b-it-GGUF`](https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF) | model card | **Tight** | Gemma terms; multimodal variants exist — use text GGUF only here |
| **Phi-4-mini-instruct** | ~3.8B | **2.49 GB** [`bartowski/microsoft_Phi-4-mini-instruct-GGUF`](https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF) | 128k | **Tight** | Strong reasoning/code for size ([microsoft card](https://huggingface.co/microsoft/Phi-4-mini-instruct)) |
| **Qwen2.5-0.5B-Instruct** | 0.5B | **~0.4 GB** class [`Qwen/Qwen2.5-0.5B-Instruct-GGUF`](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) | 32k | **Easy** | Fastest useful tier |
| **Llama 3.2 1B Instruct** | 1B | Q4 tier ~**0.7–0.8 GB** [`unsloth/Llama-3.2-1B-Instruct-GGUF`](https://huggingface.co/unsloth/Llama-3.2-1B-Instruct-GGUF) | 128k | **Easy** | PocketPal / community use for smoke tests |
| **DeepSeek-R1-Distill-Qwen-1.5B** | 1.5B | **1.12 GB** Q4_K_M [`bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF`](https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF) | varies | **Easy** | “Thinking” distill; good for security study prompts, slower tokens than 0.5B |
| DeepSeek-R1-Distill-Qwen-7B | 7B | ~4 GB+ Q4 | — | **OOM** on 8 GB phone | Not recommended here |

### Expected speed on Snapdragon 888 class (CPU, llama.cpp)

**Verified reports (same SoC generation):**

| Source | Device / SoC | Model | Reported generation speed |
|--------|----------------|-------|---------------------------|
| [QuantG Termux guide](https://quantg.in/how-i-locally-run-deepseek-llama-on-android-using-ollama-and-termux-a-technical-implementation-guide/) | Galaxy S21 Ultra, **SD888**, 8 GB | **3B Q4_0** | **~3.2 tok/s** (512 ctx); **1B ~8.7 tok/s**; thermal drop to **~2.3 tok/s** sustained |
| [Engineer Labo](https://x-tech.pasona.co.jp/media/detail.html?p=11648) (**2025-11-07**) | **SD888**, Android 13 | **8B Q4_K_M** (JP) | **~3.41 tok/s** (128 tokens) — **8B not recommended** on 8 GB RAM |
| [SOTA2 / 2023.12](https://www.sota2.com/research/sota/language-model-inference-on-mobile-and-iot-device-latency-benchmark-llama-cpp-inference-evaluation) | SD888 | TinyLLaMA 1.1B Q4 | **~31.5 tok/s** gen (older stack — **not** directly comparable to 2025 llama.cpp) |

**Practical planning (2025–2026 llama.cpp, CPU, `-ngl 0`, `-t 4`, `-c 2048–4096`):**

| Tier | Expectation |
|------|-------------|
| 0.5B–1.5B Q4 | **~6–10 tok/s** peak; conversational |
| 3B Q4_K_M | **~2.5–4 tok/s**; matches QuantG 3B on SD888 |
| 4B Q4_K_M | **~2–3 tok/s**; may OOM if context too large |
| PocketPal scale | **&lt;2 tok/s** = sluggish; **7–8+** = OK chat ([PocketPal discussion #556](https://github.com/a-ghorbani/pocketpal-ai/discussions/556), **2025**) |

**Hearsay / do not bank on:** Adreno 660 OpenCL on this phone — **probado 2026-10-31, no viable** ([rmx3311-llm-opencl-vulkan.md](../benchmarks/rmx3311-llm-opencl-vulkan.md)); upstream A6xx phone drivers “likely not supported” — [OPENCL.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md). Hexagon offload on SD888 for llama.cpp (targets **8 Elite / v79** — [#14356](https://github.com/ggml-org/llama.cpp/discussions/14356)).

---

## Measured on this device (RMX3311, adb, llama.cpp b12017, 2026-10-31)

Full methodology and per-run logs: [`../benchmarks/rmx3311-llm.md`](../benchmarks/rmx3311-llm.md) · [`../benchmarks/runs/`](../benchmarks/runs/).

| Model | Q4_K_M | Best `-t` | **tg128 (t/s)** | pp512 best (t/s) | Notes |
|-------|--------|-----------|-----------------|------------------|--------|
| Qwen2.5-0.5B-Instruct | 463 MiB | **4** | **~51** | ~107 | Medido en frío; chat fluido |
| DeepSeek-R1-Distill-Qwen-1.5B | 1,04 GiB | **4** | **~24** | ~79 | CoT / estudio |
| **SmolLM3-3B** | 1,78 GiB | **2** | **~9,6** | ~22 | **Top pick**; VmHWM ~3,9 GiB @ `-c 4096` |
| Qwen2.5-3B-Instruct | 1,95 GiB | **4** | **~6,9** | ~13 | Completado oct-31 sesión 2 |
| Phi-4-mini-instruct | 2,32 GiB | **4** | **~5,4** | ~10 | VmHWM ~4,2 GiB; usar `-c 2048–4096` |

**Sostenido 5 min (SmolLM3, `-t 2`):** tg128 estable **~5,5–6,3 t/s**; batería **+0,9 °C** — throttling leve, no colapso.

**Runtime adb-only (sin Termux):** `/data/local/tmp/llama/`, `LD_LIBRARY_PATH`. Re-run: `scripts/bench/finish-benchmarks.ps1` (detached, logs en `docs/benchmarks/runs/`).

---

## Recommendations (this phone)

| Role | Model | Quant | Repo / file | `-c` limit (start) | Expected TG (CPU) |
|------|--------|-------|-------------|-------------------|-------------------|
| **Top pick (quality + RAM)** | **SmolLM3-3B** or **Qwen2.5-3B-Instruct** | **Q4_K_M** | `bartowski/HuggingFaceTB_SmolLM3-3B-GGUF` **or** `Qwen/Qwen2.5-3B-Instruct-GGUF` | **4096** (2048 if OOM) | SmolLM3 **~9,6 @ -t 2**; Qwen **~6,9 @ -t 4** measured |
| **Faster fallback** | **Qwen2.5-0.5B-Instruct** | **Q4_K_M** | `Qwen/Qwen2.5-0.5B-Instruct-GGUF` | **4096–8192** | **~51 tok/s** @ **`-t 4`** (device cold) |
| **Coding / cyber reasoning** | **Phi-4-mini-instruct** (quality) **or** **DeepSeek-R1-Distill-Qwen-1.5B** (speed + chain-of-thought) | **Q4_K_M** | `bartowski/microsoft_Phi-4-mini-instruct-GGUF` **or** `bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF` | Phi: **2048–4096**; DS 1.5B: **4096** | Phi **~5,4 tok/s @ -t 4**; DS **~24 tok/s @ -t 4** |

**SmolLM3** chat template: use **`--jinja`** ([ggml-org card](https://huggingface.co/ggml-org/SmolLM3-3B-GGUF)). **Qwen3** needs recent llama.cpp (**b5401+** per [HF card](https://huggingface.co/Qwen/Qwen3-4B-GGUF)).

---

## Runtime options (no root), ranked

| Rank | Runtime | Pros | Cons | Verified? |
|------|---------|------|------|-----------|
| **1** | **`llama-cpp` Termux package** (`pkg install llama-cpp`) | Fastest path; includes `llama-cli`, `llama-server`; optional OpenCL/Vulkan plugin packages ([build.sh](https://github.com/termux/termux-packages/blob/master/packages/llama-cpp/build.sh)) | Version pins to Termux build; GPU plugins **no** en RMX3311 stock ([opencl-vulkan bench](../benchmarks/rmx3311-llm-opencl-vulkan.md)) | **Yes** — Termux packaging (CPU path uses **b12017** copy, not pkg alone) |
| **2** | **Build llama.cpp in Termux** | Control flags: `-DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod`; `-DLLAMA_BUILD_SERVER=ON` | Long compile; **avoid** `-march=armv8.4a+i8mm` globally ([issue #6990](https://github.com/ggerganov/llama.cpp/issues/6990)) | **Yes** — [android.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md) |
| **3** | **PocketPal AI** ([pocketpal.dev](https://www.pocketpal.dev/)) | GUI, HF download, **built-in benchmark** (TG/PP, Jan **2025** — [discussion #155](https://github.com/a-ghorbani/pocketpal-ai/discussions/155)) | Another app to exempt from battery killer | **Yes** — app + docs |
| **4** | **ChatterUI / Layla** (community Android llama.cpp frontends) | Chat UX | Feature set varies by release; not audited here | **Partial** — store listings / GitHub only |
| **5** | **MLC Chat / MNN-LLM / Alibaba MNN** | Possible NPU/GPU paths on some devices | SD888 support and model coverage **device-specific**; separate model format (not GGUF) | **Mixed** — vendor docs; treat as experimental on GT2 |
| **6** | **Google AI Edge Gallery / LiteRT-LM** | Google’s on-device stack | Model catalog and Hexagon path **not verified** for SD888 in this research | **Unverified** for this device |
| **7** | **OpenCL backend** (`GGML_OPENCL=ON`, `LD_LIBRARY_PATH=/vendor/lib64`) | Can win on **new** Adreno (8 Gen 3+) | RMX3311 stock + Termux **probado — no** ([rmx3311-llm-opencl-vulkan.md](../benchmarks/rmx3311-llm-opencl-vulkan.md)); ~12 vs ~51 tok/s tg128 en 0.5B | **No** on this device |
| **8** | **Hexagon / QNN NPU** | Huge speed on **8 Elite** in demos | **SD888 / v68 not in verified llama.cpp Hexagon tier** | **Not realistic** here |

---

## Install — Termux (recommended path)

### 0. Termux (F-Droid vs Google Play)

Install **F-Droid** build (**0.118.3** suggested on [f-droid.org](https://f-droid.org/packages/com.termux/), **2025-05-29**). **Do not** mix with Play Store fork ([Termux discussion #4000](https://github.com/termux/termux-app/discussions/4000), **2024-06-08**): Play `v0.120` is a **separate fork** (~v0.108 feature level). Official sources: **F-Droid + GitHub** ([termux-app README](https://github.com/termux/termux-app)).

### 1. Base setup (on phone, Termux)

```bash
pkg update && pkg upgrade -y
termux-setup-storage
pkg install -y git wget curl python pip
pip install -U "huggingface_hub[cli]"
mkdir -p ~/models && cd ~
```

### 2. Install llama.cpp binaries

**Option A — package (start here):**

```bash
pkg install -y llama-cpp
# Optional backends (often useless on Adreno 660 phone):
# pkg install -y llama-cpp-backend-opencl llama-cpp-backend-vulkan
llama-cli --version
```

**Option B — build from source (when you need latest Qwen3 / flags):**

```bash
pkg install -y git cmake ninja clang make libandroid-spawn
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod \
  -DLLAMA_CURL=ON \
  -DLLAMA_BUILD_SERVER=ON
cmake --build build -j"$(nproc)"
export PATH="$HOME/llama.cpp/build/bin:$PATH"
```

Reference: [llama.cpp android.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md).

### 3. Download models (verified repos)

**Top pick — SmolLM3-3B Q4_K_M:**

```bash
huggingface-cli download bartowski/HuggingFaceTB_SmolLM3-3B-GGUF \
  --include "HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf" \
  --local-dir ~/models
```

**Alternative top pick — Qwen2.5-3B:**

```bash
huggingface-cli download Qwen/Qwen2.5-3B-Instruct-GGUF \
  --include "qwen2.5-3b-instruct-q4_k_m.gguf" \
  --local-dir ~/models
```

**Fast — Qwen2.5-0.5B:**

```bash
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct-GGUF \
  --include "qwen2.5-0.5b-instruct-q4_k_m.gguf" \
  --local-dir ~/models
```

**Cyber / code — Phi-4-mini:**

```bash
huggingface-cli download bartowski/microsoft_Phi-4-mini-instruct-GGUF \
  --include "microsoft_Phi-4-mini-instruct-Q4_K_M.gguf" \
  --local-dir ~/models
```

**wget fallback (no HF login, single file URL pattern):**

```bash
# Example: official Qwen2.5 3B Q4_K_M — check current URL on HF if 404
wget -c -O ~/models/qwen2.5-3b-instruct-q4_k_m.gguf \
  "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
```

### 4. Run (CPU baseline)

```bash
# Interactive
llama-cli -m ~/models/SmolLM3-3B-Q4_K_M.gguf \
  --jinja -c 4096 -t 4 -ngl 0 \
  -p "Resume en español: qué es un pentest rootless."

# Local API (LAN only — bind carefully on untrusted networks)
llama-server -m ~/models/qwen2.5-3b-instruct-q4_k_m.gguf \
  -c 4096 -t 4 -ngl 0 --host 127.0.0.1 --port 8080
```

### 5. Measure tokens/s

```bash
llama-bench -m ~/models/qwen2.5-0.5b-instruct-q4_k_m.gguf -t 4 -ngl 0 -p 512 -n 128
```

Compare with PocketPal’s benchmark defaults (PP 512, TG 128 — [discussion #556](https://github.com/a-ghorbani/pocketpal-ai/discussions/556)).

---

## Notes (legacy kernel plan)

- Original Phase 8 assumed NetHunter + optional Turnip/Vulkan in chroot — still valid **if** the device path unblocks later ([PLAN.md](../PLAN.md)).
- OpenCL vendor libs are **bionic** — probado en RMX3311: **no mejora** frente a b12017 CPU ([rmx3311-llm-opencl-vulkan.md](../benchmarks/rmx3311-llm-opencl-vulkan.md)).
- Docker inside rootless Kali proot is **not** a realistic GPU passthrough target.

---

## Sources (accessed 2026-10-31)

| Topic | URL |
|-------|-----|
| SD888 3B/1B speeds | https://quantg.in/how-i-locally-run-deepseek-llama-on-android-using-ollama-and-termux-a-technical-implementation-guide/ |
| SD888 8B speed | https://x-tech.pasona.co.jp/media/detail.html?p=11648 (2025-11-07) |
| OpenCL Adreno | https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md |
| Adreno 660 PR | https://github.com/ggml-org/llama.cpp/pull/12886 |
| Hexagon / Android | https://github.com/ggml-org/llama.cpp/discussions/14356 |
| Termux llama-cpp | https://github.com/termux/termux-packages/blob/master/packages/llama-cpp/build.sh |
| Termux / Play | https://github.com/termux/termux-app/discussions/4000 |
| PocketPal benchmark | https://github.com/a-ghorbani/pocketpal-ai/discussions/556 |
| Qwen3-4B GGUF | https://huggingface.co/Qwen/Qwen3-4B-GGUF |
| SmolLM3 blog | https://huggingface.co/blog/smollm3 (2025-07-08) |
